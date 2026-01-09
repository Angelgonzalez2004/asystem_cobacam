import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_home_screen.dart';
import 'package:asystem_cobacam/screens/common/profile_screen.dart'; 
import 'package:asystem_cobacam/screens/common/settings_screen.dart'; 
import 'package:asystem_cobacam/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_query_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/school_cycle_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/non_attendance_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/credential_generator_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/incidence_report_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/ai_assistant_screen.dart'; // Importar
import 'package:asystem_cobacam/widgets/refresh_app_button.dart';

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
      const GroupManagementScreen(),
      const SchoolCycleManagementScreen(),
      const StudentManagementScreen(),
      const GroupScheduleManagementScreen(),
      const AttendanceScreen(),
      const NonAttendanceManagementScreen(),
      const AttendanceQueryScreen(),
      const CredentialGeneratorScreen(),
      const Center(child: Text("Scanner QR (Próximamente)")), 
      const IncidenceReportScreen(), 
      const AIAssistantScreen(), // Opción 13
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
      'Asistente IA',
    ];
  }

  Future<void> _initUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email ?? '';
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _userRef!.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
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
      case 'ia':
        index = 13;
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
        title: Text(_screenTitles[safeIndex]),
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
    );
  }
}