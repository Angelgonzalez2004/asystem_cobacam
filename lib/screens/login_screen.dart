import 'dart:async';
import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/tutor/tutor_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/forgot_password_screen.dart';
import 'package:asystem_cobacam/screens/signup_screen.dart';
import 'package:asystem_cobacam/services/session_service.dart';
import 'package:asystem_cobacam/services/notification_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
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
        setState(() {
          _lockoutTime = null;
          _lockoutMessage = '';
          _failedAttempts = 0;
        });
      } else {
        final remaining = _lockoutTime!.difference(DateTime.now());
        setState(() {
          _lockoutMessage = 'Espera ${remaining.inSeconds}s';
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

  // MÉTODO PARA MOSTRAR MENSAJES CON ESTILO INSTITUCIONAL
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: isError ? Colors.red.shade900.withOpacity(0.9) : Colors.green.shade800.withOpacity(0.9),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_lockoutTime != null && DateTime.now().isBefore(_lockoutTime!)) {
      _showMessage('Acceso bloqueado temporalmente por seguridad.', isError: true);
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showMessage('Por favor, ingresa tu correo y contraseña.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _failedAttempts = 0;
      if (!mounted) return;

      User? user = userCredential.user;
      if (user != null) {
        DatabaseReference userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await userRef.get();

        if (!mounted) return;

        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          String? role;
          if (data is Map) {
            final safeMap = Map<Object?, Object?>.from(data);
            role = safeMap['role']?.toString().trim();
          }
          SessionService().registerCurrentSession();
          NotificationService.saveDeviceToken();
          _navigateToDashboard(role);
        } else {
          _showMessage('No se encontraron datos vinculados a esta cuenta.', isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _failedAttempts++;
      String message = 'Credenciales incorrectas.';

      if (e.code == 'too-many-requests') {
        _triggerLockout(300);
        message = 'Demasiados intentos fallidos. Cuenta bloqueada temporalmente.';
      } else if (_failedAttempts >= 5) {
        _triggerLockout(60);
        message = 'Demasiados intentos. Espera 1 minuto.';
      } else if (e.code == 'user-not-found') {
        message = 'El correo ingresado no está registrado.';
      } else if (e.code == 'wrong-password') {
        message = 'La contraseña es incorrecta.';
      } else if (e.code == 'invalid-credential') {
        message = 'Correo o contraseña inválidos.';
      }

      _showMessage(message, isError: true);
    } catch (e) {
      if (mounted) _showMessage('Error de conexión: Intentar más tarde.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;
    Widget dashboard;
    switch (role) {
      case 'Alumno': dashboard = const StudentDashboardScreen(); break;
      case 'Tutor': dashboard = const TutorDashboardScreen(); break;
      case 'Academica': dashboard = const AcademicDashboardScreen(); break;
      case 'Prefecta': dashboard = const PrefectDashboardScreen(); break;
      case 'Personal Administrativo por Plantel': dashboard = const CampusAdminDashboardScreen(); break;
      case 'Personal Administrativo General': dashboard = const GeneralAdminDashboardScreen(); break;
      default: 
        _showMessage('Rol ($role) no reconocido en el sistema.', isError: true);
        return;
    }
    Navigator.pushReplacement(context, SlideRightRoute(page: dashboard));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLocked = _lockoutTime != null && DateTime.now().isBefore(_lockoutTime!);

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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(40.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 60, offset: const Offset(0, 30)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Hero(
                              tag: 'app_logo_main',
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Image.asset('assets/images/logo1.png', height: 70),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'ASYSTEM COBACAM',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3.0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLocked ? 'ACCESO RESTRINGIDO' : 'INICIAR SESIÓN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isLocked ? colors.error : colors.secondary,
                              fontSize: 24,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 48),

                          _buildPremiumTextField(
                            controller: _emailController,
                            label: 'CORREO INSTITUCIONAL',
                            icon: Icons.alternate_email_rounded,
                            enabled: !isLocked,
                          ),
                          const SizedBox(height: 24),
                          _buildPremiumTextField(
                            controller: _passwordController,
                            label: 'CONTRASEÑA',
                            icon: Icons.lock_person_rounded,
                            isPassword: true,
                            enabled: !isLocked,
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLocked ? null : () => Navigator.push(context, SlideRightRoute(page: const ForgotPasswordScreen())),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : ElevatedButton(
                                  onPressed: isLocked ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isLocked ? Colors.white24 : Colors.white,
                                    foregroundColor: const Color(0xFF0F172A),
                                    minimumSize: const Size(double.infinity, 65),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    isLocked ? _lockoutMessage.toUpperCase() : 'INGRESAR',
                                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0),
                                  ),
                                ),

                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('¿No tienes cuenta? ', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                              GestureDetector(
                                onTap: isLocked ? null : () => Navigator.push(context, SlideRightRoute(page: const SignUpScreen())),
                                child: Text('Regístrate', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w900)),
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

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _isPasswordObscured : false,
            enabled: enabled,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              filled: false,
              prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.6), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              hintText: 'Escribe aquí...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
