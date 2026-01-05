import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/forgot_password_screen.dart';
import 'package:asystem_cobacam/screens/signup_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      UiHelpers.showSnackBar(context, 'Por favor, ingresa correo y contraseña.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      User? user = userCredential.user;
      if (user != null) {
        debugPrint("Usuario autenticado: ${user.uid}. Buscando datos...");

        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await userRef.get();

        if (!mounted) return;

        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          String? role;

          if (data is Map) {
            final safeMap = Map<dynamic, dynamic>.from(data);
            role = safeMap['role']?.toString();
          }

          debugPrint("Rol encontrado: $role");
          _navigateToDashboard(role);
        } else {
          UiHelpers.showSnackBar(context, 'No se encontraron datos de usuario.',
              isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint("Error de Auth: ${e.code}");
      String message = 'Credenciales incorrectas. Inténtalo de nuevo.';
      if (e.code == 'user-not-found') message = 'Usuario no encontrado.';
      if (e.code == 'wrong-password') message = 'Contraseña incorrecta.';
      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error inesperado en Login: $e");
      UiHelpers.showSnackBar(context, 'Ocurrió un error inesperado: $e',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;

    Widget dashboard;
    switch (role) {
      case 'Alumno':
        dashboard = const StudentDashboardScreen();
        break;
      case 'Academica':
        dashboard = const AcademicDashboardScreen();
        break;
      case 'Prefecta':
        dashboard = const PrefectDashboardScreen();
        break;
      case 'Personal Administrativo por Plantel':
        dashboard = const CampusAdminDashboardScreen();
        break;
      case 'Personal Administrativo General':
        dashboard = const GeneralAdminDashboardScreen();
        break;
      default:
        UiHelpers.showSnackBar(context, 'Rol de usuario ($role) no reconocido.',
            isError: true);
        return;
    }

    // Animate transition
    Navigator.pushReplacement(context, SlideRightRoute(page: dashboard));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Centrado
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset('assets/images/logo1.png', height: 100),
                        ),
                        const SizedBox(height: 48),
                        
                        // Textos de Bienvenida
                        Text(
                          'Portal Institucional',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inicie sesión para acceder a su panel',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Formulario
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
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _passwordController,
                                  decoration: _buildInputDecorationWithToggle('Contraseña', Icons.lock_outline),
                                  obscureText: _isPasswordObscured,
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.push(context, SlideRightRoute(page: const ForgotPasswordScreen())),
                                    child: Text(
                                      '¿Olvidó su contraseña?',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : SizedBox(
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            elevation: 0,
                                          ),
                                          child: const Text('Entrar al Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Enlace de Registro
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿Aún no tiene una cuenta? ',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(context, SlideRightRoute(page: const SignUpScreen())),
                              child: Text(
                                'Regístrese aquí',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Botón Volver
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            '‹ Volver al inicio',
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
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  InputDecoration _buildInputDecorationWithToggle(String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon:
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      suffixIcon: IconButton(
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
      ),
    );
  }
}
