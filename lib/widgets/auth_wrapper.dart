import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Ejecutamos la redirección después de que se monte el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectUser();
    });
  }

  Future<void> _redirectUser() async {
    try {
      debugPrint("🔍 Verificando sesión...");
      // Pequeño delay para evitar conflictos de renderizado y dar tiempo a Firebase
      await Future.delayed(const Duration(seconds: 1));

      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (user == null) {
        debugPrint("👤 No hay usuario logueado. Yendo a WelcomeScreen.");
        _goToWelcome();
        return;
      }

      debugPrint("✅ Usuario detectado: ${user.uid}. Buscando rol en DB...");
      
      // Obtenemos los datos del usuario
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        // Parsing seguro para Web
        final data = snapshot.value;
        String? role;

        if (data is Map) {
          // Usamos Map<dynamic, dynamic> para evitar errores de cast en web
          final safeMap = Map<dynamic, dynamic>.from(data);
          role = safeMap['role']?.toString();
        } 
        
        debugPrint("🔑 Rol encontrado: $role");
        _navigateToDashboard(role);
      } else {
        debugPrint("⚠️ El usuario existe en Auth pero no en la Base de Datos.");
        _goToWelcome();
      }
    } catch (e) {
      debugPrint("🚨 Error crítico en AuthWrapper: $e");
      if (mounted) {
        _goToWelcome();
      }
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;

    Widget dashboard;
    switch (role) {
      case 'prefecta':
        dashboard = const PrefectDashboardScreen();
        break;
      case 'academico':
        dashboard = const AcademicDashboardScreen();
        break;
      case 'director':
        dashboard = const CampusAdminDashboardScreen();
        break;
      case 'admin':
        dashboard = const GeneralAdminDashboardScreen();
        break;
      case 'alumno':
        dashboard = const StudentDashboardScreen();
        break;
      default:
        debugPrint("❓ Rol desconocido o nulo. Redirigiendo a inicio.");
        dashboard = const WelcomeScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => dashboard),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Cargando sistema...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}