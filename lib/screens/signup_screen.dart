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
    // RESTAURACIÓN DE ADVERTENCIAS POR FOCO
    _accessCodeFocus.addListener(_onAccessCodeFocus);
    _matriculaFocus.addListener(_onMatriculaFocus);
  }

  void _onMatriculaFocus() {
    if (_matriculaFocus.hasFocus) {
      String message = _selectedRole == 'Tutor'
          ? "Ingrese la matrícula del alumno/a que desea vincular a su cuenta."
          : "¡ADVERTENCIA! Favor de ingresar su matrícula VERDADERA. El sistema detecta intentos de suplantación.";
      
      _showTopWarning(message, Icons.warning_amber_rounded, Colors.orange.shade900);
    }
  }

  void _onAccessCodeFocus() {
    if (_accessCodeFocus.hasFocus) {
      _showTopWarning(
        "Este código es proporcionado por la administración del plantel para validar su rol.",
        Icons.info_outline,
        const Color(0xFF1E3A8A),
      );
    }
  }

  void _showTopWarning(String message, IconData icon, Color bgColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: bgColor.withOpacity(0.95),
        margin: const EdgeInsets.all(16),
      ),
    );
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
    _accessCodeFocus.removeListener(_onAccessCodeFocus);
    _matriculaFocus.removeListener(_onMatriculaFocus);
    _accessCodeFocus.dispose();
    _matriculaFocus.dispose();
    super.dispose();
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
      UiHelpers.showSnackBar(context, 'Completa los campos requeridos.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String? role = _selectedRole;
      if (role == null) throw Exception('Selecciona un rol.');

      if (role == 'Personal Administrativo General') {
        if (_accessCodeController.text != generalAdminCode) {
          throw Exception('Código de Administrador General incorrecto.');
        }
      } else {
        final String? campus = _selectedCampus;
        if (campus == null) throw Exception('Selecciona un plantel.');
        if (_accessCodeController.text != campusRoleCodes[campus]?[role]) {
          throw Exception('Código de Acceso incorrecto.');
        }
      }

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null) throw Exception("Error al crear usuario.");

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

      UiHelpers.showSnackBar(context, '¡Cuenta creada exitosamente!');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      UiHelpers.showSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: FadeInUp(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Container(
                          padding: EdgeInsets.all(isWide ? 48.0 : 24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 60, offset: const Offset(0, 30)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'REGISTRO DE NUEVO USUARIO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFFACC15), fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Complete el formulario institucional para dar de alta su cuenta en el sistema.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w400),
                                ),
                                const SizedBox(height: 40),

                                Center(child: _buildImagePicker()),
                                const SizedBox(height: 48),

                                _buildSectionTitle('IDENTIDAD PERSONAL', Icons.person_add_alt_1_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildPremiumField(controller: _nameController, label: 'NOMBRE COMPLETO', icon: Icons.badge_rounded),
                                  _buildDateSelector(),
                                ]),
                                _buildPremiumField(controller: _locationController, label: 'MUNICIPIO / LOCALIDAD', icon: Icons.map_rounded),
                                
                                const SizedBox(height: 32),
                                _buildSectionTitle('ADSCRIPCIÓN INSTITUCIONAL', Icons.account_balance_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildDropdown(
                                    items: _roles, 
                                    label: 'CARGO O ROL', 
                                    icon: Icons.assignment_ind_rounded, 
                                    onChanged: (v) => setState(() => _selectedRole = v),
                                    itemIcons: {
                                      'Tutor': Icons.family_restroom_rounded,
                                      'Alumno': Icons.school_rounded,
                                      'Academica': Icons.menu_book_rounded,
                                      'Prefecta': Icons.verified_user_rounded,
                                      'Personal Administrativo por Plantel': Icons.admin_panel_settings_rounded,
                                      'Personal Administrativo General': Icons.account_balance_rounded,
                                    },
                                  ),
                                  if (_selectedRole != null && _selectedRole != 'Personal Administrativo General')
                                    _buildDropdown(
                                      items: cobacamCampuses, 
                                      label: 'PLANTEL / EMSAD', 
                                      icon: Icons.location_city_rounded, 
                                      onChanged: (v) => setState(() => _selectedCampus = v),
                                      itemIcons: { for (var item in cobacamCampuses) item : Icons.business_rounded },
                                    ),
                                ]),
                                
                                if (_selectedRole == 'Alumno' || _selectedRole == 'Tutor')
                                  _buildPremiumField(controller: _matriculaController, label: 'MATRÍCULA DE CONTROL', icon: Icons.pin_rounded, focusNode: _matriculaFocus),

                                const SizedBox(height: 32),
                                _buildSectionTitle('CREDENCIALES DE ACCESO', Icons.security_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildPremiumField(controller: _emailController, label: 'CORREO ELECTRÓNICO', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                                  _buildPremiumField(controller: _passwordController, label: 'CONTRASEÑA DEL SISTEMA', icon: Icons.password_rounded, isPassword: true),
                                ]),
                                
                                if (_selectedRole != null && (_selectedCampus != null || _selectedRole == 'Personal Administrativo General'))
                                  _buildPremiumField(controller: _accessCodeController, label: 'CÓDIGO DE VALIDACIÓN LABORAL', icon: Icons.verified_user_rounded, isAccessCode: true, focusNode: _accessCodeFocus),

                                const SizedBox(height: 56),

                                _isLoading
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                    : ElevatedButton(
                                        onPressed: _handleSignUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF0F172A),
                                          minimumSize: const Size(double.infinity, 65),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          elevation: 10,
                                        ),
                                        child: const Text('PROCESAR REGISTRO INSTITUCIONAL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 15)),
                                      ),

                                const SizedBox(height: 40),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('¿Ya dispone de una cuenta? ', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: const Text('Iniciar Sesión', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFACC15).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFFACC15)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildResponsiveRow(bool isWide, List<Widget> children) {
    if (!isWide) return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList());
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: c))).toList(),
      ),
    );
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isAccessCode = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    String? hint,
  }) {
    bool obscure = isPassword ? _isPasswordObscured : (isAccessCode ? _isAccessCodeObscured : false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
            cursorColor: const Color(0xFF1E3A8A),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A).withOpacity(0.7), size: 18),
              suffixIcon: (isPassword || isAccessCode)
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF1E3A8A).withOpacity(0.5),
                        size: 18,
                      ),
                      onPressed: () => setState(() {
                        if (isPassword) _isPasswordObscured = !_isPasswordObscured;
                        if (isAccessCode) _isAccessCodeObscured = !_isAccessCodeObscured;
                      }),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: hint ?? 'Completar campo...',
              hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3), fontSize: 13),
            ),
            validator: (v) => v!.isEmpty ? 'Dato requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'FECHA DE NACIMIENTO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextFormField(
            controller: _dobController,
            onTap: _selectDate,
            readOnly: true,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.calendar_month_rounded, color: const Color(0xFF1E3A8A).withOpacity(0.7), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: 'Seleccionar fecha...',
              hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3), fontSize: 13),
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
    Map<String, IconData>? itemIcons,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: DropdownButtonFormField<String>(
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(
                        children: [
                          if (itemIcons != null && itemIcons.containsKey(e))
                            Icon(itemIcons[e], size: 18, color: const Color(0xFF1E3A8A).withOpacity(0.7)),
                          if (itemIcons != null && itemIcons.containsKey(e))
                            const SizedBox(width: 12),
                          Text(e, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
            dropdownColor: Colors.white,
            iconEnabledColor: const Color(0xFF1E3A8A).withOpacity(0.7),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A).withOpacity(0.7), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            validator: (v) => v == null ? 'Seleccione una opción' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
              border: Border.all(color: const Color(0xFFFACC15).withOpacity(0.5), width: 2),
              image: _profileImage != null
                  ? DecorationImage(
                      image: (kIsWeb ? NetworkImage(_profileImage!.path) : FileImage(File(_profileImage!.path))) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profileImage == null
                ? Icon(Icons.add_a_photo_rounded, size: 32, color: Colors.white.withOpacity(0.5))
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFACC15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF1E3A8A)),
            ),
          ),
        ],
      ),
    );
  }
}