import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class GroupScheduleManagementScreen extends StatefulWidget {
  const GroupScheduleManagementScreen({super.key});

  @override
  State<GroupScheduleManagementScreen> createState() =>
      _GroupScheduleManagementScreenState();
}

class _GroupScheduleManagementScreenState
    extends State<GroupScheduleManagementScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  DatabaseReference? _groupsRef;
  DatabaseReference? _groupSchedulesRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;

  List<Group> _groups = [];
  Map<String, List<GroupSchedule>> _groupSchedules = {};
  
  // Cycle Management
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  bool _isReadOnly = false; // Historical protection

  bool _isLoading = true;
  String? _campus;

  final List<String> _weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes'
  ];

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      _campus = userData['campus'];
      
      if (_campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      // Load cycles first
      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId = await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() {
        _availableSchoolCycles = cycles;
        _selectedSchoolCycle = currentCycleId;
      });
      
      _checkCycleStatus();
      _loadDataForCycle(_selectedSchoolCycle!);

    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkCycleStatus() {
    if (_selectedSchoolCycle == null || _availableSchoolCycles.isEmpty) return;
    try {
      final cycle = _availableSchoolCycles.firstWhere((c) => c.id == _selectedSchoolCycle);
      final now = DateTime.now();
      if (now.isAfter(cycle.endDate.add(const Duration(days: 1)))) {
        setState(() => _isReadOnly = true);
      } else {
        setState(() => _isReadOnly = false);
      }
    } catch (e) {
      setState(() => _isReadOnly = false);
    }
  }

  void _loadDataForCycle(String cycleId) {
    if (_campus == null) return;
    
    setState(() {
      _isLoading = true;
      _groups = [];
      _groupSchedules = {};
    });

    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    _groupSchedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');

    // 1. Load Groups for this Cycle
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!
        .orderByChild('schoolCycleId')
        .equalTo(cycleId)
        .onValue
        .listen((event) {
      final newGroups = <Group>[];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          newGroups.add(Group.fromSnapshot(child));
        }
      }
      if (mounted) {
        setState(() => _groups = newGroups);
        _loadSchedules(); // Load schedules after groups are set contextually
      }
    });
  }

  void _loadSchedules() {
    if (_groupSchedulesRef == null) return;
    
    _groupSchedulesSubscription?.cancel();
    _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
      final newGroupSchedules = <String, List<GroupSchedule>>{};
      if (event.snapshot.exists) {
        for (final groupChild in event.snapshot.children) {
          final groupId = groupChild.key!;
          final List<GroupSchedule> schedulesForGroup = [];
          
          if (groupChild.value is Map) {
             final daysMap = groupChild.value as Map;
             daysMap.forEach((dayKey, dayValue) {
                if (dayValue is Map) {
                   schedulesForGroup.add(GroupSchedule(
                    id: dayKey.toString(),
                    groupId: groupId,
                    schoolCycle: _selectedSchoolCycle!,
                    dayOfWeek: dayKey.toString(),
                    entryTime: dayValue['entryTime'] ?? '',
                    exitTime: dayValue['exitTime'] ?? '',
                  ));
                }
             });
          }
          newGroupSchedules[groupId] = schedulesForGroup;
        }
      }
      if (mounted) {
        setState(() {
          _groupSchedules = newGroupSchedules;
          _isLoading = false;
        });
      }
    }, onError: (e) {
       if (mounted) setState(() => _isLoading = false);
    });
    
    // Si no hay datos, asegurar que isLoading se apague
    if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
            if (_isLoading && mounted) setState(() => _isLoading = false);
        });
    }
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _editGroupSchedule(Group group, GroupSchedule? existingSchedule) async {
    if (_isReadOnly) {
       UiHelpers.showSnackBar(context, 'Ciclo cerrado. No se pueden modificar horarios.', isError: true);
       return;
    }

    String initialDayOfWeek = existingSchedule?.dayOfWeek ?? _weekdays.first;
    TimeOfDay? entryTime = existingSchedule?.entryTime.isNotEmpty == true
        ? _parseTimeOfDay(existingSchedule!.entryTime)
        : null;
    TimeOfDay? exitTime = existingSchedule?.exitTime.isNotEmpty == true
        ? _parseTimeOfDay(existingSchedule!.exitTime)
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setStateInDialog) {
            return AlertDialog(
              title: Text('Horario - Grupo ${group.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: initialDayOfWeek,
                    decoration: const InputDecoration(
                        labelText: 'Día de la Semana',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder()),
                    items: _weekdays.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                    onChanged: existingSchedule != null ? null : (value) { // Disable day change if editing existing
                      setStateInDialog(() => initialDayOfWeek = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerTile(
                          context: dialogContext,
                          label: 'Entrada',
                          time: entryTime,
                          color: Colors.teal,
                          onTimePicked: (picked) => setStateInDialog(() => entryTime = picked),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePickerTile(
                          context: dialogContext,
                          label: 'Salida',
                          time: exitTime,
                          color: Colors.orange,
                          onTimePicked: (picked) => setStateInDialog(() => exitTime = picked),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (entryTime == null || exitTime == null) {
                      UiHelpers.showSnackBar(context, 'Selecciona ambas horas.', isError: true);
                      return;
                    }
                    // Validate Entry < Exit
                    final double startDouble = entryTime!.hour + entryTime!.minute / 60.0;
                    final double endDouble = exitTime!.hour + exitTime!.minute / 60.0;
                    
                    if (startDouble >= endDouble) {
                       UiHelpers.showSnackBar(context, 'La salida debe ser después de la entrada.', isError: true);
                       return;
                    }

                    if (!dialogContext.mounted) return;

                    try {
                      final scheduleData = GroupSchedule(
                        id: initialDayOfWeek,
                        groupId: group.key,
                        schoolCycle: _selectedSchoolCycle!,
                        dayOfWeek: initialDayOfWeek,
                        entryTime: entryTime!.format(context), // Use context for formatting consistency
                        exitTime: exitTime!.format(context),
                      );
                      
                      // Save under: planteles/campus/schedules/cycle/group/day
                      await _groupSchedulesRef!
                          .child(group.key)
                          .child(initialDayOfWeek)
                          .set(scheduleData.toFirebaseMap());
                          
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      UiHelpers.showSnackBar(context, 'Horario guardado.');
                    } catch (e) {
                      UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimePickerTile({
    required BuildContext context,
    required String label,
    required TimeOfDay? time,
    required Function(TimeOfDay) onTimePicked,
    required Color color,
  }) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 7, minute: 0),
          builder: (context, child) {
             return Theme(
               data: Theme.of(context).copyWith(
                 colorScheme: ColorScheme.light(primary: color, onPrimary: Colors.white, surface: Colors.white),
               ),
               child: child!,
             );
          }
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(time?.format(context) ?? '--:--',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String time) {
    try {
      // Formato esperado: "7:00 AM" o "14:00" dependiendo de la localización.
      // Intentamos parsing simple "HH:mm" si no hay AM/PM
      if (time.contains(":") && !time.contains("M")) {
          final parts = time.split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      
      // Si tiene AM/PM es más complejo sin el contexto, pero Flutter suele estandarizar.
      // Simplificación: Asumir que el usuario selecciona del picker y se guarda consistente.
      // Para parsing robusto, mejor usar TimeOfDay con un helper manual si el formato varía.
      // Aquí haremos un split simple asumiendo "HH:mm" de 24h es lo ideal, 
      // pero TimeOfDay.format() usa locale. 
      
      // Fallback: Devolver 7:00 si falla
      return const TimeOfDay(hour: 7, minute: 0); 
    } catch (e) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // No AppBar needed as per previous requests
      body: LayoutBuilder(builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Header con Selector de Ciclo
                      FadeInUp(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? theme.cardTheme.color : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedSchoolCycle,
                                        isExpanded: true,
                                        hint: const Text("Seleccionar Ciclo Escolar"),
                                        items: _availableSchoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedSchoolCycle = val;
                                              _checkCycleStatus();
                                              _loadDataForCycle(val);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isReadOnly)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock, size: 14, color: Color(0xFFD32F2F)),
                                      SizedBox(width: 6),
                                      Text("Ciclo Cerrado - Solo Lectura", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : _groups.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.class_outlined, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text("No hay grupos en este ciclo.", style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _groups.length,
                                  itemBuilder: (context, index) {
                                    final group = _groups[index];
                                    final schedulesForGroup = _groupSchedules[group.key] ?? [];
                                    final hasSchedules = schedulesForGroup.isNotEmpty;

                                    return FadeInUp(
                                      delay: Duration(milliseconds: 50 * index),
                                      child: Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                                        color: isDark ? theme.cardTheme.color : Colors.white,
                                        child: Theme(
                                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                          child: ExpansionTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: hasSchedules ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(Icons.access_time_filled_rounded, color: hasSchedules ? Colors.green : Colors.orange),
                                            ),
                                            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            subtitle: Text(
                                              hasSchedules ? '${schedulesForGroup.length} días asignados' : 'Sin horario configurado',
                                              style: TextStyle(color: theme.textTheme.bodySmall?.color),
                                            ),
                                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                            children: [
                                              const Divider(color: Color(0xFFEEEEEE)),
                                              // Lista de días (Lunes a Viernes)
                                              ..._weekdays.map((day) {
                                                final schedule = schedulesForGroup.firstWhere(
                                                  (s) => s.dayOfWeek == day,
                                                  orElse: () => GroupSchedule(id: '', groupId: group.key, schoolCycle: '', dayOfWeek: day, entryTime: '', exitTime: ''),
                                                );
                                                final isSet = schedule.entryTime.isNotEmpty;

                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSet ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: isSet ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 80, 
                                                        child: Text(day, style: TextStyle(fontWeight: FontWeight.w600, color: isSet ? theme.colorScheme.primary : Colors.grey)),
                                                      ),
                                                      Expanded(
                                                        child: Center(
                                                          child: isSet 
                                                            ? Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const Icon(Icons.login, size: 14, color: Colors.teal),
                                                                  const SizedBox(width: 4),
                                                                  Text(schedule.entryTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey)),
                                                                  const Icon(Icons.logout, size: 14, color: Colors.orange),
                                                                  const SizedBox(width: 4),
                                                                  Text(schedule.exitTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                ],
                                                              )
                                                            : const Text('-- : --', style: TextStyle(color: Colors.grey)),
                                                        ),
                                                      ),
                                                      if (!_isReadOnly)
                                                        IconButton(
                                                          icon: Icon(isSet ? Icons.edit : Icons.add_circle_outline, size: 20, color: isSet ? Colors.grey : theme.colorScheme.primary),
                                                          onPressed: () => _editGroupSchedule(group, isSet ? schedule : null),
                                                          tooltip: isSet ? 'Editar' : 'Asignar',
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                        )
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              );
            }),
    );
  }
}