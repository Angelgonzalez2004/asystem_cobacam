import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/schedule_models.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_groups_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_subjects_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_teachers_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/schedule_builder_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// View model for a unique course assigned to a teacher
class AssignedCourse {
  final String subjectName;
  final String groupName;
  final String subjectId;
  final String groupId;

  AssignedCourse({required this.subjectName, required this.groupName, required this.subjectId, required this.groupId});

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
  bool _isLoading = true;
  String? _teacherId;
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
      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      final userName = userData['fullName'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      
      final campusRef = FirebaseDatabase.instance.ref('planteles/$campus');

      // Fetch metadata first
      final results = await Future.wait([
        campusRef.child('teachers').get(),
        campusRef.child('subjects').get(),
        campusRef.child('groups').get(),
      ]);

      final teachers = _extractData(results[0], (snap) => Teacher.fromSnapshot(snap));
      _subjects = _extractData(results[1], (snap) => Subject.fromSnapshot(snap));
      _groups = _extractData(results[2], (snap) => Group.fromSnapshot(snap));
      
      // Find teacher key that corresponds to the logged-in user
      final currentTeacher = teachers.firstWhere((t) => t.name == userName, orElse: () => Teacher(key: '', name: '', subjects: []));
      if (currentTeacher.key.isEmpty) {
         throw Exception('El usuario actual no está registrado como maestro en este plantel.');
      }
      setState(() { _teacherId = currentTeacher.key; });

      // Now listen to the schedule
      _scheduleSubscription = campusRef.child('schedule').onValue.listen((event) {
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
            orElse: () =>
                Group(key: '', name: 'N/A', semester: 0, studentCount: 0, schoolCycleId: ''));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  List<T> _extractData<T>(DataSnapshot snapshot, T Function(DataSnapshot) fromSnapshot) {
    if (!snapshot.exists) return [];
    return snapshot.children.map((child) => fromSnapshot(child)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2.0,
            child: ExpansionTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text('Administración de Horarios', style: theme.textTheme.titleLarge),
              subtitle: const Text('Gestionar datos maestros para la generación de horarios'),
              initiallyExpanded: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_pin_rounded),
                  title: const Text('Gestionar Maestros'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTeachersScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: const Text('Gestionar Materias'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageSubjectsScreen())),
                ),
                 ListTile(
                  leading: const Icon(Icons.class_outlined),
                  title: const Text('Gestionar Grupos y Aulas'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageGroupsScreen())),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

           Card(
            elevation: 2.0,
            child: ListTile(
              leading: Icon(Icons.grid_on_sharp, color: theme.colorScheme.secondary, size: 40),
              title: Text('Constructor de Horarios', style: theme.textTheme.titleLarge),
              subtitle: const Text('Asignar clases, maestros y grupos de forma manual.'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleBuilderScreen())),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 24.0, bottom: 8.0, left: 8.0, right: 8.0),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Mis Cursos Asignados', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),

          _assignedCourses.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No tienes cursos asignados en el horario actual.'),
                ))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _assignedCourses.length,
                  itemBuilder: (context, index) {
                    final course = _assignedCourses[index];
                    return Card(
                      elevation: 2.0,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.subjectName,
                              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text('Grupo: ${course.groupName}', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.people_alt_outlined),
                                  label: const Text('Ver Alumnos'),
                                  onPressed: () {},
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Pase de Lista'),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
