import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart'; // Import Group model
import 'package:asystem_cobacam/services/app_settings_service.dart'; // Import AppSettingsService
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle model
import 'package:asystem_cobacam/services/hive_service.dart'; // ADDED: Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // ADDED: Import ConnectivityService
import 'package:provider/provider.dart'; // ADDED: Import Provider

class StudentFormScreen extends StatefulWidget {
  final Student? student; // Null if adding new student, not null if editing
  final String campusId;
  final String currentSchoolCycle; // This is the *global current* cycle, not necessarily the student's cycle

  const StudentFormScreen({
    super.key,
    this.student,
    required this.campusId,
    required this.currentSchoolCycle,
  });

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _guardianFullNameController;
  late TextEditingController _ageController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _studentPhoneController;
  late TextEditingController _placeOfResidenceController;
  late TextEditingController _institutionalEmailController;
  late TextEditingController _studentIdController;

  String? _selectedGender;
  String? _selectedGroup; // To be populated from Firebase or a predefined list
  String? _selectedSchoolCycle; // Student's specific school cycle

  List<Group> _groups = [];
  List<SchoolCycle> _availableSchoolCycles = [];
  bool _isLoadingGroups = true;
  bool _isLoadingCycles = true;
  bool _isSaving = false;

  late final HiveService _hiveService; // ADDED: Declaration
  late final ConnectivityService _connectivityService; // ADDED: Declaration
  late final AppSettingsService _appSettingsService; // MODIFIED: to late final

  @override
  void initState() {
    super.initState();
    // ADDED: Initialize services
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);

    _fullNameController = TextEditingController(text: widget.student?.fullName ?? '');
    _guardianFullNameController = TextEditingController(text: widget.student?.guardianFullName ?? '');
    _ageController = TextEditingController(text: widget.student?.age.toString() ?? '');
    _guardianPhoneController = TextEditingController(text: widget.student?.guardianPhone ?? '');
    _studentPhoneController = TextEditingController(text: widget.student?.studentPhone ?? '');
    _placeOfResidenceController = TextEditingController(text: widget.student?.placeOfResidence ?? '');
    _institutionalEmailController = TextEditingController(text: widget.student?.institutionalEmail ?? '');
    _studentIdController = TextEditingController(text: widget.student?.studentId ?? '');

