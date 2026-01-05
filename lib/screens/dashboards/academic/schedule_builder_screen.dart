import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/schedule_models.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_groups_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_subjects_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_teachers_screen.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
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

  // Data lists for dropdowns
  List<Teacher> _teachers = [];
  List<Subject> _subjects = [];
  List<Group> _groups = [];
  List<Classroom> _classrooms = [];

  // Schedule data
  DatabaseReference? _scheduleRef;
  Map<String, ClassAssignment> _schedule = {};
  StreamSubscription? _scheduleSubscription;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
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
            if (existingConflicts
                .any((entry) => entry.value.classroomId == selectedClassroomId)) {
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
        title: const Text('Constructor de Horarios'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        actions: [
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
                    return Center(
                      child: SingleChildScrollView(
                        // Allow full page scroll if needed vertically
                        child: SingleChildScrollView(
                          // Horizontal scroll for the table
                          scrollDirection: Axis.horizontal,
                          child: Screenshot(
                            controller: _screenshotController,
                            child: Container(
                              color: isDark
                                  ? theme.scaffoldBackgroundColor
                                  : Colors.white,
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(_schoolInfo!['name']!,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Text(
                                      '${_schoolInfo!['municipio']!} - Clave: ${_schoolInfo!['clave']!}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: Colors.grey)),
                                  const SizedBox(height: 24),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey
                                              .withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          theme.colorScheme.primary
                                              .withValues(alpha: 0.05)),
                                      dataRowColor: WidgetStateProperty.all(
                                          isDark
                                              ? theme.cardTheme.color
                                              : Colors.white),
                                      columns: _buildColumns(theme),
                                      rows: _buildRows(theme),
                                      border: TableBorder(
                                        horizontalInside: BorderSide(
                                            color: Colors.grey
                                                .withValues(alpha: 0.2)),
                                        verticalInside: BorderSide(
                                            color: Colors.grey
                                                .withValues(alpha: 0.2)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  List<DataColumn> _buildColumns(ThemeData theme) {
    return [
      DataColumn(
          label: Text('Hora',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary))),
      ...DIAS_SEMANA.map((day) => DataColumn(
          label: Text(day,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface)))),
    ];
  }

  List<DataRow> _buildRows(ThemeData theme) {
    return HORARIOS.asMap().entries.map((entry) {
      final timeSlotIndex = entry.key;
      final timeSlot = entry.value;

      if (timeSlot.isRecess) {
        return DataRow(
          color: WidgetStateProperty.all(
              theme.colorScheme.secondary.withValues(alpha: 0.1)),
          cells: List.generate(DIAS_SEMANA.length + 1, (index) {
            if (index == 0) {
              return DataCell(Center(
                  child: Text(timeSlot.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary))));
            }
            if (index == 3) {
              return DataCell(Center(
                  child: Text('R E C E S O',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                          letterSpacing: 2))));
            }
            return const DataCell(SizedBox());
          }),
        );
      }

      return DataRow(
        cells: [
          DataCell(Text(timeSlot.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500))),
          ...DIAS_SEMANA.asMap().entries.map((dayEntry) {
            final dayIndex = dayEntry.key;
            final assignment = _schedule['$dayIndex-$timeSlotIndex'];
            return DataCell(
              _buildCell(assignment, dayIndex, timeSlotIndex, theme),
              onTap: () => _showAssignmentDialog(dayIndex, timeSlotIndex),
            );
          }),
        ],
      );
    }).toList();
  }

  Widget _buildCell(ClassAssignment? assignment, int dayIndex,
      int timeSlotIndex, ThemeData theme) {
    if (assignment == null) {
      return Center(
          child:
              Icon(Icons.add_rounded, color: Colors.grey.shade300, size: 20));
    }

    // Find the names from the IDs
    final subject = _subjects
        .firstWhere((s) => s.key == assignment.subjectId,
            orElse: () => Subject(key: '', name: 'N/A', code: ''))
        .name;
    final teacher = _teachers
        .firstWhere((t) => t.key == assignment.teacherId,
            orElse: () => Teacher(key: '', name: 'N/A', subjects: []))
        .name;
    final group = _groups
        .firstWhere((g) => g.key == assignment.groupId,
            orElse: () => Group(
                key: '',
                name: 'N/A',
                semester: 0,
                studentCount: 0,
                schoolCycleId: ''))
        .name;
    final classroom = _classrooms
        .firstWhere((c) => c.key == assignment.classroomId,
            orElse: () => Classroom(key: '', name: 'N/A', capacity: 0))
        .name;

    return Tooltip(
      message:
          'Materia: $subject\nMaestro: $teacher\nGrupo: $group\nAula: $classroom',
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(6),
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(subject,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary),
                overflow: TextOverflow.ellipsis),
            Text(group,
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurface)),
            Text(teacher.split(' ').last,
                style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            Text(classroom,
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.secondary)),
          ],
        ),
      ),
    );
  }
}
