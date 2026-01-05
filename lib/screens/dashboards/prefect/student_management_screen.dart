import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart'; // Import the Student model
import 'package:asystem_cobacam/screens/dashboards/prefect/student_form_screen.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart'; // Import AppSettingsService
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle model
import 'package:asystem_cobacam/screens/dashboards/prefect/student_excel_import_screen.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;
  DatabaseReference? _studentsRef;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;
  List<Student> _students = [];
  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = '';
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedFilterSchoolCycle;

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
      final allCycles = await _appSettingsService.getAllSchoolCycles();

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _availableSchoolCycles = allCycles;
        _selectedFilterSchoolCycle = dynamicSchoolCycle;
      });

      _studentsRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');

      _studentsSubscription = _studentsRef!.onValue.listen((event) {
        final newStudents = <Student>[];
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            final student = Student.fromSnapshot(child);
            if (student.isActive) {
              newStudents.add(student);
            }
          }
        }
        setState(() {
          _students = newStudents;
          _isLoading = false;
        });
      }, onError: (error) {
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al cargar alumnos: ${error.toString()}',
              isError: true);
        }
        setState(() => _isLoading = false);
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    super.dispose();
  }

  void _showAddStudentDialog() async {
    if (_campus == null) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: Campus no definido.',
            isError: true);
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormScreen(
          campusId: _campus!,
          currentSchoolCycle: _currentSchoolCycle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _studentsRef == null
                      ? const Center(child: Text('Error cargando información.'))
                      : Column(
                          children: [
                            FadeInUp(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: isDark
                                        ? BorderSide.none
                                        : BorderSide(
                                            color: Colors.grey.shade200),
                                  ),
                                  color: isDark
                                      ? theme.cardTheme.color
                                      : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue:
                                                _selectedFilterSchoolCycle,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Filtrar por Ciclo Escolar',
                                              border: InputBorder.none,
                                              prefixIcon: Icon(
                                                  Icons.filter_alt_outlined),
                                            ),
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                _onFilterCycleChanged(newValue);
                                              }
                                            },
                                            items: _availableSchoolCycles
                                                .map<DropdownMenuItem<String>>(
                                                    (cycle) {
                                              return DropdownMenuItem<String>(
                                                value: cycle.id,
                                                child: Text(cycle.id),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        Container(
                                            height: 24,
                                            width: 1,
                                            color: Colors.grey.shade300,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 8)),
                                        IconButton(
                                          icon: Icon(
                                              Icons.cloud_upload_outlined,
                                              color:
                                                  theme.colorScheme.secondary),
                                          onPressed: () {
                                            if (_campus == null) {
                                              UiHelpers.showSnackBar(context,
                                                  'Error: Campus no definido.',
                                                  isError: true);
                                              return;
                                            }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    StudentExcelImportScreen(
                                                  campusId: _campus!,
                                                  currentSchoolCycle:
                                                      _currentSchoolCycle,
                                                ),
                                              ),
                                            );
                                          },
                                          tooltip: 'Importar Alumnos (Excel)',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _students.isEmpty
                                  ? Center(
                                      child: FadeInUp(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.people_outline,
                                                size: 64,
                                                color: Colors.grey.shade300),
                                            const SizedBox(height: 16),
                                            Text(
                                                'No hay alumnos en el ciclo $_selectedFilterSchoolCycle.',
                                                style: TextStyle(
                                                    color:
                                                        Colors.grey.shade500)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount: _students.length,
                                      itemBuilder: (context, index) {
                                        final student = _students[index];
                                        return FadeInUp(
                                          delay: Duration(
                                              milliseconds: 30 * index),
                                          child: Card(
                                            elevation: 0,
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: isDark
                                                  ? BorderSide.none
                                                  : BorderSide(
                                                      color:
                                                          Colors.grey.shade200),
                                            ),
                                            color: isDark
                                                ? theme.cardTheme.color
                                                : Colors.white,
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              leading: CircleAvatar(
                                                backgroundColor: theme
                                                    .colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                child: Text(student.fullName[0],
                                                    style: TextStyle(
                                                        color: theme.colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              title: Text(student.fullName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                          color: Colors.blue
                                                              .withValues(
                                                                  alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6)),
                                                      child: Text(
                                                          'Grupo: ${student.group}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.blue,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                        'ID: ${student.studentId}',
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.edit_outlined),
                                                    onPressed: () async {
                                                      if (_campus == null) {
                                                        return;
                                                      }
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              StudentFormScreen(
                                                            student: student,
                                                            campusId: _campus!,
                                                            currentSchoolCycle:
                                                                _currentSchoolCycle,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons
                                                            .person_remove_outlined,
                                                        color: theme
                                                            .colorScheme.error),
                                                    onPressed: () =>
                                                        _confirmAndDeleteStudent(
                                                            student),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
            ),
          );
        },
      ),
    );
  }

  void _onFilterCycleChanged(String newCycleId) {
    if (_campus == null || newCycleId == _selectedFilterSchoolCycle) return;

    _studentsSubscription?.cancel();

    setState(() {
      _selectedFilterSchoolCycle = newCycleId;
      _isLoading = true;
      _students = [];
    });

    _studentsRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');
    _studentsSubscription = _studentsRef!.onValue.listen((event) {
      final newStudents = <Student>[];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          newStudents.add(Student.fromSnapshot(child));
        }
      }
      if (mounted) {
        setState(() {
          _students = newStudents;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'Error al cargar alumnos: ${error.toString()}',
            isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _confirmAndDeleteStudent(Student student) async {
    final TextEditingController reasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Baja'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '¿Dar de baja a ${student.fullName}? Se conservará el historial.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                      labelText: 'Motivo de la baja',
                      border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white),
              child: const Text('Dar de Baja'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deRegisterStudent(student, reasonController.text);
    }
  }

  Future<void> _deRegisterStudent(Student student, String reason) async {
    if (_campus == null || _studentsRef == null) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: Referencia no definida.',
            isError: true);
      }
      return;
    }

    try {
      await _studentsRef!
          .child(student.studentId)
          .update({'isActive': false, 'deactivationReason': reason});
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Alumno dado de baja exitosamente.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al dar de baja: ${e.toString()}',
            isError: true);
      }
    }
  }
}
