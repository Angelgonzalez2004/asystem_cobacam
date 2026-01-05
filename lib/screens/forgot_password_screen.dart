import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.trim().isEmpty) {
      UiHelpers.showSnackBar(
          context, 'Por favor, ingresa tu correo electrónico.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'Enlace de recuperación enviado. Revisa tu correo.');
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ocurrió un error.';
      if (e.code == 'user-not-found') {
        message = 'No se encontró un usuario con ese correo.';
      }
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Ocurrió un error inesperado.',
            isError: true);
      }
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recuperación de Acceso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icono Institucional de Seguridad
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_reset_rounded, size: 64, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 40),
                        
                        Text(
                          '¿Problemas para ingresar?',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ingrese su correo electrónico institucional y le enviaremos las instrucciones para restablecer su contraseña.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        Card(
                          elevation: 0,
                          color: isDark ? theme.cardTheme.color : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _emailController,
                                  decoration: _buildInputDecoration('Correo Institucional', Icons.alternate_email),
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                                const SizedBox(height: 32),
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : SizedBox(
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _handlePasswordReset,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            elevation: 0,
                                          ),
                                          child: const Text('Enviar Instrucciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            '‹ Cancelar y volver',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
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
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon:
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
    );
  }
}
