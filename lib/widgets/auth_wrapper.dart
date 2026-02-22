import 'package:asystem_cobacam/screens/dashboards/academic/academic_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/tutor/tutor_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/services/session_service.dart';
import 'package:asystem_cobacam/widgets/session_guard.dart';
import 'package:asystem_cobacam/data/access_codes.dart';
import 'package:asystem_cobacam/services/access_code_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectUser();
    });
  }

  Future<void> _redirectUser() async {
    try {
      // Inicializar códigos de acceso
      AccessCodeService().initializeCodes(campusRoleCodes);

      await Future.delayed(const Duration(seconds: 2));
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (user == null) {
        _goToWelcome();
        return;
      }

      // Registrar sesión
      SessionService()
          .registerCurrentSession()
          .catchError((e) => debugPrint("Session error: $e"));

      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value;
        String? role;
        if (data is Map) {
          final safeMap = Map<dynamic, dynamic>.from(data);
          role = safeMap['role']?.toString();
        }
        _navigateToDashboard(role);
      } else {
        _goToWelcome();
      }
    } catch (e) {
      if (mounted) _goToWelcome();
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()));
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;
    Widget dashboard;
    switch (role) {
      case 'Alumno':
        dashboard = const StudentDashboardScreen();
        break;
      case 'Tutor':
        dashboard = const TutorDashboardScreen();
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
        dashboard = const WelcomeScreen();
    }

    if (role != null) {
      dashboard = SessionGuard(child: dashboard);
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => dashboard));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeIn(
          duration: const Duration(seconds: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo1.png', height: 120),
              const SizedBox(height: 40),
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 24),
              Text(
                "Iniciando Asystem Cobacam",
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
