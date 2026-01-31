import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/edit_session_dialog.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/manage_cycle_teachers_screen.dart';
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

  final List<String> _weekdays = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes'
  ];
  
  final List<Map<String, String>> _timeSlots = const [
    {'start': '07:00', 'end': '07:50'},
    {'start': '07:50', 'end': '08:40'},
    {'start': '08:40', 'end': '09:30'},
    {'start': '09:30', 'end': '09:50'}, // Receso
    {'start': '09:50', 'end': '10:40'},
    {'start': '10:40', 'end': '11:30'},
    {'start': '11:30', 'end': '12:20'},
    {'start': '12:20', 'end': '13:10'},
    {'start': '13:10', 'end': '14:00'},
  ];

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
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGroups = _allGroups
          .where((group) => group.name.toLowerCase().contains(query))
          .toList();
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

  Future<void> _editClassSession(Group group, String day, ClassSession session) async {
    if (_isReadOnly) {
      UiHelpers.showSnackBar(context, 'Ciclo cerrado. No se pueden modificar horarios.', isError: true);
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton.small(
          heroTag: 'manage_teachers',
          onPressed: () {
            if (_campus != null && _selectedSchoolCycle != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageCycleTeachersScreen(
                    campusId: _campus!,
                    schoolCycleId: _selectedSchoolCycle!,
                  ),
                ),
              );
            } else {
              UiHelpers.showSnackBar(context, 'Selecciona un ciclo escolar primero.', isError: true);
            }
          },
          tooltip: 'Gestionar Personal Docente',
          child: const Icon(Icons.person),
        ),
      ),
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
            if (_isReadOnly) _buildReadOnlyBanner(),
          ],
        ),
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
        hintText: 'Buscar grupo por nombre...',
        prefixIcon: const Icon(Icons.search),
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

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

              child: ExpansionTile(

                tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

                title: Text(

                  group.name,

                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                ),

                subtitle: Text(

                  "Semestre: ${group.semester}",

                  style: TextStyle(color: Colors.grey.shade600),

                ),

                children: [

                   if (schedule == null && _isLoading)

                    const Padding(

                      padding: EdgeInsets.all(32.0),

                      child: Center(child: CircularProgressIndicator()),

                    )

                  else

                    _buildScheduleGrid(group, schedule, theme),

                ],

              ),

            ),

          );

        },

      );

    }

  

    Widget _buildScheduleGrid(Group group, GroupSchedule? schedule, ThemeData theme) {
      final double headerHeight = 40.0;
      final double rowHeight = 80.0;
      final double timeColumnWidth = 80.0;
      
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 1.5),
          child: Column(
            children: [
              // Header Row
              Container(
                height: headerHeight,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  )
                ),
                child: Row(
                  children: [
                    SizedBox(width: timeColumnWidth),
                    ..._weekdays.map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
              // Schedule Rows
              ..._timeSlots.map((slot) {
                final startTime = slot['start']!;
                final isBreak = startTime == '09:30';
  
                return Container(
                  height: rowHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Time Column
                      SizedBox(
                        width: timeColumnWidth,
                        child: Center(
                          child: Text(
                            "${slot['start']!}\n${slot['end']!}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      // Day Cells
                      ..._weekdays.map((day) {
                        final dailySessions = schedule?.dailySchedules[day] ?? [];
                         ClassSession? session;
                        try {
                          session = dailySessions.firstWhere((s) => s.startTime == startTime);
                        } catch(e) {
                          session = null;
                        }
  
                        if (isBreak) {
                          return Expanded(child: Container(color: Colors.teal.withOpacity(0.1), child: const Center(child: Text("Receso", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)))));
                        }
  
                        return Expanded(
                          child: InkWell(
                            onTap: _isReadOnly ? null : () {
                              final sessionToEdit = session ?? ClassSession(startTime: startTime, endTime: slot['end']!);
                              _editClassSession(group, day, sessionToEdit);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              alignment: Alignment.center,
                              child: (session == null)
                                  ? Icon(Icons.add_circle_outline, color: Colors.grey.shade400)
                                  : FittedBox(
                                    child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            session.subjectName,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          if (session.teacherName?.isNotEmpty ?? false)
                                          Text(
                                            session.teacherName!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 10),
                                          ),
                                          if (!_isReadOnly)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade500),
                                            )
                                        ],
                                      ),
                                  ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }
  }

  