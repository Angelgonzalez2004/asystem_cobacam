import 'dart:io';
import 'package:asystem_cobacam/data/access_codes.dart';
import 'package:asystem_cobacam/data/campus_list.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isAccessCodeObscured = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final _matriculaController = TextEditingController();

  final FocusNode _accessCodeFocus = FocusNode();
  final FocusNode _matriculaFocus = FocusNode();

  String? _selectedRole;
  String? _selectedCampus;
  XFile? _profileImage;

  final List<String> _roles = [
    'Tutor',
    'Alumno',
    'Academica',
    'Prefecta',
    'Personal Administrativo por Plantel',
    'Personal Administrativo General',
  ];

  @override
  void initState() {
    super.initState();
    _accessCodeFocus.addListener(_onAccessCodeFocus);
    _matriculaFocus.addListener(_onMatriculaFocus);
  }

  void _onMatriculaFocus() {
    if (_matriculaFocus.hasFocus) {
      String message = _selectedRole == 'Tutor'
          ? "Ingrese la matrícula del alumno/a que desea vincular a su cuenta."
          : "¡ADVERTENCIA! Favor de ingresar su matrícula VERDADERA. El sistema detecta intentos de suplantación.";
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.orange.shade800.withOpacity(0.9),
          elevation: 6,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _dobController.dispose();
    _accessCodeController.dispose();
    _matriculaController.dispose();
    _accessCodeFocus.dispose();
    _matriculaFocus.dispose();
    super.dispose();
  }

  void _onAccessCodeFocus() {
    if (_accessCodeFocus.hasFocus) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Este código es proporcionado por la administración del plantel para validar su rol.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
          elevation: 6,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _profileImage = image);
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dobController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      UiHelpers.showSnackBar(context, 'Por favor, completa los campos requeridos.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- VALIDATION ---
      final String? role = _selectedRole;
      if (role == null) throw Exception('Por favor, selecciona un rol.');

      if (role == 'Personal Administrativo General') {
        if (_accessCodeController.text != generalAdminCode) {
          throw Exception('Código de Administrador General incorrecto.');
        }
      } else {
        final String? campus = _selectedCampus;
        if (campus == null) throw Exception('Por favor, selecciona un plantel.');
        if (_accessCodeController.text != campusRoleCodes[campus]?[role]) {
          throw Exception('Código de Acceso incorrecto para este plantel y rol.');
        }
      }

      if ((role == 'Alumno' || role == 'Tutor') && _matriculaController.text.trim().isEmpty) {
        throw Exception('La matrícula del alumno es requerida para este rol.');
      }

      // --- USER CREATION ---
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null) throw Exception("No se pudo crear el usuario.");
      if (!mounted) return;

      // --- PROFILE PICTURE UPLOAD ---
      String? profileImageUrl;
      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}');
        if (kIsWeb) {
          await storageRef.putData(await _profileImage!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await storageRef.putFile(File(_profileImage!.path));
        }
        profileImageUrl = await storageRef.getDownloadURL();
      }
      if (!mounted) return;

      // --- USER DATA CREATION ---
      final userData = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': role,
        'campus': role == 'Personal Administrativo General' ? 'General' : _selectedCampus,
        'dateOfBirth': _dobController.text,
        'location': _locationController.text.trim(),
        'profileImageUrl': profileImageUrl,
      };
      if (role == 'Alumno') {
        userData['studentId'] = _matriculaController.text.trim();
      }
      await FirebaseDatabase.instance.ref('users/${user.uid}').set(userData);

      // --- LINKING LOGIC ---
      final studentId = _matriculaController.text.trim();
      final campus = _selectedCampus!;
      
      bool linkSuccessful = false;
      String? successMessage;
      
      // Find student reference to update
      final studentsRef = FirebaseDatabase.instance.ref('planteles/$campus/students');
      final allCyclesSnapshot = await studentsRef.get();

      if (allCyclesSnapshot.exists) {
        for (final cycleSnapshot in allCyclesSnapshot.children) {
          for (final studentSnapshot in cycleSnapshot.children) {
            if (studentSnapshot.value is Map) {
              final studentData = Map<String, dynamic>.from(studentSnapshot.value as Map);
              if (studentData['studentId'] == studentId) {
                final studentRecordRef = studentSnapshot.ref;
                
                if (role == 'Alumno') {
                  await studentRecordRef.update({'userId': user.uid});
                  successMessage = 'Cuenta de alumno vinculada exitosamente.';
                } else if (role == 'Tutor') {
                  List<String> guardianIds = List<String>.from(studentData['guardianUserIds'] ?? []);
                  if (!guardianIds.contains(user.uid)) {
                    guardianIds.add(user.uid);
                    await studentRecordRef.update({'guardianUserIds': guardianIds});
                  }
                  successMessage = 'Cuenta de tutor vinculada exitosamente al alumno ${studentData['fullName']}.';
                }
                linkSuccessful = true;
                break;
              }
            }
          }
          if (linkSuccessful) break;
        }
      }

      if (!linkSuccessful && (role == 'Alumno' || role == 'Tutor')) {
         UiHelpers.showSnackBar(context, 'Advertencia: No se encontró el alumno con matrícula $studentId para vincular la cuenta.', isError: true, duration: const Duration(seconds: 5));
      } else {
        UiHelpers.showSnackBar(context, successMessage ?? '¡Cuenta creada exitosamente!');
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String message = 'Ocurrió un error.';
      if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya está en uso.';
      }
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      UiHelpers.showSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGeneralAdmin = _selectedRole == 'Personal Administrativo General';
    final needsMatricula = _selectedRole == 'Alumno' || _selectedRole == 'Tutor';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Registro de Usuario',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Card(
                      elevation: 0,
                      color: isDark ? theme.cardColor : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: BorderSide(
                            color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isWide ? 40.0 : 24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.primaryColor
                                                .withOpacity(0.2),
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 60,
                                          backgroundColor:
                                              theme.scaffoldBackgroundColor,
                                          backgroundImage: _profileImage != null
                                              ? (kIsWeb
                                                      ? NetworkImage(
                                                          _profileImage!.path)
                                                      : FileImage(File(
                                                          _profileImage!.path)))
                                                  as ImageProvider
                                              : null,
                                          child: _profileImage == null
                                              ? Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  size: 40,
                                                  color: theme.primaryColor
                                                      .withOpacity(0.5))
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 16,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              _buildSectionTitle(theme, 'Información Personal', Icons.person_outline),
                              _buildStyledField(controller: _nameController, label: 'Nombre Completo', icon: Icons.badge_outlined),
                              _buildDateSelector(),
                              _buildStyledField(controller: _locationController, label: 'Lugar de Residencia', icon: Icons.location_on_outlined),
                              
                              const SizedBox(height: 24),
                              _buildSectionTitle(theme, 'Datos Institucionales', Icons.school_outlined),

                              _buildStyledDropdown(
                                items: _roles,
                                label: 'Rol Institucional',
                                icon: Icons.work_outline,
                                onChanged: (val) => setState(() {
                                  _selectedRole = val;
                                  _selectedCampus = null;
                                }),
                              ),

                              if (_selectedRole != null && !isGeneralAdmin)
                                _buildStyledDropdown(
                                  items: cobacamCampuses,
                                  label: 'Selecciona tu Plantel',
                                  icon: Icons.apartment_rounded,
                                  onChanged: (val) => setState(() => _selectedCampus = val),
                                ),
                              
                              if (needsMatricula)
                                _buildStyledField(
                                  controller: _matriculaController,
                                  label: 'Matrícula del Alumno',
                                  icon: Icons.badge_outlined,
                                  keyboardType: TextInputType.text,
                                  focusNode: _matriculaFocus,
                                ),

                              const SizedBox(height: 24),
                              _buildSectionTitle(theme, 'Seguridad', Icons.lock_outline),

                              _buildStyledField(controller: _emailController, label: 'Correo Institucional', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                              _buildStyledField(controller: _passwordController, label: 'Contraseña', icon: Icons.vpn_key_outlined, isPassword: true),
                              
                              if (isGeneralAdmin || (_selectedRole != null && _selectedCampus != null))
                                _buildStyledField(
                                    controller: _accessCodeController,
                                    label: 'Código de Validación',
                                    icon: Icons.security_rounded,
                                    isAccessCode: true,
                                    focusNode: _accessCodeFocus),

                              const SizedBox(height: 40),

                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _handleSignUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 2,
                                        ),
                                        child: const Text('CREAR CUENTA',
                                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isAccessCode = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    bool currentObscuredState = isPassword ? _isPasswordObscured : (isAccessCode ? _isAccessCodeObscured : false);
    VoidCallback? toggleObscuredState = isPassword 
      ? () => setState(() => _isPasswordObscured = !_isPasswordObscured)
      : (isAccessCode ? () => setState(() => _isAccessCodeObscured = !_isAccessCodeObscured) : null);

    return TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: currentObscuredState,
        keyboardType: keyboardType,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          suffixIcon: toggleObscuredState != null
              ? IconButton(
                  icon: Icon(currentObscuredState ? Icons.visibility_off : Icons.visibility, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  onPressed: toggleObscuredState,
                )
              : null,
        ),
        validator: (val) => val!.isEmpty ? 'Requerido' : null,
      );
  }

  Widget _buildDateSelector() {
    return TextFormField(
      controller: _dobController, 
      onTap: _selectDate, 
      readOnly: true, 
      decoration: InputDecoration(
        labelText: 'Fecha de Nacimiento', 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), 
        prefixIcon: const Icon(Icons.calendar_today)
      )
    );
  }

  Widget _buildStyledDropdown({
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), 
        prefixIcon: Icon(icon)
      )
    );
  }
}