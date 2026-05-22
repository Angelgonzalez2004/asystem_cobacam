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
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
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
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset('assets/images/logo1.png', height: 60),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'ASYSTEM COBACAM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLocked ? 'ACCESO TEMPORALMENTE BLOQUEADO' : 'AUTENTICACIÓN DE USUARIO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isLocked ? colors.error : const Color(0xFFFACC15),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Favor de ingresar sus credenciales institucionales para acceder a su panel de gestión.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildPremiumTextField(
                            controller: _emailController,
                            label: 'CORREO ELECTRÓNICO INSTITUCIONAL',
                            icon: Icons.alternate_email_rounded,
                            enabled: !isLocked,
                            hint: 'ejemplo@cobacam.edu.mx',
                          ),
                          const SizedBox(height: 20),
                          _buildPremiumTextField(
                            controller: _passwordController,
                            label: 'CLAVE DE ACCESO (CONTRASEÑA)',
                            icon: Icons.lock_person_rounded,
                            isPassword: true,
                            enabled: !isLocked,
                            hint: 'Ingrese su clave...',
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLocked ? null : () => Navigator.push(context, SlideRightRoute(page: const ForgotPasswordScreen())),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFACC15),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              ),
                              child: const Text(
                                '¿Dificultades para acceder?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : ElevatedButton(
                                  onPressed: isLocked ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isLocked ? Colors.white24 : Colors.white,
                                    foregroundColor: const Color(0xFF1E3A8A),
                                    minimumSize: const Size(double.infinity, 60),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 8,
                                    shadowColor: Colors.black.withOpacity(0.4),
                                  ),
                                  child: Text(
                                    isLocked ? _lockoutMessage.toUpperCase() : 'VERIFICAR Y ENTRAR',
                                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15),
                                  ),
                                ),

                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿Nuevo en la comunidad? ',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: isLocked ? null : () => Navigator.push(context, SlideRightRoute(page: const SignUpScreen())),
                                  child: const Text(
                                    'Solicitar Registro',
                                    style: TextStyle(
                                      color: Color(0xFFFACC15),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
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
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: FadeInDown(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 10),
                      Text(
                        'VOLVER AL INICIO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    String? hint,
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
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _isPasswordObscured : false,
            enabled: enabled,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600),
            cursorColor: const Color(0xFF1E3A8A),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A).withOpacity(0.7), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF1E3A8A).withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: hint,
              hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
