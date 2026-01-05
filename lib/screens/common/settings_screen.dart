import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>(); // Separate key for email form
  
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Controllers for Email Change
  final _newEmailController = TextEditingController();
  final _passwordForEmailController = TextEditingController();

  bool _isLoading = false;
  bool _isObscureCurrent = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  bool _isObscureEmailPass = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    _passwordForEmailController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;

      // Re-authenticate
      final cred = EmailAuthProvider.credential(email: user.email!, password: _passwordForEmailController.text);
      await user.reauthenticateWithCredential(cred);

      // Update Email in Auth
      String newEmail = _newEmailController.text.trim();
      await user.updateEmail(newEmail);
      
      // Update Email in Database
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({'email': newEmail});

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Correo actualizado exitosamente.');
        _newEmailController.clear();
        _passwordForEmailController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Error al actualizar correo.';
      if (e.code == 'wrong-password') message = 'Contraseña incorrecta.';
      if (e.code == 'email-already-in-use') message = 'Este correo ya está en uso.';
      if (e.code == 'invalid-email') message = 'Formato de correo inválido.';
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        if (mounted) UiHelpers.showSnackBar(context, 'No se pudo encontrar el usuario actual.', isError: true);
        return;
      }

      final cred = EmailAuthProvider.credential(email: user.email!, password: _currentPasswordController.text);
      await user.reauthenticateWithCredential(cred);
      if (!mounted) return;

      await user.updatePassword(_newPasswordController.text);
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Contraseña actualizada exitosamente.');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ocurrió un error.';
      if (e.code == 'wrong-password') {
        message = 'La contraseña actual es incorrecta.';
      } else if (e.code == 'weak-password') {
        message = 'La nueva contraseña es muy débil.';
      }
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Cerrar Sesión',
      content: '¿Estás seguro de que quieres salir?',
      confirmText: 'Salir',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: FadeInUp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle(theme, 'Preferencias Visuales'),
                  const SizedBox(height: 16),
                  _buildThemeCard(theme, themeProvider, isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle(theme, 'Seguridad'),
                  const SizedBox(height: 16),
                  _buildEmailCard(theme, isDark), // New Email Card
                  const SizedBox(height: 24),
                  _buildPasswordCard(theme, isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle(theme, 'Cuenta'),
                  const SizedBox(height: 16),
                  _buildActionCard(theme, isDark),
                  const SizedBox(height: 48),
                  _buildFooter(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1));
  }

  Widget _buildThemeCard(ThemeData theme, ThemeProvider provider, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      child: ListTile(
        leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: theme.colorScheme.primary),
        title: const Text('Tema Oscuro', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Alternar entre modo claro y oscuro'),
        trailing: Switch.adaptive(
          value: isDark,
          onChanged: (val) => provider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
        ),
      ),
    );
  }

  Widget _buildEmailCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Actualizar Correo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newEmailController,
                decoration: const InputDecoration(labelText: 'Nuevo Correo', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                validator: (val) => val!.isEmpty || !val.contains('@') ? 'Correo inválido' : null,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(_passwordForEmailController, 'Contraseña Actual', _isObscureEmailPass, () => setState(() => _isObscureEmailPass = !_isObscureEmailPass)),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _changeEmail, child: const Text('Guardar Nuevo Correo')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPasswordField(_currentPasswordController, 'Contraseña Actual', _isObscureCurrent, () => setState(() => _isObscureCurrent = !_isObscureCurrent)),
              const SizedBox(height: 16),
              _buildPasswordField(_newPasswordController, 'Nueva Contraseña', _isObscureNew, () => setState(() => _isObscureNew = !_isObscureNew)),
              const SizedBox(height: 16),
              _buildPasswordField(_confirmPasswordController, 'Confirmar Contraseña', _isObscureConfirm, () => setState(() => _isObscureConfirm = !_isObscureConfirm)),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _changePassword, child: const Text('Actualizar Contraseña')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool obscure, VoidCallback onToggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: onToggle),
      ),
      validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
    );
  }

  Widget _buildActionCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        const Text('Asystem Cobacam v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text('Desarrollado para COBACAM', style: theme.textTheme.bodySmall),
      ],
    );
  }
}