    _selectedGender = widget.student?.gender;
    _selectedGroup = widget.student?.group;
    _selectedSchoolCycle = widget.student?.schoolCycle ?? widget.currentSchoolCycle;
    _loadGroups(_selectedSchoolCycle); // Pass the initially selected school cycle
    _loadSchoolCycles();
  }

  Future<void> _loadSchoolCycles() async {
    try {
      final cycles = await _appSettingsService.getAllSchoolCycles();
      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _isLoadingCycles = false;
        });
      }
    } catch (e) {
      // TODO: Handle error properly
      if (mounted) {
        setState(() {
          _isLoadingCycles = false;
        });
      }
    }
  }

  Future<void> _loadGroups([String? schoolCycleId]) async {
    if (schoolCycleId == null) {
      if (mounted) setState(() => _isLoadingGroups = false);
      return;
    }
    try {
      final groupsSnapshot = await FirebaseDatabase.instance.ref('planteles/${widget.campusId}/groups')
          .orderByChild('schoolCycleId')
          .equalTo(schoolCycleId)
          .get();
      if (groupsSnapshot.exists) {
        final List<Group> fetchedGroups = [];
        for (final child in groupsSnapshot.children) {
          fetchedGroups.add(Group.fromSnapshot(child));
        }
        if (mounted) {
          setState(() {
            _groups = fetchedGroups;
            _isLoadingGroups = false;
            // If the previously selected group is not in the new list, reset it
            if (_selectedGroup != null && !_groups.any((group) => group.name == _selectedGroup)) {
              _selectedGroup = null;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _groups = [];
            _selectedGroup = null;
            _isLoadingGroups = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
          _groups = [];
          _selectedGroup = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar grupos: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _guardianFullNameController.dispose();
    _ageController.dispose();
    _guardianPhoneController.dispose();
    _studentPhoneController.dispose();
    _placeOfResidenceController.dispose();
    _institutionalEmailController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (!mounted) return;
    setState(() { _isSaving = true; });

    try {
      final databaseRef = FirebaseDatabase.instance.ref('planteles/${widget.campusId}/students/${_selectedSchoolCycle!}');

      final studentData = Student(
        id: _studentIdController.text, // Use studentId (matricula) as the unique ID
        fullName: _fullNameController.text,
        guardianFullName: _guardianFullNameController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        guardianPhone: _guardianPhoneController.text,
        studentPhone: _studentPhoneController.text.isNotEmpty ? _studentPhoneController.text : null,
        gender: _selectedGender!,
        placeOfResidence: _placeOfResidenceController.text,
        schoolCycle: _selectedSchoolCycle!,
        group: _selectedGroup!,
        institutionalEmail: _institutionalEmailController.text,
        studentId: _studentIdController.text,
        isActive: widget.student?.isActive ?? true, // Preserve existing status or default to true
      );

      // Using studentId as the key for the student in Firebase
      await databaseRef.child(studentData.studentId).set(studentData.toFirebaseMap());
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alumno registrado exitosamente!'), backgroundColor: Colors.green));
      if (!mounted) return;
      Navigator.pop(context, true); // Pop with true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar alumno: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingGroups || _isLoadingCycles || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600), // Max width for content
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(labelText: 'Nombre Completo del Alumno'),
                          validator: (value) => value!.isEmpty ? 'El nombre completo es obligatorio' : null,
                        ),
                        TextFormField(
                          controller: _studentIdController,
                          decoration: const InputDecoration(labelText: 'Matrícula del Alumno'),
                          validator: (value) => value!.isEmpty ? 'La matrícula es obligatoria' : null,
                          enabled: widget.student == null, // Matricula is immutable after creation
                        ),
                        TextFormField(
                          controller: _guardianFullNameController,
                          decoration: const InputDecoration(labelText: 'Nombre Completo del Tutor'),
                          validator: (value) => value!.isEmpty ? 'El nombre del tutor es obligatorio' : null,
                        ),
                        TextFormField(
                          controller: _ageController,
                          decoration: const InputDecoration(labelText: 'Edad del Alumno'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value!.isEmpty ? 'La edad es obligatoria' : null,
                        ),
                        TextFormField(
                          controller: _guardianPhoneController,
                          decoration: const InputDecoration(labelText: 'Teléfono del Tutor'),
                          keyboardType: TextInputType.phone,
                          validator: (value) => value!.isEmpty ? 'El teléfono del tutor es obligatorio' : null,
                        ),
                        TextFormField(
                          controller: _studentPhoneController,
                          decoration: const InputDecoration(labelText: 'Teléfono del Alumno (Opcional)'),
                          keyboardType: TextInputType.phone,
                        ),
                        TextFormField(
                          controller: _placeOfResidenceController,
                          decoration: const InputDecoration(labelText: 'Lugar de Residencia'),
                          validator: (value) => value!.isEmpty ? 'El lugar de residencia es obligatorio' : null,
                        ),
                        TextFormField(
                          controller: _institutionalEmailController,
                          decoration: const InputDecoration(labelText: 'Correo Institucional'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => value!.isEmpty ? 'El correo institucional es obligatorio' : null,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          decoration: const InputDecoration(labelText: 'Género'),
                          items: const [
                            DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                            DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                          ],
                          onChanged: (value) {
                            setState(() { _selectedGender = value; });
                          },
                          validator: (value) => value == null ? 'El género es obligatorio' : null,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSchoolCycle,
                          decoration: const InputDecoration(labelText: 'Ciclo Escolar'),
                          items: _availableSchoolCycles.map((cycle) => DropdownMenuItem(
                            value: cycle.id,
                            child: Text(cycle.id),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSchoolCycle = value;
                              _loadGroups(value); // Reload groups for the new cycle
                            });
                          },
                          validator: (value) => value == null ? 'El ciclo escolar es obligatorio' : null,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGroup,
                          decoration: InputDecoration(
                            labelText: 'Grupo',
                            helperText: _selectedSchoolCycle == null 
                                ? 'Seleccione un ciclo escolar primero' 
                                : (_groups.isEmpty ? 'No hay grupos disponibles para este ciclo' : null),
                          ),
                          items: _groups.map((group) => DropdownMenuItem(
                            value: group.key, // Use group.key as the value
                            child: Text(group.name),
                          )).toList(),
                          onChanged: _selectedSchoolCycle == null || _groups.isEmpty
                              ? null // Disable if no cycle selected or no groups
                              : (value) {
                                  setState(() { _selectedGroup = value; });
                                },
                          validator: (value) => value == null ? 'El grupo es obligatorio' : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveStudent,
                          child: Text(widget.student == null ? 'Registrar Alumno' : 'Actualizar Alumno'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
