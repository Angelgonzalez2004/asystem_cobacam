import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
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
  final String
      currentSchoolCycle; // This is the *global current* cycle, not necessarily the student's cycle

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
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);

    _fullNameController =
        TextEditingController(text: widget.student?.fullName ?? '');
    _guardianFullNameController =
        TextEditingController(text: widget.student?.guardianFullName ?? '');
    _ageController =
        TextEditingController(text: widget.student?.age.toString() ?? '');
    _guardianPhoneController =
        TextEditingController(text: widget.student?.guardianPhone ?? '');
    _studentPhoneController =
        TextEditingController(text: widget.student?.studentPhone ?? '');
    _placeOfResidenceController =
        TextEditingController(text: widget.student?.placeOfResidence ?? '');
    _institutionalEmailController =
        TextEditingController(text: widget.student?.institutionalEmail ?? '');
    _studentIdController =
        TextEditingController(text: widget.student?.studentId ?? '');

    _selectedGender = widget.student?.gender;
    _selectedGroup = widget.student?.group;
    _selectedSchoolCycle =
        widget.student?.schoolCycle ?? widget.currentSchoolCycle;
    _loadGroups(
        _selectedSchoolCycle); // Pass the initially selected school cycle
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
      if (mounted) setState(() => _isLoadingCycles = false);
    }
  }

  Future<void> _loadGroups([String? schoolCycleId]) async {
    if (schoolCycleId == null) {
      if (mounted) setState(() => _isLoadingGroups = false);
      return;
    }
    try {
      final groupsSnapshot = await FirebaseDatabase.instance
          .ref('planteles/${widget.campusId}/groups')
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
            if (_selectedGroup != null &&
                !_groups.any((group) => group.name == _selectedGroup)) {
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
        UiHelpers.showSnackBar(context, 'Error al cargar grupos.',
            isError: true);
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
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    try {
      final databaseRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campusId}/students/${_selectedSchoolCycle!}');

      final studentData = Student(
        id: _studentIdController.text,
        fullName: _fullNameController.text,
        guardianFullName: _guardianFullNameController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        guardianPhone: _guardianPhoneController.text,
        studentPhone: _studentPhoneController.text.isNotEmpty
            ? _studentPhoneController.text
            : null,
        gender: _selectedGender!,
        placeOfResidence: _placeOfResidenceController.text,
        schoolCycle: _selectedSchoolCycle!,
        group: _selectedGroup!,
        institutionalEmail: _institutionalEmailController.text,
        studentId: _studentIdController.text,
        isActive: widget.student?.isActive ?? true,
      );

      await databaseRef
          .child(studentData.studentId)
          .set(studentData.toFirebaseMap());

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Alumno guardado correctamente.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.student == null ? 'Nuevo Alumno' : 'Editar Alumno'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingGroups || _isLoadingCycles || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : FadeInUp(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: isDark
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade200),
                      ),
                      color: isDark ? theme.cardTheme.color : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSectionTitle(theme, 'Datos del Alumno'),
                              const SizedBox(height: 16),
                              _buildTextField(_fullNameController,
                                  'Nombre Completo', Icons.person_outline),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                          _studentIdController,
                                          'Matrícula',
                                          Icons.badge_outlined,
                                          enabled: widget.student == null)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      flex: 1,
                                      child: _buildTextField(_ageController,
                                          'Edad', Icons.cake_outlined,
                                          keyboardType: TextInputType.number)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildGenderDropdown(theme),
                              const SizedBox(height: 32),
                              _buildSectionTitle(theme, 'Académico'),
                              const SizedBox(height: 16),
                              _buildCycleDropdown(theme),
                              const SizedBox(height: 12),
                              _buildGroupDropdown(theme),
                              const SizedBox(height: 32),
                              _buildSectionTitle(theme, 'Contacto y Tutor'),
                              const SizedBox(height: 16),
                              _buildTextField(
                                  _guardianFullNameController,
                                  'Nombre del Tutor',
                                  Icons.family_restroom_outlined),
                              const SizedBox(height: 12),
                              _buildTextField(_guardianPhoneController,
                                  'Teléfono Tutor', Icons.phone_outlined,
                                  keyboardType: TextInputType.phone),
                              const SizedBox(height: 12),
                              _buildTextField(
                                  _studentPhoneController,
                                  'Teléfono Alumno (Opcional)',
                                  Icons.phone_android_outlined,
                                  keyboardType: TextInputType.phone),
                              const SizedBox(height: 12),
                              _buildTextField(_placeOfResidenceController,
                                  'Lugar de Residencia', Icons.home_outlined),
                              const SizedBox(height: 12),
                              _buildTextField(
                                  _institutionalEmailController,
                                  'Correo Institucional',
                                  Icons.alternate_email_outlined,
                                  keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 40),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _saveStudent,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      widget.student == null
                                          ? 'Registrar Alumno'
                                          : 'Guardar Cambios',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(title,
        style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1));
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool enabled = true, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: !enabled,
      ),
      validator: (val) => val!.isEmpty && label != 'Teléfono Alumno (Opcional)'
          ? 'Campo requerido'
          : null,
    );
  }

  Widget _buildGenderDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: const InputDecoration(
          labelText: 'Género', prefixIcon: Icon(Icons.wc_outlined, size: 20)),
      items: const [
        DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
        DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
      ],
      onChanged: (val) => setState(() => _selectedGender = val),
      validator: (val) => val == null ? 'Selecciona género' : null,
    );
  }

  Widget _buildCycleDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSchoolCycle,
      decoration: const InputDecoration(
          labelText: 'Ciclo Escolar',
          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20)),
      items: _availableSchoolCycles
          .map((cycle) =>
              DropdownMenuItem(value: cycle.id, child: Text(cycle.id)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedSchoolCycle = val;
          _loadGroups(val);
        });
      },
      validator: (val) => val == null ? 'Selecciona ciclo' : null,
    );
  }

  Widget _buildGroupDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGroup,
      decoration: InputDecoration(
        labelText: 'Grupo',
        prefixIcon: const Icon(Icons.groups_outlined, size: 20),
        helperText: _selectedSchoolCycle == null
            ? 'Selecciona un ciclo primero'
            : (_groups.isEmpty ? 'No hay grupos' : null),
      ),
      items: _groups
          .map((group) =>
              DropdownMenuItem(value: group.key, child: Text(group.name)))
          .toList(),
      onChanged: _selectedSchoolCycle == null || _groups.isEmpty
          ? null
          : (val) => setState(() => _selectedGroup = val),
      validator: (val) => val == null ? 'Selecciona grupo' : null,
    );
  }
}
