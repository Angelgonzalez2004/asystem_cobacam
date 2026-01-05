import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart'; // ADDED: Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // ADDED: Import ConnectivityService
import 'package:provider/provider.dart'; // ADDED: Import Provider

class GroupScheduleManagementScreen extends StatefulWidget {
  const GroupScheduleManagementScreen({super.key});

  @override
  State<GroupScheduleManagementScreen> createState() => _GroupScheduleManagementScreenState();
}

class _GroupScheduleManagementScreenState extends State<GroupScheduleManagementScreen> {
  late final HiveService _hiveService; // ADDED: Declaration
  late final ConnectivityService _connectivityService; // ADDED: Declaration
  late final AppSettingsService _appSettingsService; // MODIFIED: to late final

  DatabaseReference? _groupsRef;
  DatabaseReference? _groupSchedulesRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;

  List<Group> _groups = [];
  Map<String, List<GroupSchedule>> _groupSchedules = {}; // groupId -> List<GroupSchedule>

  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = '';

  // Weekdays for display and scheduling
  final List<String> _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  @override
  void initState() {
    super.initState();
    // ADDED: Initialize services
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() { 
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
      });
      
      _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
      _groupSchedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/groupSchedules/$dynamicSchoolCycle');

      _groupsSubscription = _groupsRef!.onValue.listen((event) {
        final newGroups = <Group>[];
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            newGroups.add(Group.fromSnapshot(child));
          }
        }
        if (mounted) setState(() => _groups = newGroups);
      }, onError: (error) {
        _showErrorSnackBar('Error al cargar grupos: ${error.toString()}');
      });

      _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
        final newGroupSchedules = <String, List<GroupSchedule>>{};
        if (event.snapshot.exists) {
          for (final groupChild in event.snapshot.children) {
            final groupId = groupChild.key!;
            final List<GroupSchedule> schedulesForGroup = [];
            for (final dayChild in groupChild.children) {
              schedulesForGroup.add(GroupSchedule(
                id: dayChild.key!, // Using day name as ID for simplicity
                groupId: groupId,
                schoolCycle: _currentSchoolCycle,
                dayOfWeek: dayChild.key!,
                entryTime: (dayChild.value as Map)['entryTime'] ?? '',
                exitTime: (dayChild.value as Map)['exitTime'] ?? '',
              ));
            }
            newGroupSchedules[groupId] = schedulesForGroup;
          }
        }
        if (mounted) setState(() => _groupSchedules = newGroupSchedules);
      }, onError: (error) {
        _showErrorSnackBar('Error al cargar horarios de grupo: ${error.toString()}');
      });

    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _editGroupSchedule(Group group, GroupSchedule? existingSchedule) async {
    // Determine the day of week for the schedule we're editing or creating
    String initialDayOfWeek = existingSchedule?.dayOfWeek ?? _weekdays.first;
    TimeOfDay? entryTime = existingSchedule?.entryTime.isNotEmpty == true
        ? _parseTimeOfDay(existingSchedule!.entryTime) : null;
    TimeOfDay? exitTime = existingSchedule?.exitTime.isNotEmpty == true
        ? _parseTimeOfDay(existingSchedule!.exitTime) : null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setStateInDialog) { // Use dialogContext and setStateInDialog
            return AlertDialog(
              title: Text('Editar Horario para ${group.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: initialDayOfWeek,
                    decoration: const InputDecoration(labelText: 'Día de la Semana'),
                    items: _weekdays.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                    onChanged: (value) {
                      setStateInDialog(() => initialDayOfWeek = value!); // Update dialog state
                    },
                  ),
                  ListTile(
                    title: Text('Entrada: ${entryTime?.format(dialogContext) ?? 'Seleccionar'}'), // Use dialogContext
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: dialogContext, // Use dialogContext
                        initialTime: entryTime ?? TimeOfDay.now(),
                      );
                      if (picked != null && picked != entryTime) {
                        setStateInDialog(() => entryTime = picked); // Update dialog state
                      }
                    },
                  ),
                  ListTile(
                    title: Text('Salida: ${exitTime?.format(dialogContext) ?? 'Seleccionar'}'), // Use dialogContext
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: dialogContext, // Use dialogContext
                        initialTime: exitTime ?? TimeOfDay.now(),
                      );
                      if (picked != null && picked != exitTime) {
                        setStateInDialog(() => exitTime = picked); // Update dialog state
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(), // Use dialogContext
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (entryTime == null || exitTime == null) {
                      _showErrorSnackBar('Por favor, selecciona las horas de entrada y salida.');
                      return;
                    }
                    if (!dialogContext.mounted) return; // Check dialogContext
                    
                    try {
                      final scheduleData = GroupSchedule(
                        id: initialDayOfWeek, // Day name as ID
                        groupId: group.key,
                        schoolCycle: _currentSchoolCycle,
                        dayOfWeek: initialDayOfWeek,
                        entryTime: entryTime!.format(dialogContext), // Use dialogContext
                        exitTime: exitTime!.format(dialogContext), // Use dialogContext
                      );
                      await _groupSchedulesRef!.child(group.key).child(initialDayOfWeek).set(scheduleData.toFirebaseMap());
                      if (!dialogContext.mounted) return; // Check dialogContext
                      Navigator.of(dialogContext).pop(); // Close dialog
                      _showSuccessSnackBar('Horario de ${group.name} para $initialDayOfWeek guardado.');
                    } catch (e) {
                      _showErrorSnackBar('Error al guardar horario: ${e.toString()}');
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

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600), // Max width for content
                child: _groups.isEmpty
                    ? Center(child: Text('No hay grupos registrados para el plantel o ciclo escolar $_currentSchoolCycle.'))
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final schedulesForGroup = _groupSchedules[group.key] ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: ExpansionTile(
                              title: Text('Grupo: ${group.name}'),
                              subtitle: Text('Semestre: ${group.semester}, Alumnos: ${group.studentCount}'),
                              children: _weekdays.map((day) {
                                final schedule = schedulesForGroup.firstWhere(
                                  (s) => s.dayOfWeek == day,
                                  orElse: () => GroupSchedule(id: '', groupId: group.key, schoolCycle: _currentSchoolCycle, dayOfWeek: day, entryTime: '', exitTime: ''),
                                );
                                final hasSchedule = schedule.entryTime.isNotEmpty && schedule.exitTime.isNotEmpty;

                                return ListTile(
                                  title: Text(day),
                                  subtitle: hasSchedule
                                      ? Text('Entrada: ${schedule.entryTime} | Salida: ${schedule.exitTime}')
                                      : const Text('Horario no definido'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editGroupSchedule(group, hasSchedule ? schedule : null),
                                      ),
                                      if (hasSchedule)
                                        IconButton(
                                          icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                          onPressed: () async {
                                            if (_groupSchedulesRef == null) return;
                                            final bool? confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Confirmar Eliminación'),
                                                content: Text('¿Eliminar horario de ${group.name} para $day?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                                                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await _groupSchedulesRef!.child(group.key).child(day).remove();
                                                _showSuccessSnackBar('Horario eliminado.');
                                              } catch (e) {
                                                _showErrorSnackBar('Error al eliminar horario: ${e.toString()}');
                                              }
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
