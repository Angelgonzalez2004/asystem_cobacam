import 'dart:io';
import 'package:asystem_cobacam/data/access_codes.dart';
import 'package:asystem_cobacam/data/campus_list.dart';
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
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String? role = _selectedRole;
    final String code = _accessCodeController.text;

    if (role == null) {
      _showErrorSnackBar('Por favor, selecciona un rol.');
      setState(() => _isLoading = false);
      return;
    }

    if (role == 'Personal Administrativo General') {
      if (code != generalAdminCode) {
        _showErrorSnackBar('El Código de Administrador General es incorrecto.');
        setState(() => _isLoading = false);
        return;
      }
    } else {
      final String? campus = _selectedCampus;
      if (campus == null) {
        _showErrorSnackBar('Por favor, selecciona un plantel.');
        setState(() => _isLoading = false);
        return;
      }
      final String? correctCode = campusRoleCodes[campus]?[role];
      if (correctCode == null || code != correctCode) {
        _showErrorSnackBar('El Código de Acceso es incorrecto para el rol y plantel seleccionados.');
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        String? profileImageUrl;
        if (_profileImage != null) {
          final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}');
          final uploadTask = await storageRef.putFile(File(_profileImage!.path));
          profileImageUrl = await uploadTask.ref.getDownloadURL();
        }

        DatabaseReference userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        await userRef.set({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'campus': _selectedRole == 'Personal Administrativo General' ? 'General' : _selectedCampus,
          'dateOfBirth': _dobController.text,
          'location': _locationController.text.trim(),
          'profileImageUrl': profileImageUrl,
        });

        _showSuccessSnackBar('¡Cuenta creada exitosamente!');
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocurrió un error.';
      if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya está en uso.';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('Ocurrió un error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGeneralAdmin = _selectedRole == 'Personal Administrativo General';

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 30),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: colors.surface,
                            backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                            child: _profileImage == null
                                ? Icon(Icons.add_a_photo, size: 40, color: colors.primary.withAlpha(200))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Crear Nueva Cuenta',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),
                      _buildDropdown(_roles, 'Selecciona un Rol', Icons.person_pin, (val) {
                        setState(() {
                          _selectedRole = val;
                          _selectedCampus = null;
                        });
                      }),
                      const SizedBox(height: 20),
                      _buildTextFormField(_nameController, 'Nombre Completo', Icons.person),
                      const SizedBox(height: 20),
                      _buildTextFormField(_emailController, 'Correo Electrónico', Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 20),
                      _buildTextFormField(_passwordController, 'Contraseña', Icons.lock, isPassword: true),
                      const SizedBox(height: 20),
                      _buildTextFormField(_locationController, 'Lugar Actual', Icons.location_city),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
                        child: (_selectedRole != null && !isGeneralAdmin)
                            ? _buildDropdown(cobacamCampuses, 'Selecciona un Plantel', Icons.school, (val) => setState(() => _selectedCampus = val))
                            : const SizedBox.shrink(),
                      ),
                      if (_selectedRole != null && !isGeneralAdmin) const SizedBox(height: 20),
                      TextFormField(
                        controller: _dobController,
                        decoration: _buildInputDecoration('Fecha de Nacimiento', Icons.calendar_today),
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
                        child: (isGeneralAdmin || (_selectedRole != null && _selectedCampus != null))
                            ? _buildTextFormField(_accessCodeController, 'Código de Acceso', Icons.vpn_key)
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _handleSignUp,
                              child: const Text('Crear Cuenta'),
                            ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          '‹ Volver a Inicio de Sesión',
                          style: TextStyle(color: colors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: _buildInputDecoration(label, icon, isPassword: isPassword),
      obscureText: isPassword ? _isPasswordObscured : false,
      keyboardType: keyboardType,
      validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
    );
  }
  
  Widget _buildDropdown(List<String> items, String label, IconData icon, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(color: Colors.black87), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      decoration: _buildInputDecoration(label, icon),
      dropdownColor: Colors.white,
      validator: (val) => val == null ? 'Campo requerido' : null,
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isPassword = false}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colors.primary.withAlpha(200)),
      errorStyle: TextStyle(color: colors.error),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                color: colors.primary.withAlpha(200),
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
