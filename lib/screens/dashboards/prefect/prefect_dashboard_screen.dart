import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_home_screen.dart';
import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_query_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/school_cycle_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/non_attendance_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/credential_generator_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/incidence_report_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/ai_assistant_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_faq_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/statistics_screen.dart'; // Importado
import 'package:asystem_cobacam/widgets/refresh_app_button.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_viewer_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/teacher_schedule_viewer_screen.dart';

class PrefectDashboardScreen extends StatefulWidget {
  const PrefectDashboardScreen({super.key});

  @override
  State<PrefectDashboardScreen> createState() => _PrefectDashboardScreenState();
}

class _PrefectDashboardScreenState extends State<PrefectDashboardScreen> {
  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String _userEmail = '';
  String? _userPhotoUrl;
  String? _userCampus;
  int _selectedIndex = 0;
  DatabaseReference? _userRef;

  // Screen List
  late List<Widget> _screens;
  late List<String> _screenTitles;

  @override
  void initState() {
    super.initState();
    _initUserData();
    _initScreens();
  }

  void _initScreens() {
    _screens = [
      PrefectHomeScreen(campus: _userCampus, onNavigate: _onNavigate),
      const ProfileScreen(isEmbedded: true),
      const SettingsScreen(isEmbedded: true),
      GroupManagementScreen(onNavigate: _onNavigate),
      const SchoolCycleManagementScreen(),
      const StudentManagementScreen(),
      const GroupScheduleManagementScreen(),
      const AttendanceScreen(),
      const NonAttendanceManagementScreen(),
      const AttendanceQueryScreen(),
      const CredentialGeneratorScreen(),
      const Center(child: Text("Scanner QR (Próximamente)")),
      const IncidenceReportScreen(),
      const StatisticsScreen(), // Opción 13
      const AIAssistantScreen(), // Opción 14
      const PrefectFaqScreen(), // Opción 15
      const GroupScheduleViewerScreen(), // Opción 16
      const TeacherScheduleViewerScreen(), // Opción 17
    ];

    _screenTitles = [
      'Avisos y Comunicados',
      'Perfil',
      'Ajustes',
      'Gestión de Grupos',
      'Gestión de Ciclos Escolares',
      'Gestión de Alumnos',
      'Gestión de Horarios',
      'Pase de Lista',
      'Días No Lectivos',
      'Consulta de Asistencia',
      'Generador de Credenciales',
      'Scanner QR',
      'Reporte de Incidencias',
      'Estadísticas y Métricas',
      'Asistente IA',
      'Manual Operativo (FAQ)',
      'Visor de Horarios (Grupo)',
      'Visor de Horarios (Maestro)',
    ];
  }

  Future<void> _initUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar desde caché (Offline First)
    if (mounted) {
      setState(() {
        _userName = prefs.getString('cached_userName') ?? _userName;
        _userRole = prefs.getString('cached_userRole') ?? _userRole;
        _userCampus = prefs.getString('cached_campus') ?? _userCampus;
        _userPhotoUrl = prefs.getString('cached_userPhotoUrl');

        if (user != null) _userEmail = user.email ?? '';

        // Re-init screens with cached data
        _initScreens();
      });
    }

    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _userRef!.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final userData =
                Map<String, dynamic>.from(event.snapshot.value as Map);

            // Guardar en caché para la próxima vez
            prefs.setString(
                'cached_userName', userData['fullName'] ?? 'Usuario');
            prefs.setString('cached_userRole', userData['role'] ?? 'Prefecta');
            if (userData['campus'] != null) {
              prefs.setString('cached_campus', userData['campus']);
            }
            if (userData['profileImageUrl'] != null) {
              prefs.setString(
                  'cached_userPhotoUrl', userData['profileImageUrl']);
            }

            if (mounted) {
              setState(() {
                _userName = userData['fullName'] ?? 'Usuario';
                _userRole = userData['role'] ?? 'Prefecta';
                _userPhotoUrl = userData['profileImageUrl'];
                _userCampus = userData['campus'];

                // Re-init screens to pass the updated campus
                _initScreens();
              });
            }
          } catch (e) {
            debugPrint("Error loading profile: $e");
          }
        }
      });
    }
  }

  void _onNavigate(String route) {
    int index = 0;
    switch (route) {
      case 'home':
        index = 0;
        break;
      case 'profile':
        index = 1;
        break;
      case 'settings':
        index = 2;
        break;
      case 'qr':
        index = 11;
        break;
      case 'incidencia':
        index = 12;
        break;
      case 'stats':
        index = 13;
        break;
      case 'ia':
        index = 14;
        break;
      case 'lista':
        index = 7;
        break;
      case 'alumnos':
        index = 5;
        break;
      case 'horarios':
        index = 6;
        break;
      case 'ciclos':
        index = 4;
        break;
      case 'no_lectivos':
        index = 8;
        break;
      case 'consulta_asistencia':
        index = 9;
        break;
      case 'credenciales':
        index = 10;
        break;
      case 'faq':
        index = 15;
        break;
      case 'visor_grupo':
        index = 16;
        break;
      case 'visor_maestro':
        index = 17;
        break;
      default:
        index = 0;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final safeIndex = (_selectedIndex >= 0 && _selectedIndex < _screens.length)
        ? _selectedIndex
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (safeIndex == 14) // Si es el asistente IA
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.psychology,
                    color: Color(0xFFF59E0B)), // Color Tertiary (Amber)
              ),
            Text(_screenTitles[safeIndex]),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        elevation: 0,
        centerTitle: true,
        actions: const [
          RefreshAppButton(),
          SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        role: _userRole,
        userName: _userName,
        userEmail: _userEmail,
        profileImageUrl: _userPhotoUrl,
        onNavigate: _onNavigate,
      ),
      body: _screens[safeIndex],
      floatingActionButton: safeIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _onNavigate('ia'),
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: Colors.white,
              icon: const Icon(
                  Icons.psychology_rounded), // Psychology icon looks more "AI"
              label: const Text(
                'Asistente IA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 6,
            )
          : null,
    );
  }
}
