import 'dart:io';
import 'package:asystem_cobacam/data/access_codes.dart';
import 'package:asystem_cobacam/data/campus_list.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();
  final _accessCodeController = TextEditingController();

  String? _selectedRole;
  String? _selectedCampus;
  XFile? _profileImage;

  final List<String> _roles = [
    'Alumno',
    'Academica',
    'Prefecta',
    'Personal Administrativo por Plantel',
    'Personal Administrativo General',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _dobController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = image;
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: Theme.of(context).cardTheme.color,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      UiHelpers.showSnackBar(
          context, 'Por favor, completa los campos requeridos.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final String? role = _selectedRole;
    final String code = _accessCodeController.text;

    if (role == null) {
      UiHelpers.showSnackBar(context, 'Por favor, selecciona un rol.',
          isError: true);
      setState(() => _isLoading = false);
      return;
    }

    if (role == 'Personal Administrativo General') {
      if (code != generalAdminCode) {
        UiHelpers.showSnackBar(
            context, 'Código de Administrador General incorrecto.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }
    } else {
      final String? campus = _selectedCampus;
      if (campus == null) {
        UiHelpers.showSnackBar(context, 'Por favor, selecciona un plantel.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final String? correctCode = campusRoleCodes[campus]?[role];
      if (correctCode == null || code != correctCode) {
        UiHelpers.showSnackBar(
            context, 'Código de Acceso incorrecto para este plantel.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      User? user = userCredential.user;
      if (user != null) {
        String? profileImageUrl;
        if (_profileImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pictures/${user.uid}');
          final uploadTask =
              await storageRef.putFile(File(_profileImage!.path));

          if (!mounted) return;
          profileImageUrl = await uploadTask.ref.getDownloadURL();
          if (!mounted) return;
        }

        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('users/${user.uid}');
        await userRef.set({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'campus': _selectedRole == 'Personal Administrativo General'
              ? 'General'
              : _selectedCampus,
          'dateOfBirth': _dobController.text,
          'location': _locationController.text.trim(),
          'profileImageUrl': profileImageUrl,
        });

        if (mounted) {
          UiHelpers.showSnackBar(context, '¡Cuenta creada exitosamente!');
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ocurrió un error.';
      if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya está en uso.';
      }
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Error inesperado: ${e.toString()}',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGeneralAdmin = _selectedRole == 'Personal Administrativo General';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear Cuenta'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color:
                          isDark ? theme.cardTheme.color : Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
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
                                              color: theme.colorScheme.primary,
                                              width: 2),
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor:
                                              theme.colorScheme.surface,
                                          backgroundImage: _profileImage != null
                                              ? FileImage(
                                                  File(_profileImage!.path))
                                              : null,
                                          child: _profileImage == null
                                              ? Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  size: 40,
                                                  color: theme
                                                      .colorScheme.primary
                                                      .withValues(alpha: 0.5))
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color:
                                                  theme.scaffoldBackgroundColor,
                                              width: 2),
                                        ),
                                        child: const Icon(Icons.edit,
                                            color: Colors.white, size: 16),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              _buildSectionTitle(theme, 'Información Personal'),
                              const SizedBox(height: 16),
                              _buildTextFormField(_nameController,
                                  'Nombre Completo', Icons.person_outline),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _dobController,
                                decoration: _buildInputDecoration(
                                    'Fecha de Nacimiento',
                                    Icons.calendar_today_outlined),
                                readOnly: true,
                                onTap: _selectDate,
                                validator: (val) =>
                                    val!.isEmpty ? 'Campo requerido' : null,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(_locationController,
                                  'Lugar Actual', Icons.location_city_outlined),

                              const SizedBox(height: 32),
                              _buildSectionTitle(theme, 'Credenciales'),
                              const SizedBox(height: 16),
                              _buildTextFormField(_emailController,
                                  'Correo Electrónico', Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 16),
                              _buildTextFormField(_passwordController,
                                  'Contraseña', Icons.lock_outline,
                                  isPassword: true),

                              const SizedBox(height: 32),
                              _buildSectionTitle(theme, 'Rol Institucional'),
                              const SizedBox(height: 16),
                              _buildDropdown(_roles, 'Selecciona un Rol',
                                  Icons.work_outline, (val) {
                                setState(() {
                                  _selectedRole = val;
                                  _selectedCampus = null;
                                });
                              }),

                              // Campus Dropdown Animation
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: (_selectedRole != null &&
                                        !isGeneralAdmin)
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: _buildDropdown(
                                            cobacamCampuses,
                                            'Selecciona un Plantel',
                                            Icons.school_outlined,
                                            (val) => setState(
                                                () => _selectedCampus = val)),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Access Code Animation
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: (isGeneralAdmin ||
                                        (_selectedRole != null &&
                                            _selectedCampus != null))
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: _buildTextFormField(
                                            _accessCodeController,
                                            'Código de Acceso',
                                            Icons.vpn_key_outlined),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 40),

                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _handleSignUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          shadowColor: theme.colorScheme.primary
                                              .withValues(alpha: 0.4),
                                        ),
                                        child: const Text('Registrar Cuenta',
                                            style: TextStyle(fontSize: 18)),
                                      ),
                                    ),
                              const SizedBox(height: 20),
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

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextFormField(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: _buildInputDecoration(label, icon, isPassword: isPassword),
      obscureText: isPassword ? _isPasswordObscured : false,
      keyboardType: keyboardType,
      validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    );
  }

  Widget _buildDropdown(List<String> items, String label, IconData icon,
      void Function(String?) onChanged) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      items: items
          .map((String value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      decoration: _buildInputDecoration(label, icon),
      dropdownColor: theme.cardTheme.color,
      validator: (val) => val == null ? 'Campo requerido' : null,
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {bool isPassword = false}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon:
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _isPasswordObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordObscured = !_isPasswordObscured;
                });
              },
            )
          : null,
    );
  }
}
