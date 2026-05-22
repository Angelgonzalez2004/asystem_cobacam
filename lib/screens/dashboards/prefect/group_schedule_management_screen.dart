import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/edit_session_dialog.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';

import 'package:provider/provider.dart';

class GroupScheduleManagementScreen extends StatefulWidget {
  final bool isReadOnlyUser;
  const GroupScheduleManagementScreen({super.key, this.isReadOnlyUser = false});

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
  DatabaseReference? _teachersRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;

  List<Group> _allGroups = [];
  List<Group> _filteredGroups = [];
  Map<String, GroupSchedule> _groupSchedules = {};
  List<Teacher> _teachers = [];

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  bool _isReadOnly = false;

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

      _checkCycleStatus();
      await _loadDataForCycle(_selectedSchoolCycle!);
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkCycleStatus() {
    if (_selectedSchoolCycle == null || _availableSchoolCycles.isEmpty) return;
    try {
      final cycle = _availableSchoolCycles
          .firstWhere((c) => c.id == _selectedSchoolCycle);
      final now = DateTime.now();
      _isReadOnly = now.isAfter(cycle.endDate.add(const Duration(days: 1)));
    } catch (e) {
      _isReadOnly = false;
    }
    setState(() {});
  }



  Future<void> _loadTeachers() async {
    if (_teachersRef == null) return;
    final snapshot = await _teachersRef!.get();
    if (snapshot.exists) {
      final newTeachers = <Teacher>[];
      for (final child in snapshot.children) {
        newTeachers.add(Teacher.fromSnapshot(child));
      }
      if (mounted) {
        setState(() {
          _teachers = newTeachers;
        });
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
      _teachers = [];
    });

    // Update refs to point to the correct cycle
    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    _groupSchedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');
    _teachersRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/school_cycles/$cycleId/teachers');
    
    await _loadTeachers();

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
          _filterGroups(); // Initial filter
        });
        _loadSchedules(); // This will set _isLoading to false when done
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
    _searchController.removeListener(_filterGroups);
    _searchController.dispose();
    super.dispose();
  }

  double _parseTimeToDouble(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final double hour = double.parse(parts[0]);
      final double minute = double.parse(parts[1]);
      return hour + (minute / 60.0);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _editClassSession(Group group, String day, ClassSession session) async {
    if (_isReadOnly || widget.isReadOnlyUser) {
      UiHelpers.showSnackBar(context, 'No se pueden modificar horarios en este modo.', isError: true);
      return;
    }

    final result = await showDialog<ClassSession?>(
      context: context,
      builder: (context) => EditSessionDialog(
        session: session,
        availableTeachers: _teachers,
      ),
    );

    if (result != null) {
      // Validate teacher conflicts if assigning a teacher
      if (result.subjectId != 'DELETE_SESSION' && result.teacherId != null) {
        String? conflictingGroup;
        String? conflictingTime;

        final double rStart = _parseTimeToDouble(result.startTime);
        final double rEnd = _parseTimeToDouble(result.endTime);

        for (var entry in _groupSchedules.entries) {
          if (entry.key == group.key) continue; // Skip the group currently being edited
          final dailySessions = entry.value.dailySchedules[day] ?? [];
          for (var s in dailySessions) {
            if (s.teacherId == result.teacherId) {
              final double sStart = _parseTimeToDouble(s.startTime);
              final double sEnd = _parseTimeToDouble(s.endTime);

              // Check for overlap: rStart < sEnd && sStart < rEnd
              if (rStart < sEnd && sStart < rEnd) {
                final groupObj = _allGroups.firstWhere(
                  (g) => g.key == entry.key,
                  orElse: () => Group(
                    key: '',
                    name: 'Otro Grupo',
                    semester: 0,
                    schoolCycleId: '',
                    studentCount: 0,
                  ),
                );
                conflictingGroup = groupObj.name;
                conflictingTime = '${s.startTime} - ${s.endTime}';
                break;
              }
            }
          }
          if (conflictingGroup != null) break;
        }

        if (conflictingGroup != null) {
          final confirmConflict = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Conflicto de Docente'),
                ],
              ),
              content: Text(
                'El docente ${result.teacherName} ya está asignado al grupo "$conflictingGroup" el día $day en el horario $conflictingTime.\n\n¿Deseas guardar de todos modos y generar esta coincidencia (por ejemplo, para clases compartidas o co-docencia)?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar de todos modos'),
                ),
              ],
            ),
          );

          if (confirmConflict != true) {
            return; // Abort saving
          }
        }
      }

      GroupSchedule schedule = _groupSchedules[group.key] ??
          GroupSchedule(
            id: group.key,
            groupId: group.key,
            schoolCycle: _selectedSchoolCycle!,
            dailySchedules: {},
          );

      List<ClassSession> daySessions = schedule.dailySchedules[day] ?? [];
      daySessions.removeWhere((s) => s.startTime == session.startTime);

      if (result.subjectId != 'DELETE_SESSION') {
        daySessions.add(result);
      }

      daySessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      schedule.dailySchedules[day] = daySessions;
      await _saveScheduleForGroup(group, schedule);
    }
  }

  Future<void> _saveScheduleForGroup(Group group, GroupSchedule schedule) async {
    if (_groupSchedulesRef == null) return;

    try {
      await _groupSchedulesRef!.child(group.key).set(schedule.toFirebaseMap());
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Horario del grupo ${group.name} actualizado.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al guardar: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                _buildHeader(theme, isDark),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredGroups.isEmpty
                          ? Center(
                              child: Text(
                                _allGroups.isEmpty
                                  ? "No hay grupos en este ciclo."
                                  : "No se encontraron grupos.",
                                style: const TextStyle(color: Colors.grey)
                              ),
                            )
                          : _buildGroupList(theme),
                ),
              ],
            ),
          ),
        );
      }),

    );
  }
  
  Widget _buildHeader(ThemeData theme, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.cardTheme.color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: _buildCycleSelector()),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
            if (widget.isReadOnlyUser) _buildReadOnlyUserBanner(), // User role-based read-only
            if (_isReadOnly) _buildReadOnlyBanner(), // Cycle status-based read-only
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyUserBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.blue),
          SizedBox(width: 6),
          Text("Modo Solo Consulta: Contactar a Académica para ediciones.",
              style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCycleSelector() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedSchoolCycle,
        isExpanded: true,
        hint: const Text("Seleccionar Ciclo Escolar"),
        items: _availableSchoolCycles
            .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))
            .toList(),
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
    );
  }
  
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar grupo(s) por nombre (ej. 101, 303)...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
  
  Widget _buildReadOnlyBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 14, color: Color(0xFFD32F2F)),
          SizedBox(width: 6),
          Text("Ciclo Cerrado - Solo Lectura",
              style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGroupList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredGroups[index];
        final schedule = _groupSchedules[group.key];

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            elevation: 2.0,
            shadowColor: Colors.black.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Semestre: ${group.semester}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (schedule == null && _isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ScheduleDisplayWidget(
                      title: group.name,
                      subtitle: "Semestre: ${group.semester}",
                      scheduleData: schedule?.dailySchedules ?? {},
                      viewType: 'group',
                      mainTitle: 'Gestión de Horario',
                      campusName: _campus ?? 'N/A',
                      logoPath: 'assets/images/logo1.png',
                      onSessionTap: (widget.isReadOnlyUser || _isReadOnly)
                          ? null
                          : (session, day, startTime, endTime) {
                              if (_isReadOnly) { // This check is redundant due to above, but kept for historical context if _isReadOnly changes meaning
                                UiHelpers.showSnackBar(context,
                                    'Ciclo cerrado. No se pueden modificar horarios.',
                                    isError: true);
                                return;
                              }
                              _editClassSession(group, day, session!);
                            },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}