import 'dart:async'; // For StreamSubscription
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart'; // For AppSettingsService
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // For SchoolCycle
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // For Provider

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Student? _student;
  bool _isLoading = true;
  bool _isEditingEnabled = false; // Controlled by prefect
  String? _userProfileImageUrl; // NEW: To store profile image URL
  String _userEmail = ''; // NEW: To store user email

  StreamSubscription<DatabaseEvent>? _studentDataSubscription;
  StreamSubscription<DatabaseEvent>? _userDataSubscription;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _guardianFullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController();
  final TextEditingController _studentPhoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _placeOfResidenceController = TextEditingController();
  final TextEditingController _schoolCycleController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  final TextEditingController _institutionalEmailController = TextEditingController();
  final TextEditingController _matriculaController = TextEditingController(); // NEWLY DECLARED
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _healthConditionsController = TextEditingController();
  final TextEditingController _generalHealthStatusController = TextEditingController();
  final TextEditingController _nssController = TextEditingController();

  late final AppSettingsService _appSettingsService;
  String _currentSystemSchoolCycle = '';
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedFilterSchoolCycle;
  bool _isCurrentCycleSelected = false;


  @override
  void initState() {
    super.initState();
    _appSettingsService = Provider.of<AppSettingsService>(context, listen: false);
    _initSchoolCycleData();
    _loadStudentData();
  }

  Future<void> _initSchoolCycleData() async {
    final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();
    final allCycles = await _appSettingsService.getAllSchoolCycles();

    if (!mounted) return;
    setState(() {
      _currentSystemSchoolCycle = dynamicSchoolCycle;
      _availableSchoolCycles = allCycles;
      // Initially set selectedFilterSchoolCycle to the system's current cycle
      _selectedFilterSchoolCycle = dynamicSchoolCycle;
    });
  }

  @override
  void dispose() {
    _studentDataSubscription?.cancel();
    _userDataSubscription?.cancel();

    _fullNameController.dispose();
    _guardianFullNameController.dispose();
    _ageController.dispose();
    _guardianPhoneController.dispose();
    _studentPhoneController.dispose();
    _genderController.dispose();
    _placeOfResidenceController.dispose();
    _schoolCycleController.dispose();
    _groupController.dispose();
    _institutionalEmailController.dispose();
    _matriculaController.dispose();
    _allergiesController.dispose();
    _healthConditionsController.dispose();
    _generalHealthStatusController.dispose();
    _nssController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData({String? cycleId}) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Determine which cycle to load data for
    final String targetCycleId = cycleId ?? _selectedFilterSchoolCycle ?? _currentSystemSchoolCycle;

    // Fetch Student specific data (from 'students' node)
    final DatabaseReference studentRef =
        FirebaseDatabase.instance.ref('students/$targetCycleId').child(currentUser.uid);

    // Fetch User general data (from 'users' node)
    final DatabaseReference userGeneralRef =
        FirebaseDatabase.instance.ref('users').child(currentUser.uid);

    // Stop previous listener if any
    _studentDataSubscription?.cancel();

    // Listen to student data changes for the selected cycle
    _studentDataSubscription = studentRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data['id'] = currentUser.uid; // Ensure ID is set from UID
        if (mounted) {
          setState(() {
            _student = Student.fromMap(data);
            _selectedFilterSchoolCycle = targetCycleId; // Ensure dropdown reflects actual loaded data cycle
            _isCurrentCycleSelected = (_selectedFilterSchoolCycle == _currentSystemSchoolCycle);
            
            // CORRECCIÓN AQUÍ: Se eliminó '?? false' porque canEditProfile ya es non-nullable
            _isEditingEnabled = _student!.canEditProfile && _isCurrentCycleSelected;
            
            _fillControllers();
            _isLoading = false;
          });
        }
      } else {
        // If student data not found for the selected cycle, clear current student and disable editing
        if (mounted) {
          setState(() {
            _student = null;
            _isEditingEnabled = false;
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      debugPrint('Error loading student data for cycle $targetCycleId: $error');
      if (mounted) {
        setState(() {
          _student = null;
          _isEditingEnabled = false;
          _isLoading = false;
        });
      }
    });

    // Listen to user general data changes for profile image
    _userDataSubscription?.cancel();
    _userDataSubscription = userGeneralRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _userProfileImageUrl = data['profileImageUrl'];
            _userEmail = currentUser.email ?? '';
          });
        }
      }
    });
  }

  void _fillControllers() {
    if (_student != null) {
      _fullNameController.text = _student!.fullName;
      _guardianFullNameController.text = _student!.guardianFullName;
      _ageController.text = _student!.age.toString();
      _guardianPhoneController.text = _student!.guardianPhone;
      _studentPhoneController.text = _student!.studentPhone ?? '';
      _genderController.text = _student!.gender;
      _placeOfResidenceController.text = _student!.placeOfResidence;
      _schoolCycleController.text = _student!.schoolCycle;
      _groupController.text = _student!.group;
      _institutionalEmailController.text = _student!.institutionalEmail;
      _matriculaController.text = _student!.studentId; // Initialize matricula controller
      _allergiesController.text = _student!.allergies ?? '';
      _healthConditionsController.text = _student!.healthConditions ?? '';
      _generalHealthStatusController.text = _student!.generalHealthStatus ?? '';
      _nssController.text = _student!.nss ?? '';
    }
  }

  Future<void> _updateStudentData() async {
    if (_student == null || !_isEditingEnabled) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Datos'),
          content: const Text(
              '¿Estás seguro de que los datos mostrados son correctos? Una vez guardados, no podrás modificarlos de nuevo sin una nueva autorización de la Prefecta.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No, quiero revisar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sí, estoy seguro'),
            ),
          ],
        );
      },
    );

    if (confirmed == false || confirmed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisión cancelada. Puedes seguir editando.')),
        );
      }
      return;
    }

    final DatabaseReference studentRef =
        FirebaseDatabase.instance.ref('students').child(_student!.id);

    final updatedData = {
      'fullName': _fullNameController.text,
      'guardianFullName': _guardianFullNameController.text,
      'age': int.tryParse(_ageController.text) ?? _student!.age,
      'guardianPhone': _guardianPhoneController.text,
      'studentPhone': _studentPhoneController.text.isEmpty ? null : _studentPhoneController.text,
      'gender': _genderController.text,
      'placeOfResidence': _placeOfResidenceController.text,
      // 'schoolCycle': _schoolCycleController.text, // Not editable by student
      // 'group': _groupController.text, // Not editable by student
      'institutionalEmail': _institutionalEmailController.text,
      'allergies': _allergiesController.text.isEmpty ? null : _allergiesController.text,
      'healthConditions': _healthConditionsController.text.isEmpty ? null : _healthConditionsController.text,
      'generalHealthStatus': _generalHealthStatusController.text.isEmpty ? null : _generalHealthStatusController.text,
      'nss': _nssController.text.isEmpty ? null : _nssController.text,
      // 'isActive': _student!.isActive,
      // 'deactivationReason': _student!.deactivationReason,
      // 'medicalAlert': _student!.medicalAlert,
    };

    if (_isEditingEnabled && _student!.canEditMatricula) {
      updatedData['studentId'] = _matriculaController.text;
    }

    try {
      await studentRef.update(updatedData);
      // Reset permissions after successful save
      await studentRef.update({
        'canEditProfile': false,
        'canEditMatricula': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados correctamente y permisos de edición restablecidos.')),
        );
        setState(() {
          _isEditingEnabled = false; // Disable editing locally
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar datos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil de Alumno'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _student == null
              ? Center(
                  child: Text('No se encontraron datos de alumno.',
                      style: theme.textTheme.bodyMedium))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Warning about modification
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.tertiary),
                        ),
                        child: Text(
                          _isEditingEnabled
                              ? ((_student?.canEditMatricula ?? false)
                                  ? '¡Edición activada! Puedes modificar tus datos del ciclo actual, incluyendo tu matrícula. Ciclo y grupo no son editables.'
                                  : '¡Edición activada! Puedes modificar tus datos del ciclo actual. La matrícula, ciclo y grupo no son editables.')
                              : _isCurrentCycleSelected
                                  ? 'Solo se pueden modificar datos con autorización de la Prefecta. La matrícula, ciclo y grupo no son editables por el alumno.'
                                  : 'Estás visualizando datos de un ciclo escolar pasado o futuro. La edición no está disponible para estos ciclos.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isEditingEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: _isEditingEnabled
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // School Cycle Selection
                      DropdownButtonFormField<String>(
                        value: _selectedFilterSchoolCycle,
                        decoration: const InputDecoration(
                          labelText: 'Ciclo Escolar a Visualizar',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          prefixIcon:
                              Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        onChanged: (val) {
                          if (val != null && val != _selectedFilterSchoolCycle) {
                            setState(() {
                              _selectedFilterSchoolCycle = val;
                              _isLoading = true; // Indicate loading
                            });
                            _loadStudentData(cycleId: val); // Reload student data for the selected cycle
                          }
                        },
                        items: _availableSchoolCycles
                            .map((c) => DropdownMenuItem(
                                value: c.id, child: Text(c.id)))
                            .toList(),
                      ),
                      const SizedBox(height: 20),

                      // Profile Picture Display
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                              backgroundImage: _userProfileImageUrl != null && _userProfileImageUrl!.isNotEmpty
                                  ? NetworkImage(_userProfileImageUrl!)
                                  : null,
                              child: _userProfileImageUrl == null || _userProfileImageUrl!.isEmpty
                                  ? Icon(Icons.person, size: 60, color: theme.colorScheme.primary)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _userEmail,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Warning for profile picture
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.secondary),
                              ),
                              child: Text(
                                '¡Importante! La foto de perfil aquí mostrada es la que aparecerá en tu credencial escolar y se usará para el control de asistencia. Solo puedes modificarla dos veces al mes. Asegúrate de que sea una foto clara y actual.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSectionTitle(context, 'Información Personal'),
                      _buildEditableField(context, 'Matrícula', _matriculaController,
                          editable: _isEditingEnabled && (_student?.canEditMatricula ?? false)),
                      _buildEditableField(context, 'Nombre Completo', _fullNameController,
                          editable: _isEditingEnabled),
                      _buildEditableField(context, 'Edad', _ageController,
                          editable: _isEditingEnabled, keyboardType: TextInputType.number),
                      _buildEditableField(context, 'Género', _genderController,
                          editable: _isEditingEnabled),
                      _buildEditableField(context, 'Lugar de Residencia', _placeOfResidenceController,
                          editable: _isEditingEnabled),
                      _buildInfoField(context, 'Correo Institucional', _student?.institutionalEmail ?? '',
                          editable: false),

                      const SizedBox(height: 20),
                      _buildSectionTitle(context, 'Información de Contacto'),
                      _buildEditableField(context, 'Teléfono del Alumno', _studentPhoneController,
                          editable: _isEditingEnabled, keyboardType: TextInputType.phone),
                      _buildEditableField(context, 'Nombre del Tutor', _guardianFullNameController,
                          editable: _isEditingEnabled),
                      _buildEditableField(context, 'Teléfono del Tutor', _guardianPhoneController,
                          editable: _isEditingEnabled, keyboardType: TextInputType.phone),

                      const SizedBox(height: 20),
                      _buildSectionTitle(context, 'Información Académica'),
                      _buildInfoField(context, 'Ciclo Escolar', _student?.schoolCycle ?? '',
                          editable: false),
                      _buildInfoField(context, 'Grupo', _student?.group ?? '',
                          editable: false),

                      const SizedBox(height: 20),
                      _buildSectionTitle(context, 'Información Médica'),
                      _buildEditableField(context, 'Alergias', _allergiesController,
                          editable: _isEditingEnabled, maxLines: 3),
                      _buildEditableField(context, 'Condiciones de Salud', _healthConditionsController,
                          editable: _isEditingEnabled, maxLines: 3),
                      _buildEditableField(context, 'Estado General de Salud', _generalHealthStatusController,
                          editable: _isEditingEnabled),
                      _buildEditableField(context, 'NSS (Número de Seguro Social)', _nssController,
                          editable: _isEditingEnabled),
                      _buildInfoField(context, 'Alerta Médica Activa', (_student?.medicalAlert ?? false) ? 'Sí' : 'No',
                          editable: false, color: (_student?.medicalAlert ?? false) ? theme.colorScheme.error : null),

                      if (_isEditingEnabled) ...[
                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _updateStudentData,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar Cambios'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildInfoField(BuildContext context, String label, String value,
      {bool editable = false, Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color ?? theme.textTheme.bodyLarge?.color,
              fontWeight: editable ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 20),
        ],
      ),
    );
  }

  Widget _buildEditableField(BuildContext context, String label, TextEditingController controller,
      {bool editable = true, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: !editable,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: editable ? const Icon(Icons.edit_outlined, size: 20) : null,
          border: editable ? const OutlineInputBorder() : InputBorder.none,
          filled: !editable,
          fillColor: !editable ? Theme.of(context).disabledColor.withOpacity(0.1) : null,
          contentPadding: editable ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12) : const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: editable ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).disabledColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}