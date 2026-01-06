import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/schedule_models.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_groups_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_subjects_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_teachers_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/schedule_builder_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// View model for a unique course assigned to a teacher
class AssignedCourse {
  final String subjectName;
  final String groupName;
  final String subjectId;
  final String groupId;

  AssignedCourse(
      {required this.subjectName,
      required this.groupName,
      required this.subjectId,
      required this.groupId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignedCourse &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          groupId == other.groupId;

  @override
  int get hashCode => subjectId.hashCode ^ groupId.hashCode;
}

class AcademicHomeScreen extends StatefulWidget {
  const AcademicHomeScreen({super.key});

  @override
  State<AcademicHomeScreen> createState() => _AcademicHomeScreenState();
}

class _AcademicHomeScreenState extends State<AcademicHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  bool _isLoading = true;
  String? _teacherId;
  String? _campus;
  List<AssignedCourse> _assignedCourses = [];

  StreamSubscription? _scheduleSubscription;
  StreamSubscription? _userSubscription;

  List<Subject> _subjects = [];
  List<Group> _groups = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    _userSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _handleError('No hay usuario autenticado.');
        return;
      }
      _loadDataForUser(user);
    });
  }

  Future<void> _loadDataForUser(User user) async {
    try {
      final userProfileSnapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      final userName = userData['fullName'];
      if (campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }
      
      setState(() {
        _campus = campus;
      });

      final campusRef = FirebaseDatabase.instance.ref('planteles/$campus');

      // Fetch metadata first
      final results = await Future.wait([
        campusRef.child('teachers').get(),
        campusRef.child('subjects').get(),
        campusRef.child('groups').get(),
      ]);

      final teachers =
          _extractData(results[0], (snap) => Teacher.fromSnapshot(snap));
      _subjects =
          _extractData(results[1], (snap) => Subject.fromSnapshot(snap));
      _groups = _extractData(results[2], (snap) => Group.fromSnapshot(snap));

      // Find teacher key that corresponds to the logged-in user
      final currentTeacher = teachers.firstWhere((t) => t.name == userName,
          orElse: () => Teacher(key: '', name: '', subjects: []));
      if (currentTeacher.key.isEmpty) {
        throw Exception(
            'El usuario actual no está registrado como maestro en este plantel.');
      }
      setState(() {
        _teacherId = currentTeacher.key;
      });

      // Now listen to the schedule
      _scheduleSubscription =
          campusRef.child('schedule').onValue.listen((event) {
        _processSchedule(event.snapshot);
      });
    } catch (e) {
      _handleError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processSchedule(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      if (mounted) {
        setState(() => _assignedCourses = []);
      }
      return;
    }
    final Set<AssignedCourse> courses = {};

    for (final childSnapshot in snapshot.children) {
      final assignment = ClassAssignment.fromSnapshot(childSnapshot);
      if (assignment.teacherId == _teacherId) {
        final subject = _subjects.firstWhere(
            (s) => s.key == assignment.subjectId,
            orElse: () => Subject(key: '', name: 'N/A', code: ''));
        final group = _groups.firstWhere((g) => g.key == assignment.groupId,
            orElse: () => Group(
                key: '',
                name: 'N/A',
                semester: 0,
                studentCount: 0,
                schoolCycleId: ''));
        courses.add(AssignedCourse(
          subjectName: subject.name,
          groupName: group.name,
          subjectId: subject.key,
          groupId: group.key,
        ));
      }
    }
    if (mounted) {
      setState(() => _assignedCourses = courses.toList());
    }
  }

  void _handleError(String error) {
    if (mounted) {
      UiHelpers.showSnackBar(context, 'Error: $error', isError: true);
      setState(() => _isLoading = false);
    }
  }

  List<T> _extractData<T>(
      DataSnapshot snapshot, T Function(DataSnapshot) fromSnapshot) {
    if (!snapshot.exists) return [];
    return snapshot.children.map((child) => fromSnapshot(child)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildSectionHeader(theme, 'Administración Académica'),
                const SizedBox(height: 16),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.shade200)),
                    color: isDark ? theme.cardTheme.color : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildAdminTile(
                              context,
                              'Gestionar Maestros',
                              Icons.person_pin_rounded,
                              Colors.blue.shade500,
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ManageTeachersScreen()))),
                          Divider(
                              height: 32,
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                          _buildAdminTile(
                              context,
                              'Gestionar Materias',
                              Icons.book_outlined,
                              Colors.orange.shade500,
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ManageSubjectsScreen()))),
                          Divider(
                              height: 32,
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                          _buildAdminTile(
                              context,
                              'Gestionar Grupos y Aulas',
                              Icons.class_outlined,
                              Colors.purple.shade500,
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ManageGroupsScreen()))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.grid_view_rounded,
                            color: Colors.white, size: 24),
                      ),
                      title: Text('Constructor de Horarios',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle:
                          const Text('Asignar clases, maestros y grupos.'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ScheduleBuilderScreen())),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Announcements Section
                _buildSectionHeader(theme, 'Avisos'),
                const SizedBox(height: 16),
                StreamBuilder<List<AnnouncementModel>>(
                  stream: _announcementService.getAnnouncementsStream(_campus, false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No hay avisos recientes."));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return AnnouncementCard(announcement: snapshot.data![index]);
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 32),

                _buildSectionHeader(theme, 'Mis Cursos Asignados'),
                const SizedBox(height: 16),
                _assignedCourses.isEmpty
                    ? FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.class_outlined,
                                  size: 60, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text('No tienes cursos asignados actualmente.',
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(color: theme.disabledColor)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _assignedCourses.length,
                        itemBuilder: (context, index) {
                          final course = _assignedCourses[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: 100 * index),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              decoration: BoxDecoration(
                                  color: isDark
                                      ? theme.cardTheme.color
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.transparent
                                          : Colors.grey.shade100),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ]),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(20),
                                title: Text(
                                  course.subjectName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.people_outline,
                                          size: 16,
                                          color: theme
                                              .textTheme.bodyMedium?.color),
                                      const SizedBox(width: 6),
                                      Text('Grupo: ${course.groupName}',
                                          style: theme.textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                          const Icon(Icons.fact_check_outlined),
                                      tooltip: 'Pase de Lista',
                                      color: theme.colorScheme.secondary,
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 18),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  // Navigate to course details
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }

