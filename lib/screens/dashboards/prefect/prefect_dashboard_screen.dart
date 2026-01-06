import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_home_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/profile_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/settings_screen.dart';
import 'package:asystem_cobacam/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/school_cycle_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/non_attendance_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_query_screen.dart';

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

  // Screen List - Indexes must match _onNavigate logic
  // 0: Home
  // 1: Profile
  // 2: Settings
  // 3: GroupManagement
  // 4: SchoolCycleManagement
  // 5: StudentManagement
  // 6: GroupScheduleManagement
  // 7: AttendanceScreen (Pase de Lista)
  // 8: NonAttendanceManagement
  // 9: AttendanceQueryScreen
  // 10: QR Scanner (Placeholder for now)
  // 11: Report Incident (Placeholder)

  late List<Widget> _screens;
  late List<String> _screenTitles;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initScreens();
  }

  void _initScreens() {
    _screens = [
      PrefectHomeScreen(campus: _userCampus), // Pass campus to Home
      const ProfileScreen(),
      const SettingsScreen(),
      const GroupManagementScreen(),
      const SchoolCycleManagementScreen(),
      const StudentManagementScreen(),
      const GroupScheduleManagementScreen(),
      const AttendanceScreen(),
      const NonAttendanceManagementScreen(),
      const AttendanceQueryScreen(),
      const Center(child: Text("Scanner QR (Próximamente)")),
      const Center(child: Text("Reporte de Incidencias (Próximamente)")),
    ];

    _screenTitles = [
      'Avisos y Comunicados', // Changed Title
      'Perfil',
      'Ajustes',
      'Gestión de Grupos',
      'Gestión de Ciclos Escolares',
      'Gestión de Alumnos',
      'Gestión de Horarios',
      'Pase de Lista',
      'Días No Lectivos',
      'Consulta de Asistencia',
      'Scanner QR',
      'Reportar Incidencia',
    ];
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _userName = userData['fullName'] ?? 'Usuario';
            _userRole = userData['role'] ?? 'Prefecta';
            _userEmail = userData['email'] ?? user.email ?? '';
            _userPhotoUrl = userData['profileImageUrl'];
            _userCampus = userData['campus'];
            
            // Re-init screens to pass the fetched campus
            _initScreens();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  void _onNavigate(String route) {
    int index = 0;
    switch (route) {
      case 'qr':
        index = 10;
        break;
      case 'incidencia':
        index = 11;
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
      default:
        index = 0;
    }
    
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Ensure safe index
    final safeIndex = (_selectedIndex >= 0 && _selectedIndex < _screens.length) 
        ? _selectedIndex 
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[safeIndex]),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      drawer: AppDrawer(
        role: 'Prefecta',
        userName: _userName,
        userEmail: _userEmail,
        profileImageUrl: _userPhotoUrl,
        onNavigate: _onNavigate,
      ),
      body: _screens[safeIndex],
    );
  }
}
