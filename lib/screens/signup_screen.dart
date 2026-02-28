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
                                  'ASYSTEM COBACAM',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3.0),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'REGISTRO DE USUARIO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w200, letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 40),

                                Center(child: _buildImagePicker()),
                                const SizedBox(height: 48),

                                _buildSectionTitle('INFORMACIÓN PERSONAL', Icons.person_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildPremiumField(controller: _nameController, label: 'NOMBRE COMPLETO', icon: Icons.badge_outlined),
                                  _buildDateSelector(),
                                ]),
                                _buildPremiumField(controller: _locationController, label: 'LUGAR DE RESIDENCIA', icon: Icons.location_on_outlined),
                                
                                const SizedBox(height: 32),
                                _buildSectionTitle('DATOS INSTITUCIONALES', Icons.school_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildDropdown(items: _roles, label: 'ROL INSTITUCIONAL', icon: Icons.work_outline, onChanged: (v) => setState(() => _selectedRole = v)),
                                  if (_selectedRole != null && _selectedRole != 'Personal Administrativo General')
                                    _buildDropdown(items: cobacamCampuses, label: 'SELECCIONA TU PLANTEL', icon: Icons.apartment_rounded, onChanged: (v) => setState(() => _selectedCampus = v)),
                                ]),
                                
                                if (_selectedRole == 'Alumno' || _selectedRole == 'Tutor')
                                  _buildPremiumField(controller: _matriculaController, label: 'MATRÍCULA DEL ALUMNO', icon: Icons.badge_outlined, focusNode: _matriculaFocus),

                                const SizedBox(height: 32),
                                _buildSectionTitle('SEGURIDAD', Icons.lock_rounded),
                                _buildResponsiveRow(isWide, [
                                  _buildPremiumField(controller: _emailController, label: 'CORREO INSTITUCIONAL', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                                  _buildPremiumField(controller: _passwordController, label: 'CONTRASEÑA', icon: Icons.vpn_key_outlined, isPassword: true),
                                ]),
                                
                                if (_selectedRole != null && (_selectedCampus != null || _selectedRole == 'Personal Administrativo General'))
                                  _buildPremiumField(controller: _accessCodeController, label: 'CÓDIGO DE VALIDACIÓN', icon: Icons.security_rounded, isAccessCode: true, focusNode: _accessCodeFocus),

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
                                        ),
                                        child: const Text('REGISTRAR EN EL SISTEMA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                      ),

                                const SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: const Text('Inicia sesión', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900)),
                                    ),
                                  ],
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
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(width: 16),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  Widget _buildResponsiveRow(bool isWide, List<Widget> children) {
    if (!isWide) return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 20), child: c)).toList());
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: c))).toList(),
      ),
    );
  }

  Widget _buildPremiumField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, bool isAccessCode = false, TextInputType? keyboardType, FocusNode? focusNode}) {
    bool obscure = isPassword ? _isPasswordObscured : (isAccessCode ? _isAccessCodeObscured : false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: TextFormField(
            controller: controller, focusNode: focusNode, obscureText: obscure, keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: false,
              prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: (isPassword || isAccessCode) ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.4), size: 18), onPressed: () => setState(() { if(isPassword) _isPasswordObscured = !_isPasswordObscured; if(isAccessCode) _isAccessCodeObscured = !_isAccessCodeObscured; })) : null,
              hintText: 'Escribe aquí...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FECHA DE NACIMIENTO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: TextFormField(
            controller: _dobController, onTap: _selectDate, readOnly: true,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(filled: false, prefixIcon: Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required List<String> items, required String label, required IconData icon, required Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: DropdownButtonFormField<String>(
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.black87, fontSize: 13)))).toList(),
            onChanged: onChanged, dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(filled: false, prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7), size: 18), border: InputBorder.none),
            validator: (v) => v == null ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 60, backgroundColor: Colors.white.withOpacity(0.1),
        backgroundImage: _profileImage != null ? (kIsWeb ? NetworkImage(_profileImage!.path) : FileImage(File(_profileImage!.path))) as ImageProvider : null,
        child: _profileImage == null ? const Icon(Icons.camera_enhance_rounded, size: 40, color: Colors.white) : null,
      ),
    );
  }
}
