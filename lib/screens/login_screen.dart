import 'dart:async';
import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/forgot_password_screen.dart';
import 'package:asystem_cobacam/screens/signup_screen.dart';
import 'package:asystem_cobacam/services/session_service.dart';
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

  // --- ANTI-BRUTE FORCE STATE ---
  int _failedAttempts = 0;
  DateTime? _lockoutTime;
  Timer? _lockoutTimer;
  String _lockoutMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _checkLockoutStatus() {
    if (_lockoutTime != null) {
      if (DateTime.now().isAfter(_lockoutTime!)) {
        // Lockout expired
        setState(() {
          _lockoutTime = null;
          _lockoutMessage = '';
          _failedAttempts = 0; // Reset after successful wait
        });
      } else {
        // Still locked, update timer
        final remaining = _lockoutTime!.difference(DateTime.now());
        setState(() {
          _lockoutMessage =
              'Espera ${remaining.inSeconds}s para intentar de nuevo';
        });
        _lockoutTimer = Timer(const Duration(seconds: 1), _checkLockoutStatus);
      }
    }
  }

  void _triggerLockout(int seconds) {
    setState(() {
      _lockoutTime = DateTime.now().add(Duration(seconds: seconds));
    });
    _checkLockoutStatus();
  }

  Future<void> _handleLogin() async {
    // 1. Check Lockout
    if (_lockoutTime != null && DateTime.now().isBefore(_lockoutTime!)) {
      UiHelpers.showSnackBar(
          context, 'Sistema bloqueado temporalmente por seguridad.',
          isError: true);
      return;
    }

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

      // --- LOGIN SUCCESS ---
      _failedAttempts = 0; // Reset attempts

      if (!mounted) return;

      User? user = userCredential.user;
      if (user != null) {
        debugPrint("Usuario autenticado: ${user.uid}. Buscando datos...");

        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await userRef.get();

        if (!mounted) return;

        if (snapshot.exists && snapshot.value != null) {
          try {
            final data = snapshot.value;
            String? role;
            if (data is Map) {
              final safeMap = Map<Object?, Object?>.from(data);
              role = safeMap['role']?.toString().trim();
            }

            debugPrint("Rol encontrado: '$role'");

            // Registrar sesión
            try {
              SessionService().registerCurrentSession();
            } catch (e) {
              debugPrint("Error registrando sesión: $e");
            }

            _navigateToDashboard(role);
          } catch (e) {
            debugPrint("Error processing user data: $e");
            UiHelpers.showSnackBar(
                context, 'Error al procesar datos de usuario.',
                isError: true);
          }
        } else {
          UiHelpers.showSnackBar(context, 'No se encontraron datos de usuario.',
              isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint("Error de Auth: ${e.code}");

      String message = 'Credenciales incorrectas.';

      // --- LOGIC: FAILED ATTEMPTS ---
      _failedAttempts++;

      if (e.code == 'too-many-requests') {
        // Firebase native protection triggered
        message = 'Demasiados intentos. Cuenta bloqueada temporalmente.';
        _triggerLockout(300); // 5 minutes (Local UI lock to match server)
      } else {
        // Local throttling
        if (_failedAttempts >= 5) {
          _triggerLockout(60); // 1 minute lockout
          message = 'Demasiados intentos fallidos. Espera 1 minuto.';
        } else if (_failedAttempts >= 3) {
          _triggerLockout(10); // 10 seconds warning lockout
          message = 'Credenciales incorrectas. Espera 10 segundos.';
        } else {
          // Normal error
          if (e.code == 'user-not-found') message = 'Usuario no encontrado.';
          if (e.code == 'wrong-password') message = 'Contraseña incorrecta.';
          if (e.code == 'invalid-credential')
            message = 'Correo o contraseña inválidos.';
        }
      }

      UiHelpers.showSnackBar(context, message, isError: true);
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error inesperado en Login: $e");
      UiHelpers.showSnackBar(context, 'Error de conexión: $e', isError: true);
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

    Navigator.pushReplacement(context, SlideRightRoute(page: dashboard));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLocked =
        _lockoutTime != null && DateTime.now().isBefore(_lockoutTime!);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Fondo
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: BorderSide(
                          color: isLocked
                              ? theme.colorScheme.error.withOpacity(0.5)
                              : theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                        ),
                      ),
                      color: isDark ? theme.cardColor : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Center(
                              child: Hero(
                                tag: 'app_logo',
                                child: Image.asset('assets/images/logo1.png',
                                    height: 80),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              isLocked ? 'Acceso Bloqueado' : 'Bienvenido',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isLocked
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isLocked
                                  ? 'Se han detectado múltiples intentos fallidos.'
                                  : 'Inicia sesión para continuar',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isLocked
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Inputs (Deshabilitados si está bloqueado)
                            _buildTextField(
                              controller: _emailController,
                              label: 'Correo Institucional',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isLocked,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              enabled: !isLocked,
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLocked
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        SlideRightRoute(
                                            page:
                                                const ForgotPasswordScreen())),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 8),
                                ),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isLocked
                                        ? Colors.grey
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Botón Login
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: isLocked ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isLocked
                                            ? Colors.grey
                                            : theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        isLocked ? _lockoutMessage : 'INGRESAR',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),

                            const SizedBox(height: 32),

                            // Footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿No tienes cuenta? ',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6)),
                                ),
                                GestureDetector(
                                  onTap: isLocked
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          SlideRightRoute(
                                              page: const SignUpScreen())),
                                  child: Text(
                                    'Regístrate',
                                    style: TextStyle(
                                      color: isLocked
                                          ? Colors.grey
                                          : theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? (theme.inputDecorationTheme.fillColor ??
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.3))
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isPasswordObscured : false,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon:
              Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordObscured
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: () => setState(
                      () => _isPasswordObscured = !_isPasswordObscured),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
