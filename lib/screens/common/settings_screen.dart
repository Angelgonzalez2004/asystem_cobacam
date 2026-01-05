import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showSnackBar('No se pudo encontrar el usuario actual.', isError: true);
        return;
      }

      // Re-authenticate the user
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(cred);

      // If re-authentication is successful, update the password
      await user.updatePassword(_newPasswordController.text);

      _showSnackBar('Contraseña actualizada exitosamente.', isError: false);
      // Clear fields after success
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

    } on FirebaseAuthException catch (e) {
      String message = 'Ocurrió un error.';
      if (e.code == 'wrong-password') {
        message = 'La contraseña actual es incorrecta.';
      } else if (e.code == 'weak-password') {
        message = 'La nueva contraseña es muy débil.';
      } else {
        message = 'Error: ${e.message}';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar('Un error inesperado ocurrió.', isError: true);
    } finally {
      if(mounted){
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cambiar Contraseña',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: const InputDecoration(labelText: 'Contraseña Actual'),
                    obscureText: true,
                    validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(labelText: 'Nueva Contraseña'),
                    obscureText: true,
                    validator: (val) {
                      if (val!.isEmpty) return 'Campo requerido';
                      if (val.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(labelText: 'Confirmar Nueva Contraseña'),
                    obscureText: true,
                    validator: (val) {
                      if (val!.isEmpty) return 'Campo requerido';
                      if (val != _newPasswordController.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _changePassword,
                          child: const Text('Actualizar Contraseña'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
