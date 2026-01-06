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

          if (kIsWeb) {
            final bytes = await _profileImage!.readAsBytes();
            await storageRef.putData(
                bytes, SettableMetadata(contentType: 'image/jpeg'));
          } else {
            await storageRef.putFile(File(_profileImage!.path));
          }

          if (!mounted) return;
          profileImageUrl = await storageRef.getDownloadURL();
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear Nueva Cuenta',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      children: [
                        // Avatar Section
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.cardTheme.color,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundColor: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    backgroundImage: _profileImage != null
                                        ? (kIsWeb
                                            ? NetworkImage(_profileImage!.path)
                                            : FileImage(
                                                File(_profileImage!.path))) as ImageProvider
                                        : null,
                                    child: _profileImage == null
                                        ? Icon(Icons.person_outline_rounded,
                                            size: 40,
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.5))
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                  bottom: 0,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: theme.scaffoldBackgroundColor,
                                          width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 16),
                                  ))
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Foto de Perfil",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Form Card
                        Card(
                          elevation: 0,
                          color: isDark ? theme.cardTheme.color : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.08)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isWide ? 40.0 : 24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Section 1: Personal Info
                                  _buildSectionHeader(theme, "Información Personal", Icons.badge_outlined),
                                  const SizedBox(height: 24),
                                  _buildTextFormField(
                                      _nameController,
                                      'Nombre Completo',
                                      Icons.person_outline_rounded),
                                  const SizedBox(height: 20),
                                  
                                  ResponsiveRow(
                                    isWide: isWide,
                                    gap: 20,
                                    children: [
                                      TextFormField(
                                        controller: _dobController,
                                        decoration: _buildInputDecoration(
                                            'Fecha de Nacimiento',
                                            Icons.calendar_today_rounded),
                                        readOnly: true,
                                        onTap: _selectDate,
                                        validator: (val) => val!.isEmpty
                                            ? 'Campo requerido'
                                            : null,
                                        style: TextStyle(
                                            color:
                                                theme.colorScheme.onSurface),
                                      ),
                                      _buildTextFormField(
                                          _locationController,
                                          'Lugar de Residencia',
                                          Icons.location_city_rounded),
                                    ],
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Divider(height: 1),
                                  ),

                                  // Section 2: Institutional Info
                                  _buildSectionHeader(theme, "Datos Institucionales", Icons.apartment_rounded),
                                  const SizedBox(height: 24),
                                  
                                  ResponsiveRow(
                                    isWide: isWide,
                                    gap: 20,
                                    children: [
                                      _buildDropdown(
                                          _roles,
                                          'Selecciona un Rol',
                                          Icons.work_outline_rounded, (val) {
                                        setState(() {
                                          _selectedRole = val;
                                          _selectedCampus = null;
                                        });
                                      }),
                                      
                                      if (_selectedRole != null && !isGeneralAdmin)
                                        _buildDropdown(
                                            cobacamCampuses,
                                            'Selecciona un Plantel',
                                            Icons.school_outlined,
                                            (val) => setState(
                                                () => _selectedCampus = val))
                                      else
                                         const SizedBox.shrink(), // Placeholder for grid alignment if needed
                                    ],
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Divider(height: 1),
                                  ),

                                  // Section 3: Access & Security
                                  _buildSectionHeader(theme, "Seguridad de Acceso", Icons.lock_person_outlined),
                                  const SizedBox(height: 24),
                                  
                                  _buildTextFormField(
                                      _emailController,
                                      'Correo Institucional',
                                      Icons.alternate_email_rounded,
                                      keyboardType:
                                          TextInputType.emailAddress),
                                  const SizedBox(height: 20),
                                  
                                  ResponsiveRow(
                                    isWide: isWide,
                                    gap: 20,
                                    children: [
                                      _buildTextFormField(
                                          _passwordController,
                                          'Contraseña',
                                          Icons.lock_outline_rounded,
                                          isPassword: true),
                                          
                                      if (isGeneralAdmin ||
                                          (_selectedRole != null &&
                                              _selectedCampus != null))
                                        _buildTextFormField(
                                            _accessCodeController,
                                            'Código de Validación',
                                            Icons.vpn_key_rounded)
                                      else
                                         const SizedBox.shrink(),
                                    ],
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
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14)),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                                'Crear Cuenta Oficial',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            '‹ Cancelar Registro',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
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
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((String item) {
          return Text(
            item,
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
             overflow: TextOverflow.ellipsis
          );
        }).toList();
      },
      onChanged: onChanged,
      decoration: _buildInputDecoration(label, icon),
      dropdownColor: theme.cardTheme.color,
      validator: (val) => val == null ? 'Campo requerido' : null,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {bool isPassword = false}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
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

class ResponsiveRow extends StatelessWidget {
  final bool isWide;
  final List<Widget> children;
  final double gap;

  const ResponsiveRow(
      {super.key,
      required this.isWide,
      required this.children,
      this.gap = 16.0});

  @override
  Widget build(BuildContext context) {
    // Filter out SizedBox.shrink or nulls if any logic put them there
    final visibleChildren = children.where((c) {
        if (c is SizedBox && (c.width == 0.0 || c.height == 0.0)) return false;
        return true;
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    if (!isWide) {
      return Column(
        children: visibleChildren
            .expand((element) => [element, SizedBox(height: gap)])
            .take(visibleChildren.length * 2 - 1)
            .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleChildren
          .expand((element) => [Expanded(child: element), SizedBox(width: gap)])
          .take(visibleChildren.length * 2 - 1)
          .toList(),
    );
  }
}

