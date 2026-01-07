import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart'; // Importa la pantalla de gestión de grupos
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
  bool _isReadOnly = false;

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
      _checkCycleStatus(_selectedSchoolCycle); // Check status immediately
      _loadGroups(_selectedSchoolCycle);
    });
  }

  void _checkCycleStatus(String? cycleId) {
    if (cycleId == null || _availableSchoolCycles.isEmpty) return;
    
    try {
      final cycle = _availableSchoolCycles.firstWhere((c) => c.id == cycleId);
      final now = DateTime.now();
      // Si la fecha de fin ya pasó, es histórico/cerrado.
      // Agregamos un margen de 1 día para seguridad.
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

  Future<void> _loadGroups([String? schoolCycleId]) async {
    if (schoolCycleId == null) {
      if (mounted) setState(() => _isLoadingGroups = false);
      return;
    }
    
    if (mounted) {
        setState(() {
            _isLoadingGroups = true;
            _groups = [];
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
            
            // Validar si el grupo seleccionado previamente existe en la nueva lista
            if (_selectedGroup != null) {
               bool exists = _groups.any((g) => g.key == _selectedGroup);
               
               if (!exists && widget.student != null) {
                   // Intento de recuperación por nombre si venimos de editar
                   final matchByName = _groups.firstWhere(
                       (g) => g.name == widget.student!.group, 
                       orElse: () => Group(key: '', name: '', semester: 0, studentCount: 0, schoolCycleId: '')
                   );
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
        debugPrint('Error loading groups: $e');
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
      final databaseRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campusId}/students/${_selectedSchoolCycle!}');

      // Obtener el nombre del grupo para guardarlo
      final selectedGroupObj = _groups.firstWhere((g) => g.key == _selectedGroup, orElse: () => _groups.first);
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
      );

      await databaseRef
          .child(studentData.studentId)
          .set(studentData.toFirebaseMap());

      // --- ACTUALIZAR CONTADOR DE ALUMNOS EN EL GRUPO ---
      if (_selectedGroup != null) {
        final groupRef = FirebaseDatabase.instance
            .ref('planteles/${widget.campusId}/groups/$_selectedGroup/studentCount');
        
        try {
          await groupRef.runTransaction((mutableData) {
            // Si no existe, es 0. Si existe, suma 1.
            int currentCount = (mutableData as int?) ?? 0;
            return Transaction.success(currentCount + 1);
          });
        } catch (e) {
          debugPrint('Error actualizando contador de grupo: $e');
          // No detenemos el flujo, es un error secundario
        }
      }
      // --------------------------------------------------

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
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outline, color: Colors.red),
                                SizedBox(width: 12),
                                Expanded(child: Text("🔒 Ciclo Histórico Cerrado - Solo Lectura", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
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
                                  _buildCycleDropdown(theme),
                                  const SizedBox(height: 12),
                                  
                                  _isLoadingGroups 
                                    ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                                    : _buildGroupDropdown(theme),
                                  
                                  if (_groups.isEmpty && !_isLoadingGroups && _selectedSchoolCycle != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        "⚠️ No hay grupos registrados para el ciclo $_selectedSchoolCycle.",
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
                                      onPressed: _isReadOnly ? null : _saveStudent,
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
            value: _groups.any((g) => g.key == _selectedGroup) ? _selectedGroup : null,
            decoration: InputDecoration(
              labelText: 'Grupo Asignado',
              prefixIcon: const Icon(Icons.groups_outlined, size: 20),
              helperText: _selectedSchoolCycle == null
                  ? 'Primero selecciona un ciclo'
                  : (_groups.isEmpty ? 'No existen grupos en este ciclo' : null),
              helperStyle: _groups.isEmpty ? TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold) : null,
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
              ? null // No permitir crear grupos en ciclos cerrados
              : () async {
               await Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (context) => const GroupManagementScreen())
               );
               if (_selectedSchoolCycle != null) _loadGroups(_selectedSchoolCycle);
            }, 
            icon: const Icon(Icons.add_business_rounded),
            tooltip: 'Crear/Gestionar Grupos',
          ),
        )
      ],
    );
  }
}