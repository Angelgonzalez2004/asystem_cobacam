import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GeneralScheduleManagementScreen extends StatefulWidget {
  const GeneralScheduleManagementScreen({super.key});

  @override
  State<GeneralScheduleManagementScreen> createState() =>
      _GeneralScheduleManagementScreenState();
}

class _GeneralScheduleManagementScreenState
    extends State<GeneralScheduleManagementScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  DatabaseReference? _groupsRef;
  DatabaseReference? _groupSchedulesRef;
  DatabaseReference? _studentsRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;

  List<Group> _allGroups = [];
  List<Group> _filteredGroups = [];
  Map<String, GroupSchedule> _groupSchedules = {};
  Map<String, int> _groupRealStudentCounts = {};

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;

  bool _isLoading = true;
  String? _campus;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
    _searchController.addListener(_filterGroups);
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
      _campus = userData['campus'];

      if (_campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId =
          await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() {
        _availableSchoolCycles = cycles;
        _selectedSchoolCycle = currentCycleId;
      });

      await _loadDataForCycle(_selectedSchoolCycle!);
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDataForCycle(String cycleId) async {
    if (_campus == null) return;

    setState(() {
      _isLoading = true;
      _allGroups = [];
      _filteredGroups = [];
      _groupSchedules = {};
      _groupRealStudentCounts = {};
    });

    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    _groupSchedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');
    _studentsRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/students/$cycleId');

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
        setState(() {
          _allGroups = newGroups;
          _filterGroups();
        });
        _loadSchedules();
      }
    });

    _studentsSubscription?.cancel();
    _studentsSubscription = _studentsRef!.onValue.listen((event) {
      final Map<String, int> newCounts = {};
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          try {
            final data = Map<String, dynamic>.from(child.value as Map);
            final isActive = data['isActive'] ?? true;
            if (isActive) {
              final groupName = data['group'] as String?;
              if (groupName != null && groupName.isNotEmpty) {
                newCounts[groupName] = (newCounts[groupName] ?? 0) + 1;
              }
            }
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          _groupRealStudentCounts = newCounts;
        });
      }
    });
  }

  void _loadSchedules() {
    _groupSchedulesSubscription?.cancel();
    _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
      final newSchedules = <String, GroupSchedule>{};
      if (event.snapshot.exists) {
        for (final groupSnapshot in event.snapshot.children) {
          newSchedules[groupSnapshot.key!] =
              GroupSchedule.fromSnapshot(groupSnapshot);
        }
      }
      if (mounted) {
        setState(() {
          _groupSchedules = newSchedules;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _filterGroups() {
    final rawQuery = _searchController.text.toLowerCase();
    final searchTerms = rawQuery
        .split(',')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();

    setState(() {
      if (searchTerms.isEmpty) {
        _filteredGroups = _allGroups;
      } else {
        _filteredGroups = _allGroups
            .where((group) =>
                searchTerms.any((term) => group.name.toLowerCase().contains(term)))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    _studentsSubscription?.cancel();
    _searchController.removeListener(_filterGroups);
    _searchController.dispose();
    super.dispose();
  }

  bool _isDetailedSchedule(GroupSchedule? schedule) {
    if (schedule == null || schedule.dailySchedules.isEmpty) return false;
    for (final sessions in schedule.dailySchedules.values) {
      if (sessions.length > 1) return true;
      for (final session in sessions) {
        if (session.subjectName != 'Horario General') return true;
      }
    }
    return false;
  }

  bool _isUniformSchedule(GroupSchedule? schedule) {
    if (schedule == null || schedule.dailySchedules.isEmpty) return true;
    String? firstStart;
    String? firstEnd;

    for (final day in ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes']) {
      final sessions = schedule.dailySchedules[day];
      if (sessions == null || sessions.isEmpty) continue;
      final firstSession = sessions.first;
      if (firstStart == null) {
        firstStart = firstSession.startTime;
        firstEnd = firstSession.endTime;
      } else {
        if (firstSession.startTime != firstStart || firstSession.endTime != firstEnd) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, String>? _getGeneralHours(GroupSchedule? schedule) {
    if (schedule == null || schedule.dailySchedules.isEmpty) return null;

    String? earliestStart;
    String? latestEnd;

    schedule.dailySchedules.forEach((day, sessions) {
      for (final session in sessions) {
        if (earliestStart == null || session.startTime.compareTo(earliestStart!) < 0) {
          earliestStart = session.startTime;
        }
        if (latestEnd == null || session.endTime.compareTo(latestEnd!) > 0) {
          latestEnd = session.endTime;
        }
      }
    });

    if (earliestStart == null || latestEnd == null) return null;
    return {'start': earliestStart!, 'end': latestEnd!};
  }

  Future<void> _showEditDialog(Group group, GroupSchedule? schedule) async {
    final bool isDetailed = _isDetailedSchedule(schedule);
    final hours = _getGeneralHours(schedule);

    final List<String> weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    final Map<String, TimeOfDay> tempEntries = {};
    final Map<String, TimeOfDay> tempExits = {};

    for (final day in weekdays) {
      TimeOfDay dayEntry = const TimeOfDay(hour: 7, minute: 0);
      TimeOfDay dayExit = const TimeOfDay(hour: 14, minute: 0);

      if (schedule != null && schedule.dailySchedules.containsKey(day)) {
        final sessions = schedule.dailySchedules[day];
        if (sessions != null && sessions.isNotEmpty) {
          try {
            final firstSession = sessions.first;
            final eParts = firstSession.startTime.split(':');
            dayEntry = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
            final exParts = firstSession.endTime.split(':');
            dayExit = TimeOfDay(hour: int.parse(exParts[0]), minute: int.parse(exParts[1]));
          } catch (_) {}
        }
      } else if (hours != null) {
        try {
          final eParts = hours['start']!.split(':');
          dayEntry = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
          final exParts = hours['end']!.split(':');
          dayExit = TimeOfDay(hour: int.parse(exParts[0]), minute: int.parse(exParts[1]));
        } catch (_) {}
      }
      tempEntries[day] = dayEntry;
      tempExits[day] = dayExit;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? theme.cardColor : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurar Horario',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Grupo: ${group.name}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDetailed) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '¡ALERTA IMPORTANTE!\nEste grupo ya cuenta con un horario de clases detallado cargado por Académica. Si guardas un Horario General, SOBRESCRIBIRÁS todas las materias y sesiones registradas.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'El horario general establece las horas reglamentarias para el control de asistencia diario (lunes a viernes, entre las 07:00 AM y las 02:00 PM). Cada día de la semana puede tener horarios diferentes.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        children: weekdays.map((day) {
                          return _buildDailyTimePickerRow(
                            context: context,
                            day: day,
                            entryTime: tempEntries[day]!,
                            exitTime: tempExits[day]!,
                            isDark: isDark,
                            onEditEntry: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: tempEntries[day]!,
                              );
                              if (selected != null) {
                                setDialogState(() {
                                  tempEntries[day] = selected;
                                });
                              }
                            },
                            onEditExit: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: tempExits[day]!,
                              );
                              if (selected != null) {
                                setDialogState(() {
                                  tempExits[day] = selected;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
                if (schedule != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Limpiar Horario'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final confirm = await UiHelpers.showConfirmationDialog(
                        context,
                        title: '¿Eliminar horario?',
                        content: 'Se borrará el horario configurado para el grupo ${group.name}. Esta acción no se puede deshacer.',
                        confirmText: 'Sí, eliminar',
                        cancelText: 'Cancelar',
                        isDestructive: true,
                      );
                      if (confirm && context.mounted) {
                        Navigator.pop(context, {'clear': true});
                      }
                    },
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () {
                    for (final day in weekdays) {
                      final entry = tempEntries[day]!;
                      final exit = tempExits[day]!;

                      final double eDouble = entry.hour + entry.minute / 60.0;
                      final double exDouble = exit.hour + exit.minute / 60.0;

                      if (eDouble >= exDouble) {
                        UiHelpers.showSnackBar(
                          context,
                          'En $day, la hora de entrada debe ser anterior a la de salida.',
                          isError: true,
                        );
                        return;
                      }
                      if (eDouble < 7.0) {
                        UiHelpers.showSnackBar(
                          context,
                          'En $day, el horario de entrada no puede ser anterior a las 07:00 AM.',
                          isError: true,
                        );
                        return;
                      }
                      if (exDouble > 14.0) {
                        UiHelpers.showSnackBar(
                          context,
                          'En $day, el horario de salida no puede ser posterior a las 02:00 PM (14:00).',
                          isError: true,
                        );
                        return;
                      }
                    }

                    Navigator.pop(context, {
                      'entries': tempEntries,
                      'exits': tempExits,
                    });
                  },
                  child: const Text('Guardar Horario', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result.containsKey('clear')) {
        await _clearSchedule(group);
      } else {
        final entries = result['entries'] as Map<String, TimeOfDay>;
        final exits = result['exits'] as Map<String, TimeOfDay>;
        await _saveGeneralSchedule(group, entries, exits);
      }
    }
  }

  Widget _buildDailyTimePickerRow({
    required BuildContext context,
    required String day,
    required TimeOfDay entryTime,
    required TimeOfDay exitTime,
    required bool isDark,
    required VoidCallback onEditEntry,
    required VoidCallback onEditExit,
  }) {
    final theme = Theme.of(context);
    Color dayColor;
    switch (day) {
      case 'Lunes':
        dayColor = const Color(0xFF3B82F6);
        break;
      case 'Martes':
        dayColor = const Color(0xFF0D9488);
        break;
      case 'Miércoles':
        dayColor = const Color(0xFF6366F1);
        break;
      case 'Jueves':
        dayColor = const Color(0xFF8B5CF6);
        break;
      case 'Viernes':
        dayColor = const Color(0xFFF97316);
        break;
      default:
        dayColor = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dayColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEditEntry,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.login_rounded, size: 14, color: dayColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ENTRADA',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entryTime.format(context),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onEditExit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.01) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, size: 14, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SALIDA',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  exitTime.format(context),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGeneralSchedule(
    Group group,
    Map<String, TimeOfDay> entries,
    Map<String, TimeOfDay> exits,
  ) async {
    if (_groupSchedulesRef == null) return;

    final List<String> weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    final Map<String, List<ClassSession>> dailySchedules = {};

    for (final day in weekdays) {
      final entry = entries[day] ?? const TimeOfDay(hour: 7, minute: 0);
      final exit = exits[day] ?? const TimeOfDay(hour: 14, minute: 0);

      final String entryStr = '${entry.hour.toString().padLeft(2, '0')}:${entry.minute.toString().padLeft(2, '0')}';
      final String exitStr = '${exit.hour.toString().padLeft(2, '0')}:${exit.minute.toString().padLeft(2, '0')}';

      dailySchedules[day] = [
        ClassSession(
          startTime: entryStr,
          endTime: exitStr,
          subjectName: 'Horario General',
          subjectId: 'GENERAL',
          teacherName: 'Por asignar',
        )
      ];
    }

    final schedule = GroupSchedule(
      id: group.key,
      groupId: group.key,
      schoolCycle: _selectedSchoolCycle!,
      dailySchedules: dailySchedules,
    );

    try {
      setState(() => _isLoading = true);
      await _groupSchedulesRef!.child(group.key).set(schedule.toFirebaseMap());
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Horario general de ${group.name} guardado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al guardar: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearSchedule(Group group) async {
    if (_groupSchedulesRef == null) return;

    try {
      setState(() => _isLoading = true);
      await _groupSchedulesRef!.child(group.key).remove();
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Horario de ${group.name} eliminado.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al eliminar: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(builder: (context, constraints) {
        final double width = constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, isDark, width),
                _buildDashboardStats(theme, isDark, width),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Lista de Grupos (${_filteredGroups.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[750],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando información en tiempo real...',
                                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : _filteredGroups.isEmpty
                          ? Center(
                              child: FadeIn(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isDark ? theme.cardColor : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.search_off_rounded,
                                        size: 60,
                                        color: theme.colorScheme.primary.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _allGroups.isEmpty
                                          ? "No hay grupos en este ciclo escolar."
                                          : "No se encontraron resultados para tu búsqueda.",
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_allGroups.isNotEmpty)
                                      TextButton.icon(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        label: const Text('Limpiar filtros de búsqueda'),
                                        onPressed: () => _searchController.clear(),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : _buildGroupList(theme, isDark, width),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDashboardStats(ThemeData theme, bool isDark, double width) {
    final int totalGroups = _allGroups.length;
    final int generalSchedules = _groupSchedules.values.where((s) => !_isDetailedSchedule(s)).length;
    final int detailedSchedules = _groupSchedules.values.where((s) => _isDetailedSchedule(s)).length;
    final int totalStudents = _groupRealStudentCounts.values.fold(0, (sum, val) => sum + val);

    final List<Map<String, dynamic>> stats = [
      {
        'title': 'Grupos Registrados',
        'value': totalGroups.toString(),
        'subtitle': 'Total en ciclo actual',
        'icon': Icons.grid_view_rounded,
        'color': Colors.indigo,
      },
      {
        'title': 'Horarios Generales',
        'value': generalSchedules.toString(),
        'subtitle': 'Configurados por Prefecta',
        'icon': Icons.schedule_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Horarios Detallados',
        'value': detailedSchedules.toString(),
        'subtitle': 'Subidos por Académica',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.teal,
      },
      {
        'title': 'Alumnos Totales',
        'value': totalStudents.toString(),
        'subtitle': 'Registrados en el ciclo',
        'icon': Icons.people_alt_rounded,
        'color': Colors.orange,
      },
    ];

    int crossAxisCount = 2;
    double childAspectRatio = 2.0;
    if (width >= 960) {
      crossAxisCount = 4;
      childAspectRatio = 2.2;
    } else if (width >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 2.4;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.45;
    }

    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            final Color statColor = stat['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor.withOpacity(0.6) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? statColor.withOpacity(0.15) : statColor.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statColor.withOpacity(isDark ? 0.02 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat['icon'] as IconData, color: statColor, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat['value'] as String,
                          style: TextStyle(
                            fontSize: width < 600 ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stat['title'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          stat['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark, double width) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.8)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_rounded, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'PLANTEL: ${_campus?.toUpperCase() ?? 'CARGANDO...'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Control General de Horarios',
                        style: TextStyle(
                          fontSize: width < 600 ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gestiona el horario de entrada y salida para el pase de lista de los grupos en el ciclo escolar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (width >= 800) ...[
                  const SizedBox(width: 20),
                  Hero(
                    tag: 'prefect_shield',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: theme.colorScheme.primary,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (width >= 700)
              Row(
                children: [
                  Expanded(flex: 3, child: _buildSearchBar(theme, isDark)),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildCycleSelectorContainer(theme, isDark)),
                ],
              )
            else
              Column(
                children: [
                  _buildCycleSelectorContainer(theme, isDark),
                  const SizedBox(height: 12),
                  _buildSearchBar(theme, isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSelectorContainer(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? theme.scaffoldBackgroundColor.withOpacity(0.5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSchoolCycle,
                isExpanded: true,
                dropdownColor: isDark ? theme.cardColor : Colors.white,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                hint: const Text("Seleccionar Ciclo"),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.primary),
                items: _availableSchoolCycles
                    .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.id)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSchoolCycle = val;
                      _loadDataForCycle(val);
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar grupo por nombre o semestre...',
        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? theme.scaffoldBackgroundColor.withOpacity(0.5) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList(ThemeData theme, bool isDark, double width) {
    int crossAxisCount = 1;
    double childAspectRatio = 2.1;

    if (width >= 960) {
      crossAxisCount = 3;
      childAspectRatio = 1.5;
    } else if (width >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.6;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 2.1;
    }

    if (width < 380) {
      childAspectRatio = 1.8;
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _filteredGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredGroups[index];
        final schedule = _groupSchedules[group.key];
        final bool isDetailed = _isDetailedSchedule(schedule);
        final hours = _getGeneralHours(schedule);

        Color statusColor;
        String statusTitle;
        IconData statusIcon;
        List<Color> cardGradient;

        if (schedule != null) {
          if (isDetailed) {
            statusColor = Colors.teal;
            statusTitle = "Horario Detallado";
            statusIcon = Icons.assignment_rounded;
            cardGradient = isDark 
                ? [theme.cardColor, theme.cardColor.withOpacity(0.8)] 
                : [Colors.white, Colors.teal.shade50.withOpacity(0.3)];
          } else {
            statusColor = Colors.blue;
            statusTitle = "Horario General";
            statusIcon = Icons.timer_rounded;
            cardGradient = isDark 
                ? [theme.cardColor, theme.cardColor.withOpacity(0.8)] 
                : [Colors.white, Colors.blue.shade50.withOpacity(0.3)];
          }
        } else {
          statusColor = const Color(0xFF64748B);
          statusTitle = "Sin Horario";
          statusIcon = Icons.calendar_today_rounded;
          cardGradient = isDark 
              ? [theme.cardColor, theme.cardColor.withOpacity(0.8)] 
              : [Colors.white, Colors.white];
        }

        final int studentCount = _groupRealStudentCounts[group.name] ?? 0;

        return FadeInUp(
          delay: Duration(milliseconds: 30 * index),
          duration: const Duration(milliseconds: 500),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: schedule != null
                    ? statusColor.withOpacity(isDark ? 0.25 : 0.4)
                    : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                width: schedule != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showEditDialog(group, schedule),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                group.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 10, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusTitle,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.layers_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                "Sem.: ${group.semester}",
                                style: TextStyle(
                                  color: isDark ? Colors.grey[350] : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.people_outline_rounded, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                "$studentCount Alum.",
                                style: TextStyle(
                                  color: isDark ? Colors.grey[350] : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (hours != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_filled_rounded, size: 13, color: statusColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _isUniformSchedule(schedule)
                                          ? '${hours['start']} - ${hours['end']}'
                                          : 'L-V: Variable (${hours['start']} - ${hours['end']})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  if (isDetailed)
                                    Text(
                                      'Detallado',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    )
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 13, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Sin horario asignado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
