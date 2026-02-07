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
  final _matriculaController = TextEditingController();

  final FocusNode _accessCodeFocus = FocusNode();
  final FocusNode _matriculaFocus = FocusNode();

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
  void initState() {
    super.initState();
    _accessCodeFocus.addListener(_onAccessCodeFocus);
    _matriculaFocus.addListener(_onMatriculaFocus);
  }

  void _onMatriculaFocus() {
    if (_matriculaFocus.hasFocus) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "¡ADVERTENCIA! Favor de ingresar su matrícula VERDADERA. El sistema detecta intentos de suplantación.",
                  style: TextStyle(fontSize: 13, color: Colors.white),
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Clean previous
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Si usted es el administrador correspondiente favor de escribirla, sino por favor pídasela al personal correspondiente para la creación de esta cuenta.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4), // Un poco más para leer
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
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
                  surface: Theme.of(context).cardColor,
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
        
        final userData = {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'campus': _selectedRole == 'Personal Administrativo General'
              ? 'General'
              : _selectedCampus,
          'dateOfBirth': _dobController.text,
          'location': _locationController.text.trim(),
          'profileImageUrl': profileImageUrl,
        };

        if (_selectedRole == 'Alumno') {
          userData['studentId'] = _matriculaController.text.trim();
        }

        await userRef.set(userData);

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
                              // Cabecera: Foto
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

                              // Formulario Grid
                              _buildFormGrid(isWide, isGeneralAdmin, theme),

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
                                                  BorderRadius.circular(16)),
                                          elevation: 2,
                                        ),
                                        child: const Text('CREAR CUENTA',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0)),
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

  Widget _buildFormGrid(bool isWide, bool isGeneralAdmin, ThemeData theme) {
    List<Widget> children = [
      // Info Personal
      _buildSectionTitle(theme, 'Información Personal', Icons.person_outline),
      _buildStyledField(
          controller: _nameController,
          label: 'Nombre Completo',
          icon: Icons.badge_outlined),

      if (isWide)
        Row(
          children: [
            Expanded(child: _buildDateSelector()),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStyledField(
                    controller: _locationController,
                    label: 'Lugar de Residencia',
                    icon: Icons.location_on_outlined)),
          ],
        )
      else ...[
        _buildDateSelector(),
        const SizedBox(height: 16),
        _buildStyledField(
            controller: _locationController,
            label: 'Lugar de Residencia',
            icon: Icons.location_on_outlined),
      ],

      const SizedBox(height: 24),
      _buildSectionTitle(theme, 'Datos Institucionales', Icons.school_outlined),

      _buildStyledDropdown(
        items: _roles,
        label: 'Rol Institucional',
        icon: Icons.work_outline,
        onChanged: (val) {
          setState(() {
            _selectedRole = val;
            _selectedCampus = null;
          });
        },
      ),

      if (_selectedRole != null && !isGeneralAdmin) ...[
        const SizedBox(height: 16),
        _buildStyledDropdown(
          items: cobacamCampuses,
          label: 'Selecciona tu Plantel',
          icon: Icons.apartment_rounded,
          onChanged: (val) => setState(() => _selectedCampus = val),
        ),
      ],

      if (_selectedRole == 'Alumno') ...[
        const SizedBox(height: 16),
        _buildStyledField(
          controller: _matriculaController,
          label: 'Matrícula',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.text,
          focusNode: _matriculaFocus,
        ),
      ],

      const SizedBox(height: 24),
      _buildSectionTitle(theme, 'Seguridad', Icons.lock_outline),

      _buildStyledField(
        controller: _emailController,
        label: 'Correo Institucional',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),

      if (isWide)
        Row(
          children: [
            Expanded(
                child: _buildStyledField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    icon: Icons.vpn_key_outlined,
                    isPassword: true)),
            if (isGeneralAdmin ||
                (_selectedRole != null && _selectedCampus != null)) ...[
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStyledField(
                      controller: _accessCodeController,
                      label: 'Código de Validación',
                      icon: Icons.security_rounded,
                      focusNode: _accessCodeFocus)),
            ]
          ],
        )
      else ...[
        _buildStyledField(
            controller: _passwordController,
            label: 'Contraseña',
            icon: Icons.vpn_key_outlined,
            isPassword: true),
        if (isGeneralAdmin ||
            (_selectedRole != null && _selectedCampus != null)) ...[
          const SizedBox(height: 16),
          _buildStyledField(
              controller: _accessCodeController,
              label: 'Código de Validación',
              icon: Icons.security_rounded,
              focusNode: _accessCodeFocus),
        ]
      ]
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .expand((element) => [
                element,
                if (element is! SizedBox && element is! Row)
                  const SizedBox(height: 16)
              ])
          .toList(),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
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
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword ? _isPasswordObscured : false,
        keyboardType: keyboardType,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordObscured
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: () => setState(
                      () => _isPasswordObscured = !_isPasswordObscured),
                )
              : null,
        ),
        validator: (val) => val!.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildDateSelector() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dobController.text.isEmpty
                    ? 'Fecha de Nacimiento'
                    : _dobController.text,
                style: TextStyle(
                  color: _dobController.text.isEmpty
                      ? theme.colorScheme.onSurface.withOpacity(0.6)
                      : theme.colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(color: theme.colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        selectedItemBuilder: (BuildContext context) {
          return items.map<Widget>((String item) {
            return Text(
              item,
              style: TextStyle(color: theme.colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            );
          }).toList();
        },
        onChanged: onChanged,
        dropdownColor: theme.cardColor,
        icon: Icon(Icons.arrow_drop_down_circle_outlined,
            color: theme.colorScheme.onSurface.withOpacity(0.5)),
      ),
    );
  }
}
