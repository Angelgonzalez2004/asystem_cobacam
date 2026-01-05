import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/forgot_password_screen.dart';
import 'package:asystem_cobacam/screens/signup_screen.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showErrorSnackBar('Por favor, ingresa correo y contraseña.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        debugPrint("Usuario autenticado: ${user.uid}. Buscando datos...");
        
        DatabaseReference userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await userRef.get();

        if (snapshot.exists && snapshot.value != null) {
          // --- CORRECCIÓN DE PARSEO SEGURO PARA WEB ---
          final data = snapshot.value;
          String? role;

          if (data is Map) {
             // Convertimos de forma segura evitando 'as Map<String, dynamic>' estricto
             final safeMap = Map<dynamic, dynamic>.from(data);
             role = safeMap['role']?.toString();
          }
          
          debugPrint("Rol encontrado: $role");
          _navigateToDashboard(role);
        } else {
          _showErrorSnackBar('No se encontraron datos de usuario.');
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Error de Auth: ${e.code}");
      String message = 'Credenciales incorrectas. Inténtalo de nuevo.';
      if (e.code == 'user-not-found') message = 'Usuario no encontrado.';
      if (e.code == 'wrong-password') message = 'Contraseña incorrecta.';
      _showErrorSnackBar(message);
    } catch (e) {
      debugPrint("Error inesperado en Login: $e");
      _showErrorSnackBar('Ocurrió un error inesperado: $e');
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
        _showErrorSnackBar('Rol de usuario ($role) no reconocido.');
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => dashboard));
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(tag: 'app_logo', child: Image.asset('assets/images/logo1.png', height: 80)),
                    const SizedBox(height: 30),
                    Text('Inicio de Sesión', textAlign: TextAlign.center, style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    TextField(controller: _emailController, decoration: _buildInputDecoration('Correo Electrónico', Icons.email), keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      decoration: _buildInputDecorationWithToggle('Contraseña', Icons.lock),
                      obscureText: _isPasswordObscured,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(context, SlideRightRoute(page: const ForgotPasswordScreen())),
                        child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: colors.secondary.withAlpha(220))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            child: const Text('Entrar'),
                          ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('‹ Volver', style: TextStyle(color: colors.secondary))),
                        Text('|', style: TextStyle(color: colors.primary.withAlpha(100))),
                        TextButton(onPressed: () => Navigator.push(context, SlideRightRoute(page: const SignUpScreen())), child: Text('Crear Cuenta', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colors.primary.withAlpha(200)),
    );
  }
  
  InputDecoration _buildInputDecorationWithToggle(String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colors.primary.withAlpha(200)),
      suffixIcon: IconButton(
        icon: Icon(
          _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
          color: colors.primary.withAlpha(200),
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