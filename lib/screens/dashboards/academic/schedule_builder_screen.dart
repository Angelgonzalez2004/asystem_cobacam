import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/schedule_models.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_groups_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_subjects_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_teachers_screen.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:gal/gal.dart'; // <--- NUEVA LIBRERÍA
import 'package:asystem_cobacam/data/educational_centers.dart';

class ScheduleBuilderScreen extends StatefulWidget {
  const ScheduleBuilderScreen({super.key});

  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen> {
  final _screenshotController = ScreenshotController();
  bool _isLoading = true;
  String? _campus;
  Map<String, String>? _schoolInfo;
  bool _isSearching = false;

  // Data lists for dropdowns
  List<Teacher> _teachers = [];
  List<Subject> _subjects = [];
  List<Group> _groups = [];
  List<Classroom> _classrooms = [];

  // Schedule data
  DatabaseReference? _scheduleRef;
  Map<String, ClassAssignment> _schedule = {};
  StreamSubscription? _scheduleSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // To store the current search query

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _initData();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _searchController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _runGreedyGenerator() async {
    if (_scheduleRef == null ||
        _campus == null ||
        _teachers.isEmpty ||
        _subjects.isEmpty ||
        _groups.isEmpty ||
        _classrooms.isEmpty) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context,
          'Asegúrate de tener maestros, materias, grupos y aulas registrados.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    int assignedCount = 0;

    // Clear existing schedule before generating a new one
    await _scheduleRef!.remove();
    _schedule.clear(); // Clear local cache as well

    try {
      final List<Map<String, dynamic>> potentialAssignments = [];
      // Prepare all possible combinations of (teacher, subject, group, classroom)
      for (var teacher in _teachers) {
        for (var subject in _subjects) {
          for (var group in _groups) {
            for (var classroom in _classrooms) {
              potentialAssignments.add({
                'teacherId': teacher.key,
                'subjectId': subject.key,
                'groupId': group.key,
                'classroomId': classroom.key,
              });
            }
          }
        }
      }

      for (int dayIndex = 0; dayIndex < DIAS_SEMANA.length; dayIndex++) {
        for (int timeSlotIndex = 0;
            timeSlotIndex < HORARIOS.length;
            timeSlotIndex++) {
          if (HORARIOS[timeSlotIndex].isRecess) continue; // Skip recess

          final slotKey = '$dayIndex-$timeSlotIndex';

          // If the slot is already assigned (e.g., from a previous manual assignment)
          if (_schedule.containsKey(slotKey)) continue;

          // Try to find a valid assignment for this slot
          for (var assignmentData in potentialAssignments) {
            final String? selectedTeacherId = assignmentData['teacherId'];
            final String? selectedGroupId = assignmentData['groupId'];
            final String? selectedClassroomId = assignmentData['classroomId'];

            // Simulate conflict check for this potential assignment
            bool conflictFound = false;
            final existingConflicts = _schedule.entries
                .where((entry) => entry.key.endsWith('-$timeSlotIndex'));

            if (existingConflicts
                .any((entry) => entry.value.teacherId == selectedTeacherId)) {
              conflictFound = true;
            }
            if (existingConflicts
                .any((entry) => entry.value.groupId == selectedGroupId)) {
              conflictFound = true;
            }
            if (existingConflicts.any(
                (entry) => entry.value.classroomId == selectedClassroomId)) {
              conflictFound = true;
            }

            if (!conflictFound) {
              // Assign this class
              await _scheduleRef!.child(slotKey).set(assignmentData);
              assignedCount++;
              // Move to the next slot (greedy choice)
              break;
            }
          }
        }
      }
      if (!mounted) return;
      UiHelpers.showSnackBar(
          context, 'Generación finalizada. $assignedCount clases asignadas.');
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Error en la generación: ${e.toString()}',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No auth user');

      final userProfileSnapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) {
        throw Exception('Cannot find user profile');
      }

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('User has no assigned campus');

      setState(() {
        _campus = campus;
        _schoolInfo = getEducationalCenterInfo(campus);
      });

      final campusRef = FirebaseDatabase.instance.ref('planteles/$campus');
      _scheduleRef = campusRef.child('schedule');

      // Fetch all data in parallel for efficiency
      final results = await Future.wait([
        campusRef.child('teachers').get(),
        campusRef.child('subjects').get(),
        campusRef.child('groups').get(),
        campusRef.child('classrooms').get(),
      ]);

      _teachers =
          _extractData(results[0], (snap) => Teacher.fromSnapshot(snap));
      _subjects =
          _extractData(results[1], (snap) => Subject.fromSnapshot(snap));
      _groups = _extractData(results[2], (snap) => Group.fromSnapshot(snap));
      _classrooms =
          _extractData(results[3], (snap) => Classroom.fromSnapshot(snap));

      // Listen for schedule updates
      _scheduleSubscription = _scheduleRef!.onValue.listen((event) {
        final newSchedule = <String, ClassAssignment>{};
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            newSchedule[child.key!] = ClassAssignment.fromSnapshot(child);
          }
        }
        setState(() {
          _schedule = newSchedule;
        });
      });
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<T> _extractData<T>(
      DataSnapshot snapshot, T Function(DataSnapshot) fromSnapshot) {
    if (!snapshot.exists) return [];
    return snapshot.children.map((child) => fromSnapshot(child)).toList();
  }

  void _showAssignmentDialog(int dayIndex, int timeSlotIndex) {
    if (_isLoading || _campus == null) return;
    String? selectedTeacherId;
    String? selectedSubjectId;
    String? selectedGroupId;
    String? selectedClassroomId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              'Asignar Clase - ${DIAS_SEMANA[dayIndex]} - ${HORARIOS[timeSlotIndex]}'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown<Teacher>(
                        _teachers,
                        (t) => t.name,
                        selectedTeacherId,
                        'Seleccionar Maestro',
                        (id) => setState(() => selectedTeacherId = id)),
                    _buildDropdown<Subject>(
                        _subjects,
                        (s) => s.name,
                        selectedSubjectId,
                        'Seleccionar Materia',
                        (id) => setState(() => selectedSubjectId = id)),
                    _buildDropdown<Group>(
                        _groups,
                        (g) => g.name,
                        selectedGroupId,
                        'Seleccionar Grupo',
                        (id) => setState(() => selectedGroupId = id)),
                    _buildDropdown<Classroom>(
                        _classrooms,
                        (c) => c.name,
                        selectedClassroomId,
                        'Seleccionar Aula',
                        (id) => setState(() => selectedClassroomId = id)),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!context.mounted) return;
                if (selectedTeacherId == null ||
                    selectedSubjectId == null ||
                    selectedGroupId == null ||
                    selectedClassroomId == null) {
                  if (!context.mounted) return;
                  UiHelpers.showSnackBar(
                      context, 'Por favor, complete todos los campos.',
                      isError: true);
                  return;
                }

                // --- Conflict Detection Logic ---
                final key = '$dayIndex-$timeSlotIndex';
                final conflictingAssignments = _schedule.entries.where((entry) {
                  // Check all other slots at the same time
                  return entry.key.endsWith('-$timeSlotIndex') &&
                      entry.key != key;
                });

                final teacherConflict = conflictingAssignments
                    .any((entry) => entry.value.teacherId == selectedTeacherId);
                if (teacherConflict) {
                  if (!context.mounted) return;
                  UiHelpers.showSnackBar(
                      context, 'Conflicto: El maestro ya tiene clase.',
                      isError: true);
                  return;
                }

                final groupConflict = conflictingAssignments
                    .any((entry) => entry.value.groupId == selectedGroupId);
                if (groupConflict) {
                  if (!context.mounted) return;
                  UiHelpers.showSnackBar(
                      context, 'Conflicto: El grupo ya tiene clase.',
                      isError: true);
                  return;
                }

                final classroomConflict = conflictingAssignments.any(
                    (entry) => entry.value.classroomId == selectedClassroomId);
                if (classroomConflict) {
                  if (!context.mounted) return;
                  UiHelpers.showSnackBar(
                      context, 'Conflicto: El aula ya está ocupada.',
                      isError: true);
                  return;
                }
                // --- End of Conflict Detection ---

                await _scheduleRef?.child(key).set({
                  'teacherId': selectedTeacherId,
                  'subjectId': selectedSubjectId,
                  'groupId': selectedGroupId,
                  'classroomId': selectedClassroomId,
                });
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  DropdownButtonFormField<String> _buildDropdown<T>(
      List<T> items,
      String Function(T) getName,
      String? selectedId,
      String label,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: items
          .map<DropdownMenuItem<String>>((item) => DropdownMenuItem(
                // <--- Se especificó el tipo
                value: (item as dynamic).key as String,
                child: Text(getName(item), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar horario...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              )
            : const Text('Constructor de Horarios'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: theme.colorScheme.onSurface),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
            tooltip: _isSearching ? 'Cerrar Búsqueda' : 'Buscar Horario',
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: theme.colorScheme.secondary),
            onPressed: _runGreedyGenerator,
            tooltip: 'Generar Automáticamente',
          ),
          IconButton(
            icon: Icon(Icons.download, color: theme.colorScheme.primary),
            onPressed: _captureAndSave,
            tooltip: 'Guardar Imagen',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campus == null || _schoolInfo == null
              ? const Center(
                  child: Text(
                      'Error: No se pudo determinar la información del plantel.'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final convertedSchedule = _convertScheduleToDisplayFormat();
                    return Center(
                      child: SingleChildScrollView(
                        // Allow full page scroll if needed vertically
                        child: SingleChildScrollView(
                          // Horizontal scroll for the table
                          scrollDirection: Axis.horizontal,
                          child: Screenshot(
                            controller: _screenshotController,
                            child: ScheduleDisplayWidget(
                              title: 'Horario: ${_schoolInfo!['name']!}',
                              subtitle:
                                  '${_schoolInfo!['municipio']!} - Clave: ${_schoolInfo!['clave']!}',
                              scheduleData: convertedSchedule,
                              viewType: 'builder', // Custom view type for builder
                              mainTitle: 'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
                              campusName: _schoolInfo!['name']!,
                              logoPath: 'assets/images/logo1.png',
                              onSessionTap: (session, day, startTime, endTime) {
                                final dayIndex = DIAS_SEMANA.indexOf(day);
                                final timeSlotIndex = HORARIOS.indexWhere(
                                    (slot) => slot.startTime == startTime);
                                if (dayIndex != -1 && timeSlotIndex != -1) {
                                  _showAssignmentDialog(dayIndex, timeSlotIndex);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // --- CONFIGURACIÓN DE PERMISOS PARA GAL ---
  //
  // Android:
  // Agrega esto a tu `android/app/src/main/AndroidManifest.xml` dentro del tag <manifest>:
  // <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
  // (Gal no requiere permisos extra en Android 10+ para guardar imágenes)
  //
  // iOS:
  // Agrega esto a `ios/Runner/Info.plist`:
  // <key>NSPhotoLibraryAddUsageDescription</key>
  // <string>Necesitamos permiso para guardar el horario en tu galería.</string>
  //
  // -----------------------------------------------------------------

  Future<void> _captureAndSave() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Capturar la imagen
      final image = await _screenshotController.capture();
      if (image == null) {
        if (!mounted) return;
        UiHelpers.showSnackBar(context, 'No se pudo capturar el horario.',
            isError: true);
        return;
      }

      // 2. Guardar usando Gal (Nueva Librería)
      // putImageBytes lanza una excepción si falla, así que usamos try-catch
      await Gal.putImageBytes(image,
          name: 'horario_${DateTime.now().millisecondsSinceEpoch}');

      if (!mounted) return;
      UiHelpers.showSnackBar(
          context, 'Horario guardado en la galería correctamente.');
    } on GalException catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Error de galería: ${e.type.message}',
          isError: true);
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Error al guardar: ${e.toString()}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, List<ClassSession>> _convertScheduleToDisplayFormat() {
    final Map<String, List<ClassSession>> displaySchedule = {};
    final query = _searchQuery.toLowerCase();

    _schedule.forEach((key, assignment) {
      final parts = key.split('-');
      final dayIndex = int.parse(parts[0]);

      final subject = _subjects.firstWhere((s) => s.key == assignment.subjectId,
          orElse: () => Subject(key: '', name: 'N/A', code: ''));
      final teacher = _teachers.firstWhere((t) => t.key == assignment.teacherId,
          orElse: () => Teacher(key: '', name: 'N/A', subjects: []));
      final group = _groups.firstWhere((g) => g.key == assignment.groupId,
          orElse: () => Group(key: '', name: 'N/A', semester: 0, studentCount: 0, schoolCycleId: ''));

      final classSession = ClassSession(
        startTime: HORARIOS[int.parse(parts[1])].startTime,
        endTime: HORARIOS[int.parse(parts[1])].endTime,
        subjectId: assignment.subjectId,
        teacherId: assignment.teacherId,
        groupId: assignment.groupId,
        classroomId: assignment.classroomId,
        subjectName: subject.name,
        teacherName: teacher.name,
        groupName: group.name,
      );

      // Apply search filter here
      if (query.isEmpty ||
          classSession.subjectName.toLowerCase().contains(query) ||
          classSession.teacherName.toLowerCase().contains(query) ||
          classSession.groupName.toLowerCase().contains(query)) {
        final dayName = DIAS_SEMANA[dayIndex];
        displaySchedule.putIfAbsent(dayName, () => []).add(classSession);
      }
    });

    // Sort sessions by start time for each day
    displaySchedule.values.forEach((sessions) {
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    return displaySchedule;
  }


}
