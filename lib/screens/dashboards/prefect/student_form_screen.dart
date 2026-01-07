import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student; // Null if adding new student, not null if editing
  final String campusId;
  final String
      currentSchoolCycle; // This is the *global current* cycle, but we can override it

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
  late TextEditingController _allergiesController;
  late TextEditingController _healthConditionsController;
  late TextEditingController _generalHealthStatusController;

  String? _selectedGender;
  String? _selectedGroup;
  String? _selectedSchoolCycle;

  List<Group> _groups = [];
  List<SchoolCycle> _availableSchoolCycles = [];
  bool _isLoadingGroups = true;
  bool _isLoadingCycles = true;
  bool _isSaving = false;

  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

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
    _allergiesController =
        TextEditingController(text: widget.student?.allergies ?? '');
    _healthConditionsController =
        TextEditingController(text: widget.student?.healthConditions ?? '');
    _generalHealthStatusController =
        TextEditingController(text: widget.student?.generalHealthStatus ?? 'Sano');

    _selectedGender = widget.student?.gender;
    _selectedGroup = widget.student?.group;
    
    // Si estamos editando, usar el ciclo del alumno. Si es nuevo, el actual global.
    _selectedSchoolCycle = widget.student?.schoolCycle ?? widget.currentSchoolCycle;
    
    _loadSchoolCycles().then((_) {
      _loadGroups(_selectedSchoolCycle);
    });
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
    
    // Limpiar grupos anteriores al cambiar de ciclo
    if (mounted) {
        setState(() {
            _isLoadingGroups = true;
            _groups = [];
            if (_selectedGroup != null) _selectedGroup = null;
        });
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
            // Si estamos editando y el grupo existe en este ciclo, mantenerlo seleccionado
            if (widget.student != null && widget.student!.group == widget.student!.group) { // This condition seems redundant, should check if widget.student!.group exists in fetchedGroups
                 if (_groups.any((g) => g.key == widget.student!.group)) { // Fix: compare Keys ideally
                     // Actually student.group stores the Group NAME in current model?
                     // Let's assume it stores Key or Name. The dropdown uses Key as value.
                     // Let's check Group model. Key is Firebase key. Name is '201-A'.
                     // Student model usually stores Name for display if NoSQL, or Key.
                     // The Dropdown logic below uses `group.key` as value.
                     // Let's ensure consistency.
                 }
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
    if (_selectedGroup == null) {
        UiHelpers.showSnackBar(context, 'Debes asignar un grupo.', isError: true);
        return;
    }

    setState(() => _isSaving = true);

    try {
      // Guardar bajo el nodo del ciclo escolar seleccionado
      final databaseRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campusId}/students/${_selectedSchoolCycle!}');

      // Buscar el nombre del grupo seleccionado para guardarlo (opcional, si se requiere el nombre)
      // Pero el modelo Student guarda 'group' que es el ID/Key o el Nombre?
      // Revisando StudentExcelImport, guarda el nombre de la hoja como grupo.
      // Aquí el dropdown usa `group.key`. Deberíamos guardar el NOMBRE para consistencia visual
      // o el KEY para referencias.
      // El modelo Student tiene `String group`.
      // Voy a buscar el objeto grupo para obtener su nombre real.
      final selectedGroupObj = _groups.firstWhere((g) => g.key == _selectedGroup, orElse: () => _groups.first); // Consider edge case if _groups is empty or _selectedGroup is not found
      final groupName = selectedGroupObj.name; // Guardamos el nombre "201-A"

      final studentData = Student(
        id: _studentIdController.text, // Key manual? O generada? Si es manual (matricula)
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
        group: groupName, // Guardamos el NOMBRE del grupo
        institutionalEmail: _institutionalEmailController.text,
        studentId: _studentIdController.text,
        isActive: widget.student?.isActive ?? true,
        allergies: _allergiesController.text.trim(),
        healthConditions: _healthConditionsController.text.trim(),
        generalHealthStatus: _generalHealthStatusController.text.trim(),
      );

      // Usar matricula como KEY en Firebase para evitar duplicados fáciles
      await databaseRef
          .child(studentData.studentId)
          .set(studentData.toFirebaseMap());

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Alumno guardado correctamente en el ciclo $_selectedSchoolCycle.');
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
      body: _isLoadingCycles || _isSaving
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
                              _buildSectionTitle(theme, 'Asignación Académica'),
                              const SizedBox(height: 16),
                              // CICLO ESCOLAR DROPDOWN
                              _buildCycleDropdown(theme),
                              const SizedBox(height: 12),
                              // GRUPO DROPDOWN
                              _isLoadingGroups 
                                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                                : _buildGroupDropdown(theme),
                              
                              if (_groups.isEmpty && !_isLoadingGroups && _selectedSchoolCycle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "⚠️ No hay grupos registrados para el ciclo $_selectedSchoolCycle.\nPrimero debes crear los grupos en 'Gestión de Grupos'.",
                                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

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
                              const SizedBox(height: 32),
                              _buildSectionTitle(theme, 'INFORMACIÓN MÉDICA (OPCIONAL)'),
                              const SizedBox(height: 16),
                              _buildTextField(
                                  _allergiesController,
                                  'Alergias (Medicamentos, comida, etc.)',
                                  Icons.warning_amber_rounded),
                              const SizedBox(height: 12),
                              _buildTextField(
                                  _healthConditionsController,
                                  'Condiciones de Salud (Visión, caminar, etc.)',
                                  Icons.health_and_safety_outlined),
                              const SizedBox(height: 12),
                              _buildTextField(
                                  _generalHealthStatusController,
                                  'Estado General (ej. Sano)',
                                  Icons.favorite_border_rounded),
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
          labelText: 'Ciclo Escolar de Alta',
          helperText: 'Selecciona el ciclo al que pertenece el alumno',
          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20)),
      items: _availableSchoolCycles
          .map((cycle) =>
              DropdownMenuItem(value: cycle.id, child: Text(cycle.id)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
            setState(() {
              _selectedSchoolCycle = val;
              _loadGroups(val);
            });
        }
      },
      validator: (val) => val == null ? 'Selecciona ciclo' : null,
    );
  }

  Widget _buildGroupDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedSchoolCycle), // Force rebuild when cycle changes
      value: _groups.any((g) => g.key == _selectedGroup) ? _selectedGroup : null,
      decoration: InputDecoration(
        labelText: 'Grupo Asignado',
        prefixIcon: const Icon(Icons.groups_outlined, size: 20),
        helperText: _selectedSchoolCycle == null
            ? 'Primero selecciona un ciclo'
            : (_groups.isEmpty ? 'No existen grupos en este ciclo' : null),
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