import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart';
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
  final Student? student;
  final String campusId;
  final String currentSchoolCycle;

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
  late TextEditingController _nssController;
  late TextEditingController _allergiesController;
  late TextEditingController _healthConditionsController;
  late TextEditingController _generalHealthStatusController;

  String? _selectedGender;
  String? _selectedGroup;
  String? _selectedSchoolCycle;

  // Smart Selectors State
  String? _selectedAllergyOption;
  String? _selectedConditionOption;
  String? _selectedHealthStatusOption;
  String? _selectedAge;

  final List<String> _commonAllergies = [
    'Ninguna',
    'Penicilina',
    'Sulfa',
    'Polvo/Ácaros',
    'Polen',
    'Aines (Aspirina)',
    'Látex',
    'Picaduras de insectos',
    'Mariscos',
    'Nueces/Cacahuates',
    'Lácteos',
    'Huevo',
    'Pelo de animal',
    'Moho',
    'Colorantes',
    'Otro (especificar)'
  ];

  final List<String> _commonConditions = [
    'Ninguna',
    'Asma',
    'Diabetes Tipo 1',
    'Diabetes Tipo 2',
    'Hipertensión',
    'Epilepsia/Convulsiones',
    'Migraña Crónica',
    'Gastritis',
    'Anemia',
    'Artritis',
    'Problemas Cardíacos',
    'Problemas Renales',
    'Hipotiroidismo',
    'TDAH',
    'Ansiedad/Depresión',
    'Otro (especificar)'
  ];

  final List<String> _commonHealthStatus = [
    'Excelente',
    'Bueno',
    'Regular',
    'Malo',
    'En tratamiento médico',
    'Convaleciente',
    'Requiere observación',
    'Estable',
    'Delicado',
    'Con fatiga crónica',
    'Sobrepeso',
    'Bajo peso',
    'Saludable con alergias',
    'Saludable con condiciones controladas',
    'Desconocido',
    'Otro (especificar)'
  ];

  final List<String> _ageOptions =
      List.generate(68, (index) => (index + 13).toString()); // 13 to 80

  List<Group> _groups = [];
  List<SchoolCycle> _availableSchoolCycles = [];
  bool _isLoadingGroups = true;
  bool _isLoadingCycles = true;
  bool _isSaving = false;
  bool _isReadOnly = false;
  bool _medicalAlert = false; // Estado para el Switch

  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;

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
    _nssController = TextEditingController(text: widget.student?.nss ?? '');
    _allergiesController =
        TextEditingController(text: widget.student?.allergies ?? 'Ninguna');
    _healthConditionsController = TextEditingController(
        text: widget.student?.healthConditions ?? 'Ninguna');
    _generalHealthStatusController = TextEditingController(
        text: widget.student?.generalHealthStatus ?? 'Bueno');

    _selectedGender = widget.student?.gender;
    _selectedGroup = widget.student?.group;
    _medicalAlert = widget.student?.medicalAlert ?? false; // Inicializar

    _selectedSchoolCycle =
        widget.student?.schoolCycle ?? widget.currentSchoolCycle;

    // Initialize Smart Selectors Logic
    _initSmartSelection(_allergiesController, _commonAllergies,
        (val) => _selectedAllergyOption = val);
    _initSmartSelection(_healthConditionsController, _commonConditions,
        (val) => _selectedConditionOption = val);
    _initSmartSelection(_generalHealthStatusController, _commonHealthStatus,
        (val) => _selectedHealthStatusOption = val);

    // Initialize Age
    if (_ageController.text.isNotEmpty &&
        _ageOptions.contains(_ageController.text)) {
      _selectedAge = _ageController.text;
    }

    _loadSchoolCycles().then((_) {
      _checkCycleStatus(_selectedSchoolCycle);
      _subscribeToGroups(_selectedSchoolCycle);
    });
  }

  void _initSmartSelection(TextEditingController ctrl, List<String> options,
      Function(String) setSelection) {
    final text = ctrl.text.trim();
    if (options.contains(text)) {
      setSelection(text);
    } else {
      setSelection('Otro (especificar)');
    }
  }

  void _checkCycleStatus(String? cycleId) {
    if (cycleId == null || _availableSchoolCycles.isEmpty) return;
    try {
      final cycle = _availableSchoolCycles.firstWhere((c) => c.id == cycleId);
      final now = DateTime.now();
      if (now.isAfter(cycle.endDate.add(const Duration(days: 1)))) {
        setState(() => _isReadOnly = true);
      } else {
        setState(() => _isReadOnly = false);
      }
    } catch (e) {
      setState(() => _isReadOnly = false);
    }
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

  void _subscribeToGroups(String? schoolCycleId) {
    _groupsSubscription?.cancel();
    if (schoolCycleId == null) {
      if (mounted) setState(() => _isLoadingGroups = false);
      return;
    }
    if (mounted) setState(() => _isLoadingGroups = true);
    // Reset groups temporarily
    if (mounted) setState(() => _groups = []);

    final query = FirebaseDatabase.instance
        .ref('planteles/${widget.campusId}/groups')
        .orderByChild('schoolCycleId')
        .equalTo(schoolCycleId);

    _groupsSubscription = query.onValue.listen((event) {
      final List<Group> fetchedGroups = [];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          fetchedGroups.add(Group.fromSnapshot(child));
        }
      }

      if (mounted) {
        setState(() {
          _groups = fetchedGroups;
          _isLoadingGroups = false;

          if (_selectedGroup != null) {
            bool exists = _groups.any((g) => g.key == _selectedGroup);
            if (!exists && widget.student != null) {
              final matchByName = _groups.firstWhere(
                  (g) => g.name == widget.student!.group,
                  orElse: () => Group(
                      key: '',
                      name: '',
                      semester: 0,
                      studentCount: 0,
                      schoolCycleId: ''));
              if (matchByName.key.isNotEmpty) {
                _selectedGroup = matchByName.key;
              } else {
                _selectedGroup = null;
              }
            } else if (!exists) {
              _selectedGroup = null;
            }
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
          _groups = [];
        });
        debugPrint('Error loading groups stream: $error');
      }
    });
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _fullNameController.dispose();
    _guardianFullNameController.dispose();
    _ageController.dispose();
    _guardianPhoneController.dispose();
    _studentPhoneController.dispose();
    _placeOfResidenceController.dispose();
    _institutionalEmailController.dispose();
    _studentIdController.dispose();
    _nssController.dispose();
    _allergiesController.dispose();
    _healthConditionsController.dispose();
    _generalHealthStatusController.dispose();
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
      final databaseRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campusId}/students/${_selectedSchoolCycle!}');

      final selectedGroupObj = _groups.firstWhere(
          (g) => g.key == _selectedGroup,
          orElse: () => _groups.first);
      final groupName = selectedGroupObj.name;

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
        group: groupName,
        institutionalEmail: _institutionalEmailController.text,
        studentId: _studentIdController.text,
        isActive: widget.student?.isActive ?? true,
        allergies: _allergiesController.text.trim(),
        healthConditions: _healthConditionsController.text.trim(),
        generalHealthStatus: _generalHealthStatusController.text.trim(),
        nss: _nssController.text.trim().isNotEmpty
            ? _nssController.text.trim()
            : null,
        medicalAlert: _medicalAlert, // Guardar preferencia
      );

      await databaseRef
          .child(studentData.studentId)
          .set(studentData.toFirebaseMap());

      if (widget.student != null &&
          widget.student!.id != studentData.studentId) {
        try {
          await databaseRef.child(widget.student!.id).remove();
        } catch (e) {
          debugPrint('Error eliminando registro anterior: $e');
        }
      }

      if (_selectedGroup != null) {
        final groupRef = FirebaseDatabase.instance.ref(
            'planteles/${widget.campusId}/groups/$_selectedGroup/studentCount');
        try {
          await groupRef.runTransaction((mutableData) {
            int currentCount = (mutableData as int?) ?? 0;
            return Transaction.success(currentCount + 1);
          });
        } catch (e) {
          debugPrint('Error actualizando contador de grupo: $e');
        }
      }

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
      body: _isLoadingCycles || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : FadeInUp(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (_isReadOnly)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outline, color: Colors.red),
                                SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        "🔒 Ciclo Histórico Cerrado - Solo Lectura",
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        Card(
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
                                              Icons.badge_outlined)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedAge,
                                          items: _ageOptions
                                              .map((age) => DropdownMenuItem(
                                                  value: age, child: Text(age)))
                                              .toList(),
                                          onChanged: _isReadOnly
                                              ? null
                                              : (val) {
                                                  setState(() {
                                                    _selectedAge = val;
                                                    _ageController.text =
                                                        val ?? '';
                                                  });
                                                },
                                          decoration: InputDecoration(
                                            labelText: 'Edad',
                                            prefixIcon: const Icon(
                                                Icons.calendar_today,
                                                size: 20), // Icono profesional
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 16),
                                          ),
                                          validator: (val) =>
                                              val == null ? 'Requerido' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                      _nssController,
                                      'NSS (Número de Seguro Social)',
                                      Icons.health_and_safety,
                                      keyboardType: TextInputType.number),
                                  const SizedBox(height: 12),
                                  _buildGenderDropdown(theme),
                                  const SizedBox(height: 32),

                                  _buildSectionTitle(
                                      theme, 'Asignación Académica'),
                                  const SizedBox(height: 16),
                                  _buildCycleDropdown(theme),
                                  const SizedBox(height: 12),
                                  _isLoadingGroups
                                      ? const Center(
                                          child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child:
                                                  CircularProgressIndicator()))
                                      : _buildGroupDropdown(theme),

                                  if (_groups.isEmpty &&
                                      !_isLoadingGroups &&
                                      _selectedSchoolCycle != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                          "⚠️ No hay grupos registrados para el ciclo $_selectedSchoolCycle.",
                                          style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 12),
                                          textAlign: TextAlign.center),
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
                                  _buildTextField(
                                      _placeOfResidenceController,
                                      'Lugar de Residencia',
                                      Icons.home_outlined),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                      _institutionalEmailController,
                                      'Correo Institucional',
                                      Icons.alternate_email_outlined,
                                      keyboardType: TextInputType.emailAddress),

                                  const SizedBox(height: 32),
                                  _buildSectionTitle(
                                      theme, 'INFORMACIÓN MÉDICA (OPCIONAL)'),
                                  const SizedBox(height: 16),

                                  // --- SELECTORES INTELIGENTES MÉDICOS ---
                                  _buildSmartSelector(
                                    label: 'Alergias',
                                    icon: Icons.warning_amber_rounded,
                                    options: _commonAllergies,
                                    selectedValue: _selectedAllergyOption,
                                    controller: _allergiesController,
                                    onChanged: (val) => setState(
                                        () => _selectedAllergyOption = val),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSmartSelector(
                                    label: 'Condiciones de Salud',
                                    icon: Icons.health_and_safety_outlined,
                                    options: _commonConditions,
                                    selectedValue: _selectedConditionOption,
                                    controller: _healthConditionsController,
                                    onChanged: (val) => setState(
                                        () => _selectedConditionOption = val),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSmartSelector(
                                    label: 'Estado General de Salud',
                                    icon: Icons.favorite_border_rounded,
                                    options: _commonHealthStatus,
                                    selectedValue: _selectedHealthStatusOption,
                                    controller: _generalHealthStatusController,
                                    onChanged: (val) => setState(() =>
                                        _selectedHealthStatusOption = val),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _medicalAlert
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _medicalAlert
                                              ? Colors.red
                                              : Colors.transparent),
                                    ),
                                    child: SwitchListTile(
                                      title: const Text(
                                          'Activar Alerta Médica Crítica',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: const Text(
                                          'Mostrará un aviso urgente al pasar lista. Úsalo solo para casos graves (Diabetes, Epilepsia, etc).',
                                          style: TextStyle(fontSize: 12)),
                                      value: _medicalAlert,
                                      activeColor: Colors.red,
                                      secondary: Icon(Icons.add_alert_rounded,
                                          color: _medicalAlert
                                              ? Colors.red
                                              : Colors.grey),
                                      onChanged: _isReadOnly
                                          ? null
                                          : (val) => setState(
                                              () => _medicalAlert = val),
                                    ),
                                  ),

                                  const SizedBox(height: 40),
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isReadOnly ? null : _saveStudent,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
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
                      ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (val) {
        // --- CAMPOS OBLIGATORIOS SEGÚN INSTRUCCIÓN ---
        if (label == 'Nombre Completo' || label == 'Matrícula') {
          return val!.isEmpty ? 'Este campo es obligatorio' : null;
        }

        // Otros campos son necesarios pero no bloqueantes si el usuario así lo decide,
        // excepto los que ya tienen sus propios validadores (Dropdowns).
        return null;
      },
    );
  }

  Widget _buildGenderDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: InputDecoration(
          labelText: 'Género',
          prefixIcon: const Icon(Icons.wc_outlined, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
      decoration: InputDecoration(
          labelText: 'Ciclo Escolar de Alta',
          helperText: 'Selecciona el ciclo al que pertenece el alumno',
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: _availableSchoolCycles
          .map((cycle) =>
              DropdownMenuItem(value: cycle.id, child: Text(cycle.id)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedSchoolCycle = val;
            _subscribeToGroups(val);
          });
          _checkCycleStatus(val);
        }
      },
      validator: (val) => val == null ? 'Selecciona ciclo' : null,
    );
  }

  Widget _buildGroupDropdown(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedSchoolCycle),
            value: _groups.any((g) => g.key == _selectedGroup)
                ? _selectedGroup
                : null,
            decoration: InputDecoration(
              labelText: 'Grupo Asignado',
              prefixIcon: const Icon(Icons.groups_outlined, size: 20),
              helperText: _selectedSchoolCycle == null
                  ? 'Primero selecciona un ciclo'
                  : (_groups.isEmpty
                      ? 'No existen grupos en este ciclo'
                      : null),
              helperStyle: _groups.isEmpty
                  ? TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold)
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _groups
                .map((group) =>
                    DropdownMenuItem(value: group.key, child: Text(group.name)))
                .toList(),
            onChanged: _selectedSchoolCycle == null || _groups.isEmpty
                ? null
                : (val) => setState(() => _selectedGroup = val),
            validator: (val) => val == null ? 'Selecciona grupo' : null,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: IconButton.filledTonal(
            onPressed: _isReadOnly
                ? null
                : () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const GroupManagementScreen()));
                    if (_selectedSchoolCycle != null)
                      _subscribeToGroups(_selectedSchoolCycle);
                  },
            icon: const Icon(Icons.add_business_rounded),
            tooltip: 'Crear/Gestionar Grupos',
          ),
        )
      ],
    );
  }

  Widget _buildSmartSelector({
    required String label,
    required IconData icon,
    required List<String> options,
    required String? selectedValue,
    required TextEditingController controller,
    required Function(String?) onChanged,
  }) {
    final bool isCustom = selectedValue == 'Otro (especificar)';

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: options
              .map((opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(opt, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _isReadOnly
              ? null
              : (val) {
                  onChanged(val);
                  if (val != 'Otro (especificar)') {
                    controller.text = val!;
                  } else {
                    controller.text = ''; // Clear for user input
                  }
                },
        ),
        if (isCustom)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12),
            child: FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Especifique $label',
                  prefixIcon: const Icon(Icons.edit_note_rounded,
                      size: 20, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Por favor especifique' : null,
              ),
            ),
          ),
      ],
    );
  }
}
