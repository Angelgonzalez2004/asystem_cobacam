import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart'; // Import the Student model
import 'package:asystem_cobacam/screens/dashboards/prefect/student_form_screen.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart'; // Import AppSettingsService
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle model
import 'package:asystem_cobacam/screens/dashboards/prefect/student_excel_import_screen.dart';
import 'package:asystem_cobacam/services/hive_service.dart'; // ADDED: Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // ADDED: Import ConnectivityService
import 'package:provider/provider.dart'; // ADDED: Import Provider

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  late final HiveService _hiveService; // ADDED: Declaration
  late final ConnectivityService _connectivityService; // ADDED: Declaration
  late final AppSettingsService _appSettingsService; // MODIFIED: to late final
  DatabaseReference? _studentsRef;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;
  List<Student> _students = [];
  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = ''; // Initialize as empty, will be set dynamically
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedFilterSchoolCycle;

  @override
  void initState() {
    super.initState();
    // ADDED: Initialize services
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();
      final allCycles = await _appSettingsService.getAllSchoolCycles();

      if (!mounted) return;
      setState(() { 
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _availableSchoolCycles = allCycles;
        _selectedFilterSchoolCycle = dynamicSchoolCycle; // Initially filter by the current global cycle
      });
      
      _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');

      _studentsSubscription = _studentsRef!.onValue.listen((event) {
        final newStudents = <Student>[];
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            final student = Student.fromSnapshot(child);
            if (student.isActive) { // Only add active students
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar alumnos: ${error.toString()}'), backgroundColor: Colors.red));
        }
        setState(() => _isLoading = false);
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Campus no definido.'), backgroundColor: Colors.red));
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
    // The stream listener automatically updates the list, no need to manually refresh _initData()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentsRef == null
              ? const Center(child: Text('No se pudo cargar la información del plantel para alumnos.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600), // Max width for content
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedFilterSchoolCycle,
                                  decoration: const InputDecoration(
                                    labelText: 'Filtrar por Ciclo Escolar',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      _onFilterCycleChanged(newValue);
                                    }
                                  },
                                  items: _availableSchoolCycles.map<DropdownMenuItem<String>>((cycle) {
                                    return DropdownMenuItem<String>(
                                      value: cycle.id,
                                      child: Text(cycle.id),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.cloud_upload),
                                onPressed: () {
                                  if (_campus == null) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Campus no definido.'), backgroundColor: Colors.red));
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentExcelImportScreen(
                                        campusId: _campus!,
                                        currentSchoolCycle: _currentSchoolCycle,
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Importar Alumnos desde Excel',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _students.isEmpty
                              ? Center(child: Text('No hay alumnos registrados para el ciclo escolar $_selectedFilterSchoolCycle.'))
                              : ListView.builder(
                                  itemCount: _students.length,
                                  itemBuilder: (context, index) {
                                    final student = _students[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      child: ListTile(
                                        title: Text(student.fullName),
                                        subtitle: Text('Grupo: ${student.group} | Matrícula: ${student.studentId}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                if (_campus == null) {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Campus no definido.'), backgroundColor: Colors.red));
                                                  return;
                                                }
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => StudentFormScreen(
                                                      student: student,
                                                      campusId: _campus!,
                                                      currentSchoolCycle: _currentSchoolCycle,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                              onPressed: () => _confirmAndDeleteStudent(student),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            );
          }
  void _onFilterCycleChanged(String newCycleId) {
    if (_campus == null || newCycleId == _selectedFilterSchoolCycle) return;

    _studentsSubscription?.cancel(); // Cancel current subscription

    setState(() {
      _selectedFilterSchoolCycle = newCycleId;
      _isLoading = true; // Show loading indicator while new data is fetched
      _students = []; // Clear current list
    });

    _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar alumnos: ${error.toString()}'), backgroundColor: Colors.red));
      }
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _confirmAndDeleteStudent(Student student) async {
    final TextEditingController reasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Baja de Alumno'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Estás seguro de que quieres dar de baja a ${student.fullName}? Sus registros históricos se conservarán.'),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Motivo de la baja'),
                  validator: (value) => value!.isEmpty ? 'El motivo de la baja es obligatorio' : null,
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
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Dar de Baja'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deRegisterStudent(student, reasonController.text); // Pasar el motivo
    }
  }

  Future<void> _deRegisterStudent(Student student, String reason) async {
    if (_campus == null || _studentsRef == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Campus o referencia de alumnos no definida.'), backgroundColor: Colors.red));
      return;
    }

    try {
      // Perform a soft delete by setting isActive to false and adding deactivationReason
      await _studentsRef!.child(student.studentId).update({'isActive': false, 'deactivationReason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alumno ${student.fullName} dado de baja exitosamente por: $reason.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al dar de baja alumno: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }
}
