import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/subject_model.dart';
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
  DatabaseReference? _subjectsRef;
  DatabaseReference? _teachersRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;

  List<Group> _allGroups = [];
  List<Group> _filteredGroups = [];
  Map<String, GroupSchedule> _groupSchedules = {};
  List<Subject> _subjects = [];
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
      
      _subjectsRef = FirebaseDatabase.instance.ref('subjects');
      _teachersRef = FirebaseDatabase.instance.ref('teachers');

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId =
          await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() {
        _availableSchoolCycles = cycles;
        _selectedSchoolCycle = currentCycleId;
      });

      _checkCycleStatus();
      await _loadSubjects();
      await _loadTeachers();
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

  Future<void> _loadSubjects() async {
    if (_subjectsRef == null) return;
    final snapshot = await _subjectsRef!.get();
    if (snapshot.exists) {
      final newSubjects = <Subject>[];
      for (final child in snapshot.children) {
        newSubjects.add(Subject.fromSnapshot(child));
      }
      if (mounted) {
        setState(() {
          _subjects = newSubjects;
        });
      }
    }
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
    });

    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    _groupSchedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');

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
        _loadSchedules();
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
        availableSubjects: _subjects,
        availableTeachers: _teachers,
        groupSemester: group.semester,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredGroups[index];
        final schedule = _groupSchedules[group.key];

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: DefaultTabController(
            length: _weekdays.length,
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Semestre: ${group.semester}", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    TabBar(
                      isScrollable: true,
                      tabs: _weekdays.map((day) => Tab(text: day)).toList(),
                    ),
                    SizedBox(
                      height: 450, // Fixed height for the schedule view
                      child: TabBarView(
                        children: _weekdays.map((day) {
                          final dailySessions = schedule?.dailySchedules[day] ?? [];
                          return _buildDaySchedule(group, day, dailySessions, theme);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDaySchedule(Group group, String day, List<ClassSession> sessions, ThemeData theme) {
    return ListView.builder(
      itemCount: _timeSlots.length,
      itemBuilder: (context, index) {
        final slot = _timeSlots[index];
        final startTime = slot['start']!;
        
        ClassSession? session;
        try {
          session = sessions.firstWhere((s) => s.startTime == startTime);
        } catch (e) {
          session = null;
        }

        final isBreak = startTime == '09:30';
        final isFree = session == null && !isBreak;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          color: isBreak ? Colors.cyan.shade50 : (isFree ? Colors.grey.shade100 : theme.colorScheme.surface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: SizedBox(
              width: 80,
              child: Text(
                "${slot['start']!}\n${slot['end']!}",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isBreak ? Colors.cyan.shade800 : theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
            title: Text(
              isBreak ? "Receso" : (isFree ? "Libre" : session!.subjectName),
              style: TextStyle(
                fontWeight: isFree ? FontWeight.normal : FontWeight.bold,
                color: isFree ? Colors.grey.shade700 : theme.textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: (isFree || isBreak || session?.teacherName == null)
                ? null
                : Text(session!.teacherName!, style: TextStyle(color: Colors.grey.shade600)),
            trailing: _isReadOnly
                ? null
                : IconButton(
                    icon: Icon(
                      isFree ? Icons.add_circle_outline : Icons.edit,
                      color: isFree ? theme.colorScheme.primary : Colors.grey.shade500,
                    ),
                    onPressed: isBreak ? null : () {
                      final sessionToEdit = session ?? ClassSession(startTime: startTime, endTime: slot['end']!);
                      _editClassSession(group, day, sessionToEdit);
                    },
                  ),
          ),
        );
      },
    );
  }
}