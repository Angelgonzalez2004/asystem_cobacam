import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
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

  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = '';

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

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }

      final dynamicSchoolCycle =
          await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
      });

      _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
      _groupSchedulesRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/groupSchedules/$dynamicSchoolCycle');

      _groupsSubscription = _groupsRef!.onValue.listen((event) {
        final newGroups = <Group>[];
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            newGroups.add(Group.fromSnapshot(child));
          }
        }
        if (mounted) setState(() => _groups = newGroups);
      }, onError: (error) {
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al cargar grupos: ${error.toString()}',
              isError: true);
        }
      });

      _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
        final newGroupSchedules = <String, List<GroupSchedule>>{};
        if (event.snapshot.exists) {
          for (final groupChild in event.snapshot.children) {
            final groupId = groupChild.key!;
            final List<GroupSchedule> schedulesForGroup = [];
            for (final dayChild in groupChild.children) {
              schedulesForGroup.add(GroupSchedule(
                id: dayChild.key!,
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
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al cargar horarios: ${error.toString()}',
              isError: true);
        }
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
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

  Future<void> _editGroupSchedule(
      Group group, GroupSchedule? existingSchedule) async {
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
              title: Text('Editar Horario - ${group.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: initialDayOfWeek,
                    decoration: const InputDecoration(
                        labelText: 'Día de la Semana',
                        border: OutlineInputBorder()),
                    items: _weekdays
                        .map((day) =>
                            DropdownMenuItem(value: day, child: Text(day)))
                        .toList(),
                    onChanged: (value) {
                      setStateInDialog(() => initialDayOfWeek = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTimePickerTile(
                    context: dialogContext,
                    label: 'Hora de Entrada',
                    time: entryTime,
                    onTimePicked: (picked) =>
                        setStateInDialog(() => entryTime = picked),
                  ),
                  const SizedBox(height: 12),
                  _buildTimePickerTile(
                    context: dialogContext,
                    label: 'Hora de Salida',
                    time: exitTime,
                    onTimePicked: (picked) =>
                        setStateInDialog(() => exitTime = picked),
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
                      UiHelpers.showSnackBar(context, 'Selecciona ambas horas.',
                          isError: true);
                      return;
                    }
                    if (!dialogContext.mounted) return;

                    try {
                      final scheduleData = GroupSchedule(
                        id: initialDayOfWeek,
                        groupId: group.key,
                        schoolCycle: _currentSchoolCycle,
                        dayOfWeek: initialDayOfWeek,
                        entryTime: entryTime!.format(dialogContext),
                        exitTime: exitTime!.format(dialogContext),
                      );
                      await _groupSchedulesRef!
                          .child(group.key)
                          .child(initialDayOfWeek)
                          .set(scheduleData.toFirebaseMap());
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      UiHelpers.showSnackBar(context, 'Horario actualizado.');
                    } catch (e) {
                      UiHelpers.showSnackBar(
                          context, 'Error al guardar: ${e.toString()}',
                          isError: true);
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
  }) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(time?.format(context) ?? 'Seleccionar',
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _groups.isEmpty
                    ? Center(
                        child: Text('No hay grupos registrados.',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final schedulesForGroup =
                              _groupSchedules[group.key] ?? [];

                          return FadeInUp(
                            delay: Duration(milliseconds: 50 * index),
                            child: Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: isDark
                                    ? BorderSide.none
                                    : BorderSide(color: Colors.grey.shade200),
                              ),
                              color:
                                  isDark ? theme.cardTheme.color : Colors.white,
                              child: ExpansionTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: Text(group.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Semestre: ${group.semester}, Alumnos: ${group.studentCount}'),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade50,
                                  child: Icon(Icons.schedule,
                                      color: Colors.indigo.shade600),
                                ),
                                childrenPadding:
                                    const EdgeInsets.only(bottom: 12),
                                children: _weekdays.map((day) {
                                  final schedule = schedulesForGroup.firstWhere(
                                    (s) => s.dayOfWeek == day,
                                    orElse: () => GroupSchedule(
                                        id: '',
                                        groupId: group.key,
                                        schoolCycle: _currentSchoolCycle,
                                        dayOfWeek: day,
                                        entryTime: '',
                                        exitTime: ''),
                                  );
                                  final hasSchedule =
                                      schedule.entryTime.isNotEmpty &&
                                          schedule.exitTime.isNotEmpty;

                                  return ListTile(
                                    title: Text(day,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    subtitle: hasSchedule
                                        ? Text(
                                            '${schedule.entryTime} - ${schedule.exitTime}',
                                            style: TextStyle(
                                                color: theme.primaryColor))
                                        : const Text('Sin asignar',
                                            style:
                                                TextStyle(color: Colors.grey)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _editGroupSchedule(
                                              group,
                                              hasSchedule ? schedule : null),
                                        ),
                                        if (hasSchedule)
                                          IconButton(
                                            icon: Icon(Icons.delete_outline,
                                                color: theme.colorScheme.error),
                                            onPressed: () async {
                                              if (_groupSchedulesRef == null) {
                                                return;
                                              }
                                              final confirmed = await UiHelpers
                                                  .showConfirmationDialog(
                                                      context,
                                                      title: 'Borrar Horario',
                                                      content:
                                                          '¿Eliminar horario del $day para ${group.name}?',
                                                      isDestructive: true);
                                              if (confirmed) {
                                                try {
                                                  await _groupSchedulesRef!
                                                      .child(group.key)
                                                      .child(day)
                                                      .remove();
                                                  if (mounted) {
                                                    UiHelpers.showSnackBar(
                                                        context,
                                                        'Horario eliminado.');
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    UiHelpers.showSnackBar(
                                                        context,
                                                        'Error: ${e.toString()}',
                                                        isError: true);
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
