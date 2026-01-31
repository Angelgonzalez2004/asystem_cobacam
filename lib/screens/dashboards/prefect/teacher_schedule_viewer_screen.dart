import 'dart:async';
import 'package:async/async.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TeacherScheduleViewerScreen extends StatefulWidget {
  const TeacherScheduleViewerScreen({super.key});

  @override
  State<TeacherScheduleViewerScreen> createState() =>
      _TeacherScheduleViewerScreenState();
}

class _TeacherScheduleViewerScreenState
    extends State<TeacherScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;

  List<Teacher> _allTeachers = [];
  List<Teacher> _filteredTeachers = [];
  Map<String, GroupSchedule> _groupSchedules = {};
  Map<String, Group> _groupsMap = {};

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;

  bool _isLoading = true;
  String? _campus;

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _dataSubscription;

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
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _searchController.addListener(_filterTeachers);
    _initData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _searchController.removeListener(_filterTeachers);
    _searchController.dispose();
    super.dispose();
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

      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _selectedSchoolCycle = currentCycleId;
        });
        if (_selectedSchoolCycle != null) {
          _loadDataForCycle(_selectedSchoolCycle!);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadDataForCycle(String cycleId) {
    _dataSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _allTeachers = [];
      _filteredTeachers = [];
      _groupSchedules = {};
      _groupsMap = {};
    });

    final teachersRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/school_cycles/$cycleId/teachers');
    final schedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');
    final groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');

    // Combine streams to know when all data is loaded
    final dataStream = StreamZip([
      teachersRef.onValue,
      schedulesRef.onValue,
      groupsRef.orderByChild('schoolCycleId').equalTo(cycleId).onValue,
    ]);

    _dataSubscription = dataStream.listen((data) {
      // Data from teachersRef
      final teacherSnapshot = data[0].snapshot;
      final newTeachers = <Teacher>[];
      if (teacherSnapshot.exists) {
        for (final child in teacherSnapshot.children) {
          newTeachers.add(Teacher.fromSnapshot(child));
        }
      }

      // Data from schedulesRef
      final scheduleSnapshot = data[1].snapshot;
      final newSchedules = <String, GroupSchedule>{};
      if (scheduleSnapshot.exists) {
        for (final groupSnapshot in scheduleSnapshot.children) {
          newSchedules[groupSnapshot.key!] =
              GroupSchedule.fromSnapshot(groupSnapshot);
        }
      }

      // Data from groupsRef
      final groupSnapshot = data[2].snapshot;
      final newGroups = <String, Group>{};
       if (groupSnapshot.exists) {
        for (final child in groupSnapshot.children) {
          final group = Group.fromSnapshot(child);
          newGroups[group.key] = group;
        }
      }

      if (mounted) {
        setState(() {
          _allTeachers = newTeachers;
          _groupSchedules = newSchedules;
          _groupsMap = newGroups;
          _filterTeachers();
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if(mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar datos: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    });
  }

  void _filterTeachers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = _allTeachers
          .where((teacher) => teacher.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
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
                      : _filteredTeachers.isEmpty
                          ? Center(
                              child: Text(
                                _allTeachers.isEmpty
                                    ? "No hay personal docente en este ciclo."
                                    : "No se encontraron maestros con ese nombre.",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            )
                          : _buildTeacherList(theme),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                child: Text(c.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))))
            .toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedSchoolCycle = val);
            _loadDataForCycle(val);
            UiHelpers.showSnackBar(context, 'Cargando datos para el ciclo $val');
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar profesor por nombre...',
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

  Widget _buildTeacherList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            elevation: 2.0,
            shadowColor: Colors.black.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              title: Text(
                teacher.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              children: [
                _buildScheduleGrid(teacher.id, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleGrid(String teacherId, ThemeData theme) {
    final double headerHeight = 40.0;
    final double rowHeight = 70.0;
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

                      Map<String, dynamic>? sessionData;
                      try {
                        for (var schedule in _groupSchedules.values) {
                          final session = schedule.dailySchedules[day]?.firstWhere(
                            (s) => s.startTime == startTime && s.teacherId == teacherId);
                          if (session != null) {
                            sessionData = {
                              'session': session,
                              'groupName': _groupsMap[schedule.groupId]?.name ?? 'N/A'
                            };
                            break; 
                          }
                        }
                      } catch(e) {
                         sessionData = null;
                      }

                      if (isBreak) {
                        return Expanded(child: Container(color: Colors.teal.withOpacity(0.1), child: const Center(child: Text("Receso", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)))));
                      }
                      
                      final session = sessionData?['session'] as ClassSession?;
                      final groupName = sessionData?['groupName'] as String?;

                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          alignment: Alignment.center,
                          child: (session == null)
                              ? const Text('') // Empty for "Libre"
                              : FittedBox(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        session.subjectName,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      if (groupName != null && groupName.isNotEmpty)
                                      Text(
                                        groupName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 10),
                                      ),
                                    ],
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
