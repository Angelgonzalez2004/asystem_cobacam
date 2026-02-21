// ignore_for_file: unnecessary_nullable_for_final_variable_declarations
import 'dart:io';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:provider/provider.dart';

class GeneralUserProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  const GeneralUserProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<GeneralUserProfileScreen> createState() => _GeneralUserProfileScreenState();
}

class _GeneralUserProfileScreenState extends State<GeneralUserProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref('users');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // Data Containers
  Map<String, dynamic> _userData = {};
  int? _profileImageLastUpdated;
  XFile? _newProfileImage;

  // --- Student Specific Data ---
  Student? _studentProfile;
  String? _selectedStudentSchoolCycle;
  List<SchoolCycle> _availableStudentSchoolCycles = [];
  bool _canEditStudentProfile = false; // From Student record
  bool _hasEditedProfileOnce = false; // From User record
  bool _medicalAlert = false; // From Student record

  // Controllers for general user profile fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _matriculaController = TextEditingController(); // This is the studentId from /users/uid

  // Controllers for student specific fields
  final _guardianFullNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  String? _selectedGender; // For dropdown
  final _ageController = TextEditingController();
  final _groupController = TextEditingController();
  final _placeOfResidenceStudentController = TextEditingController(); // Student specific residence
  final _allergiesController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  final _generalHealthStatusController = TextEditingController();
  final _nssController = TextEditingController();

  late final AppSettingsService _appSettingsService;
  late final ConnectivityService _connectivityService;
  late final HiveService _hiveService;

  // --- Smart Selectors Predefined Lists ---
  final List<String> _commonAllergies = [
    'Ninguna', 'Penicilina', 'Sulfa', 'Polvo/Ácaros', 'Polen', 'Aines (Aspirina)', 'Látex', 'Picaduras de insectos',
    'Mariscos', 'Nueces/Cacahuates', 'Lácteos', 'Huevo', 'Pelo de animal', 'Moho', 'Colorantes', 'Otro (especificar)'
  ];
  final List<String> _commonConditions = [
    'Ninguna', 'Asma', 'Diabetes Tipo 1', 'Diabetes Tipo 2', 'Hipertensión', 'Epilepsia/Convulsiones', 'Migraña Crónica',
    'Gastritis', 'Anemia', 'Artritis', 'Problemas Cardíacos', 'Problemas Renales', 'Hipotiroidismo', 'TDAH',
    'Ansiedad/Depresión', 'Otro (especificar)'
  ];
  final List<String> _commonHealthStatus = [
    'Excelente', 'Bueno', 'Regular', 'Malo', 'En tratamiento médico', 'Convaleciente', 'Requiere observación', 'Estable',
    'Delicado', 'Con fatiga crónica', 'Sobrepeso', 'Bajo peso', 'Saludable con alergias', 'Saludable con condiciones controladas',
    'Desconocido', 'Otro (especificar)'
  ];

  final List<String> _ageOptions =
      List.generate(68, (index) => (index + 13).toString()); // 13 to 80


  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);

    _nameController.text = ''; // Initialize to empty
    _phoneController.text = '';
    _locationController.text = '';
    _matriculaController.text = '';

    _guardianFullNameController.text = '';
    _guardianPhoneController.text = '';
    _studentPhoneController.text = '';
    _selectedGender = null;
    _ageController.text = '';
    _groupController.text = '';
    _placeOfResidenceStudentController.text = '';
    _allergiesController.text = '';
    _healthConditionsController.text = '';
    _generalHealthStatusController.text = '';
    _nssController.text = '';
    
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _matriculaController.dispose();

    _guardianFullNameController.dispose();
    _guardianPhoneController.dispose();
    _studentPhoneController.dispose();
    _ageController.dispose();
    _groupController.dispose();
    _placeOfResidenceStudentController.dispose();
    _allergiesController.dispose();
    _healthConditionsController.dispose();
    _generalHealthStatusController.dispose();
    _nssController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _userRef.child(_currentUser.uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _userData = data;
          _nameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _locationController.text = data['location'] ?? '';
          _matriculaController.text = data['studentId'] ?? '';
          _profileImageLastUpdated = data['profileImageLastUpdated'] as int?;
          _hasEditedProfileOnce = data['hasEditedProfileOnce'] ?? false;
        });

        // If the user is a student, fetch their specific student profile
        if (_userData['role'] == 'Alumno') {
          final studentId = _userData['studentId'] as String?;
          final campus = _userData['campus'] as String?;

          if (studentId != null && campus != null && studentId.isNotEmpty && campus.isNotEmpty) {
            final allCycles = await _appSettingsService.getAllSchoolCycles();
            if (mounted) {
              setState(() {
                _availableStudentSchoolCycles = allCycles;
                // Determine the currently active cycle ID using the service
                final currentActiveCycleId = _appSettingsService.getActiveSchoolCycleIdFromCache();
                
                // Set _selectedStudentSchoolCycle to the current active cycle if available,
                // otherwise to the first available cycle, or null if no cycles
                _selectedStudentSchoolCycle = allCycles.firstWhere(
                  (cycle) => cycle.id == currentActiveCycleId,
                  orElse: () => allCycles.isNotEmpty ? allCycles.first : SchoolCycle(id: '', type: '', startDate: DateTime.now(), endDate: DateTime.now())
                ).id;

                if (_selectedStudentSchoolCycle!.isEmpty && allCycles.isNotEmpty) {
                  _selectedStudentSchoolCycle = allCycles.first.id;
                }
              });
            }

            if (_selectedStudentSchoolCycle != null && _selectedStudentSchoolCycle!.isNotEmpty) {
              await _fetchStudentDataForSelectedCycle(_selectedStudentSchoolCycle!);
            }
          } else {
            debugPrint('Advertencia: Datos de Alumno incompletos para vincular perfil.');
          }
        }

        if (mounted) setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint('No user data found in Firebase for UID: ${_currentUser.uid}');
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentDataForSelectedCycle(String cycleId) async {
    if (_currentUser == null || _userData['role'] != 'Alumno') return;

    final studentId = _userData['studentId'] as String?;
    final campus = _userData['campus'] as String?;

    if (studentId == null || campus == null || studentId.isEmpty || campus.isEmpty) {
      debugPrint('Error: studentId o campus no disponibles para _fetchStudentDataForSelectedCycle.');
      if (mounted) {
        UiHelpers.showSnackBar(context, 'No se pudo cargar el perfil de alumno: datos incompletos.', isError: true);
      }
      return;
    }

    try {
      setState(() => _isLoading = true);
      final studentSnapshot = await FirebaseDatabase.instance
          .ref('planteles/$campus/students/$cycleId/$studentId')
          .get();

      if (studentSnapshot.exists) {
        final studentDataMap = Map<String, dynamic>.from(studentSnapshot.value as Map);
        final student = Student.fromMap(studentDataMap); // Assuming Student.fromMap can handle it
        if (mounted) {
          setState(() {
            _studentProfile = student;
            // Populate student-specific controllers
            _guardianFullNameController.text = student.guardianFullName;
            _guardianPhoneController.text = student.guardianPhone;
            _studentPhoneController.text = student.studentPhone ?? '';
            _selectedGender = student.gender;
            _ageController.text = student.age.toString();
            _groupController.text = student.group;
            _placeOfResidenceStudentController.text = student.placeOfResidence;
            
            // Sync general fields with student data for consistency
            _nameController.text = student.fullName;
            if (student.studentPhone != null && student.studentPhone!.isNotEmpty) {
              _phoneController.text = student.studentPhone!;
            }
            _locationController.text = student.placeOfResidence;

            _allergiesController.text = student.allergies ?? 'Ninguna';
            _healthConditionsController.text = student.healthConditions ?? 'Ninguna';
            _generalHealthStatusController.text = student.generalHealthStatus ?? 'Sano';
            _nssController.text = student.nss ?? '';
            _medicalAlert = student.medicalAlert;
            _canEditStudentProfile = student.canEditProfile; // Set editing permission

            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _studentProfile = null;
            _isLoading = false;
            _canEditStudentProfile = false; // No student record, no editing
          });
          UiHelpers.showSnackBar(context, 'No se encontró registro de alumno para el ciclo seleccionado.', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error fetching student data for cycle $cycleId: $e');
      if (mounted) {
        setState(() {
          _studentProfile = null;
          _isLoading = false;
          _canEditStudentProfile = false;
        });
        UiHelpers.showSnackBar(context, 'Error al cargar datos del alumno: $e', isError: true);
      }
    }
  }

  bool _shouldRemoveImage = false; // NEW state to track removal

  Future<void> _handleChangeProfilePictureRequest() async {
    final lastUpdate = _profileImageLastUpdated;
    final changesCount = _userData['profileImageChangesCount'] ?? 0;
    final now = DateTime.now();

    bool isNewMonth = true;
    if (lastUpdate != null) {
      final lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      isNewMonth = now.year != lastUpdateDate.year || now.month != lastUpdateDate.month;
    }

    int currentMonthChanges = isNewMonth ? 0 : changesCount;

    // Show options: Change or Remove
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Seleccionar nueva foto'),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              if ((_userData['profileImageUrl'] != null && _userData['profileImageUrl'].isNotEmpty) || _newProfileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Eliminar foto actual', style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        );
      },
    );

    if (action == 'remove') {
      setState(() {
        _newProfileImage = null;
        _shouldRemoveImage = true;
      });
      UiHelpers.showSnackBar(context, 'Foto marcada para eliminar. Guarda cambios para aplicar.');
      return;
    }

    if (action == 'change') {
      if (_userData['role'] == 'Alumno' && currentMonthChanges >= 3) {
        await UiHelpers.showAlertDialog(
          context,
          title: 'Límite Alcanzado',
          content: 'Has agotado tus 3 cambios de foto de perfil permitidos para este mes. Podrás realizar cambios nuevamente el próximo mes.',
        );
        return;
      }

      String warningMsg = 'Estás a punto de cambiar tu foto de perfil.\n\n';
      warningMsg += '⚠️ IMPORTANTE: Esta foto será la que aparezca en tu CREDENCIAL OFICIAL.\n\n';
      if (_userData['role'] == 'Alumno') {
        warningMsg += '• Límite mensual de cambios: 3.\n';
        warningMsg += '• Cambios realizados este mes: $currentMonthChanges de 3.\n\n';
      }
      warningMsg += '¿Deseas seleccionar una nueva imagen para tu perfil y credencial?';

      final bool? shouldProceed = await UiHelpers.showConfirmationDialog(
        context,
        title: 'Confirmar Foto de Credencial',
        content: warningMsg,
        confirmText: 'Seleccionar Foto',
        cancelText: 'Cancelar',
      );

      if (shouldProceed == true) {
        _pickImage();
        setState(() => _shouldRemoveImage = false); // Cancel removal if picking new
      }
    }
  }


  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newProfileImage = image;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    // Show confirmation for students if they are editing their institutional profile
    if (_userData['role'] == 'Alumno' && _studentProfile != null && _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce) {
      final bool? confirmed = await UiHelpers.showConfirmationDialog(
        context,
        title: 'Confirmar Cambios',
        content: '¿Estás seguro de que tus datos son correctos? Una vez guardados, tu perfil se bloqueará para edición y solo podrás visualizarlo. Para futuros cambios, deberás solicitar autorización a la prefectura.',
        confirmText: 'Sí, Guardar',
        cancelText: 'Revisar',
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Prepare base data
      final Map<String, dynamic> updateData = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
      };

      // 2. Handle student-specific updates if role is Alumno and editing is allowed
      if (_userData['role'] == 'Alumno' && _studentProfile != null && _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce) {
        final studentUpdates = {
          'fullName': _nameController.text.trim(), // Synchronize fullName
          'guardianFullName': _guardianFullNameController.text.trim(),
          'guardianPhone': _guardianPhoneController.text.trim(),
          'studentPhone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null, // Sync studentPhone with general phone
          'gender': _selectedGender,
          'age': int.tryParse(_ageController.text) ?? _studentProfile!.age,
          'placeOfResidence': _locationController.text.trim(), // Sync placeOfResidence with general location
          'allergies': _allergiesController.text.trim().isNotEmpty ? _allergiesController.text.trim() : null,
          'healthConditions': _healthConditionsController.text.trim().isNotEmpty ? _healthConditionsController.text.trim() : null,
          'generalHealthStatus': _generalHealthStatusController.text.trim().isNotEmpty ? _generalHealthStatusController.text.trim() : 'Sano',
          'nss': _nssController.text.trim().isNotEmpty ? _nssController.text.trim() : null,
          'medicalAlert': _medicalAlert,
          'canEditProfile': false, // Reset permission after save
        };

        final studentRef = FirebaseDatabase.instance
            .ref('planteles/${_userData['campus']}/students/$_selectedStudentSchoolCycle/${_studentProfile!.id}');
        await studentRef.update(studentUpdates);

        // Also set hasEditedProfileOnce to true in the user's profile
        updateData['hasEditedProfileOnce'] = true;
      }


      // 3. Upload new image and add its data if selected, or handle removal
      if (_newProfileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${_currentUser.uid}');

        if (kIsWeb) {
          final bytes = await _newProfileImage!.readAsBytes();
          await storageRef.putData(
              bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await storageRef.putFile(File(_newProfileImage!.path));
        }
        final imageUrl = await storageRef.getDownloadURL();
        final newTimestamp = DateTime.now().millisecondsSinceEpoch;

        updateData['profileImageUrl'] = imageUrl;
        updateData['profileImageLastUpdated'] = newTimestamp;

        // Increment or reset the monthly changes count for students
        if (_userData['role'] == 'Alumno') {
          final lastUpdate = _profileImageLastUpdated;
          final changesCount = _userData['profileImageChangesCount'] ?? 0;
          final now = DateTime.now();

          bool isNewMonth = true;
          if (lastUpdate != null) {
            final lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
            isNewMonth = now.year != lastUpdateDate.year || now.month != lastUpdateDate.month;
          }

          updateData['profileImageChangesCount'] = isNewMonth ? 1 : (changesCount + 1);

          // IMPORTANT: Update the Student record with the new photo for the credential
          if (_studentProfile != null && _selectedStudentSchoolCycle != null) {
             final studentRef = FirebaseDatabase.instance
                .ref('planteles/${_userData['campus']}/students/$_selectedStudentSchoolCycle/${_studentProfile!.id}');
             await studentRef.update({'profileImageUrl': imageUrl});
          }
        }
      } else if (_shouldRemoveImage) {
        // Handle deletion
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${_currentUser.uid}');
        
        try {
          await storageRef.delete();
        } catch (e) {
          debugPrint('Error deleting image from storage: $e');
        }

        updateData['profileImageUrl'] = null; // Mark as null in DB
        
        // Also remove from student record for credential
        if (_studentProfile != null && _selectedStudentSchoolCycle != null) {
             final studentRef = FirebaseDatabase.instance
                .ref('planteles/${_userData['campus']}/students/$_selectedStudentSchoolCycle/${_studentProfile!.id}');
             await studentRef.update({'profileImageUrl': null});
        }
        _shouldRemoveImage = false; // Reset state
      }

      // 4. Update Database
      await _userRef.child(_currentUser.uid).update(updateData);

      // 5. Update Local State
      setState(() {
        _userData.addAll(updateData);
        if (updateData.containsKey('profileImageLastUpdated')) {
          _profileImageLastUpdated = updateData['profileImageLastUpdated'];
        }

        _isEditing = false;
        _newProfileImage = null;
      });

      if (mounted) {
        UiHelpers.showSnackBar(context, '¡Perfil actualizado con éxito!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al actualizar: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
          body: Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary)));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header Expansible
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            elevation: 0,
            automaticallyImplyLeading: !widget.isEmbedded,
            leading: widget.isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Editar Perfil',
                )
              else
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _newProfileImage = null;
                      // Reset fields
                      _nameController.text = _userData['fullName'] ?? '';
                      _phoneController.text = _userData['phone'] ?? '';
                      _locationController.text = _userData['location'] ?? '';

                    });
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo decorativo
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                    ),
                  ),
                  // Imagen y Nombre
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _getProfileImage(),
                                child: _getProfileImage() == null
                                    ? Icon(Icons.person,
                                        size: 60, color: Colors.grey[400])
                                    : null,
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _handleChangeProfilePictureRequest,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData['fullName'] ?? 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _userData['role'] ?? 'Rol Desconocido',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido del Formulario
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform:
                  Matrix4.translationValues(0, -20, 0), // Solape negativo
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(theme, 'Información Personal'),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Nombre Completo',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    enabled: _isEditing && (_userData['role'] != 'Alumno' || (_canEditStudentProfile && !_hasEditedProfileOnce)),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Teléfono de Contacto',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    enabled: _isEditing && (_userData['role'] != 'Alumno' || (_canEditStudentProfile && !_hasEditedProfileOnce)),
                    inputType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Lugar de Residencia',
                    controller: _locationController,
                    icon: Icons.location_on_outlined,
                    enabled: _isEditing && (_userData['role'] != 'Alumno' || (_canEditStudentProfile && !_hasEditedProfileOnce)),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'Datos Institucionales'),
                  const SizedBox(height: 16),

                  // Read-only fields
                  _buildReadOnlyField(
                    label: 'Correo Institucional',
                    value: _userData['email'] ?? '',
                    icon: Icons.email_outlined,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          label: 'Rol',
                          value: _userData['role'] ?? '',
                          icon: Icons.badge_outlined,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReadOnlyField(
                          label: 'Plantel',
                          value: _userData['campus'] ?? 'N/A',
                          icon: Icons.school_outlined,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Student-specific fields ---
                  if (_userData['role'] == 'Alumno') ...[
                    // School Cycle Selector for Students
                    _buildSectionHeader(theme, 'CICLO ESCOLAR DEL ALUMNO'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedStudentSchoolCycle,
                      decoration: InputDecoration(
                        labelText: 'Ciclo Escolar',
                        helperText: 'Seleccione el ciclo escolar deseado para consultar sus datos.', // NEW HELPER TEXT
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: _availableStudentSchoolCycles
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.id)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStudentSchoolCycle = val;
                          });
                          _fetchStudentDataForSelectedCycle(val); // Reload student data for selected cycle
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    if (_studentProfile != null) ...[
                      // Student Personal Info
                      _buildSectionHeader(theme, 'DATOS DEL ALUMNO', Icons.person_pin_rounded),
                      const SizedBox(height: 16),
                      _buildReadOnlyField(
                        label: 'Matrícula',
                        value: _studentProfile!.studentId,
                        icon: Icons.badge_outlined,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyField(
                        label: 'Grupo',
                        value: _studentProfile!.group,
                        icon: Icons.groups_outlined,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      // Age Selector
                      DropdownButtonFormField<String>(
                        value: _ageOptions.contains(_ageController.text) ? _ageController.text : null,
                        items: _ageOptions
                            .map((age) => DropdownMenuItem(value: age, child: Text(age)))
                            .toList(),
                        onChanged: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce
                            ? (val) {
                                if (val != null) {
                                  setState(() {
                                    _ageController.text = val;
                                  });
                                }
                              }
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Edad',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Gender Selector
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        items: const [
                          DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                          DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                        ],
                        onChanged: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce
                            ? (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedGender = val;
                                  });
                                }
                              }
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Género',
                          prefixIcon: const Icon(Icons.wc_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Guardian Info
                      _buildSectionHeader(theme, 'DATOS DEL TUTOR', Icons.family_restroom_outlined),
                      const SizedBox(height: 16),
                      _buildProfileField(
                        label: 'Nombre Completo (Tutor)',
                        controller: _guardianFullNameController,
                        icon: Icons.person_outline,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileField(
                        label: 'Teléfono Tutor',
                        controller: _guardianPhoneController,
                        icon: Icons.phone_outlined,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                        inputType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Medical Info
                      _buildSectionHeader(theme, 'INFORMACIÓN MÉDICA (OPCIONAL)', Icons.medical_services_outlined),
                      const SizedBox(height: 16),
                      _buildProfileField(
                        label: 'NSS (Número de Seguro Social)',
                        controller: _nssController,
                        icon: Icons.health_and_safety_outlined,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                      ),
                      const SizedBox(height: 16),
                      _buildSmartSelector(
                        label: 'Alergias',
                        icon: Icons.warning_amber_rounded,
                        options: _commonAllergies,
                        controller: _allergiesController,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                        initialValue: _allergiesController.text,
                      ),
                      const SizedBox(height: 16),
                      _buildSmartSelector(
                        label: 'Condiciones de Salud',
                        icon: Icons.healing_outlined,
                        options: _commonConditions,
                        controller: _healthConditionsController,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                        initialValue: _healthConditionsController.text,
                      ),
                      const SizedBox(height: 16),
                      _buildSmartSelector(
                        label: 'Estado General de Salud',
                        icon: Icons.favorite_border_rounded,
                        options: _commonHealthStatus,
                        controller: _generalHealthStatusController,
                        enabled: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce,
                        initialValue: _generalHealthStatusController.text,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _medicalAlert
                              ? Colors.red.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _medicalAlert ? Colors.red : Colors.transparent),
                        ),
                        child: SwitchListTile(
                          title: const Text('Activar Alerta Médica Crítica',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'Mostrará un aviso urgente al pasar lista. Úsalo solo para casos graves (Diabetes, Epilepsia, etc).',
                              style: TextStyle(fontSize: 12)),
                          value: _medicalAlert,
                          activeColor: Colors.red,
                          secondary: Icon(Icons.add_alert_rounded,
                              color: _medicalAlert ? Colors.red : Colors.grey),
                          onChanged: _isEditing && _canEditStudentProfile && !_hasEditedProfileOnce
                              ? (val) => setState(() => _medicalAlert = val)
                              : null,
                        ),
                      ),
                    ]
                  ],

                  const SizedBox(height: 40),

                  if (_isEditing && (_userData['role'] != 'Alumno' || (_canEditStudentProfile && !_hasEditedProfileOnce)))
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('GUARDAR CAMBIOS',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0)),
                      ),
                    ),
                  // Display message if student cannot edit or has used their one-time edit
                  if (_userData['role'] == 'Alumno' && _isEditing && (!_canEditStudentProfile || _hasEditedProfileOnce))
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _hasEditedProfileOnce
                            ? 'Has utilizado tu permiso de edición única para este ciclo escolar.'
                            : 'La prefectura no ha habilitado la edición de tu perfil para este ciclo escolar.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade700),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_shouldRemoveImage) return null;
    if (_newProfileImage != null) {
      if (kIsWeb) {
        return NetworkImage(_newProfileImage!.path);
      }
      return FileImage(File(_newProfileImage!.path));
    }
    if (_userData['profileImageUrl'] != null &&
        _userData['profileImageUrl'].isNotEmpty) {
      return NetworkImage(_userData['profileImageUrl']);
    }
    return null;
  }

  Widget _buildSectionHeader(ThemeData theme, String title, [IconData? icon]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        Divider(
            color: theme.colorScheme.primary.withOpacity(0.2), thickness: 1),
      ],
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = false,
    TextInputType inputType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: enabled
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
            : Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: inputType,
        style: TextStyle(
            color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: Icon(icon,
              color: enabled ? theme.colorScheme.primary : Colors.grey),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'N/A' : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSelector({
    required String label,
    required IconData icon,
    required List<String> options,
    required TextEditingController controller,
    required bool enabled,
    String? initialValue,
  }) {
    // Determine the initial selected value for the dropdown
    String? selectedValue;
    if (initialValue != null && options.contains(initialValue)) {
      selectedValue = initialValue;
    } else if (initialValue != null && initialValue.isNotEmpty) {
      selectedValue = 'Otro (especificar)';
    }

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
          onChanged: enabled
              ? (val) {
                  if (val != null) {
                    if (val != 'Otro (especificar)') {
                      controller.text = val;
                    } else {
                      controller.text = ''; // Clear for user input if "Otro"
                    }
                    setState(() {}); // Rebuild to update TextFormField visibility
                  }
                }
              : null,
          validator: (val) => val == null || val.isEmpty ? 'Requerido' : null, // Assuming these fields are required if enabled
        ),
        if (isCustom)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12),
            child: TextFormField(
              controller: controller,
              autofocus: true,
              enabled: enabled,
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
      ],
    );
  }
}
