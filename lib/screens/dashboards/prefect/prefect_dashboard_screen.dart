import 'package:asystem_cobacam/screens/dashboards/prefect/group_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_home_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/profile_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/school_cycle_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/non_attendance_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_query_screen.dart';
import 'package:asystem_cobacam/screens/login_screen.dart';

class PrefectDashboardScreen extends StatefulWidget {
  const PrefectDashboardScreen({super.key});

  @override
  State<PrefectDashboardScreen> createState() => _PrefectDashboardScreenState();
}

class _PrefectDashboardScreenState extends State<PrefectDashboardScreen> {
  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String? _userPhotoUrl;
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const PrefectHomeScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
    const GroupManagementScreen(),
    const SchoolCycleManagementScreen(),
    const StudentManagementScreen(),
    const GroupScheduleManagementScreen(),
    const AttendanceScreen(),
    const NonAttendanceManagementScreen(),
    const AttendanceQueryScreen(),
  ];

  final List<String> _screenTitles = [
    'Inicio',
    'Perfil',
    'Ajustes',
    'Gestión de Grupos',
    'Gestión de Ciclos Escolares',
    'Gestión de Alumnos',
    'Gestión de Horarios de Grupo',
    'Registro de Asistencia',
    'Gestión de Días No Lectivos',
    'Consulta de Asistencia',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _userName = 'Usuario no autenticado';
          _userRole = 'N/A';
        });
      }
      return;
    }

    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _userName = userData['fullName'] ?? 'Nombre no disponible';
            _userRole = userData['role'] ?? 'Rol no disponible';
            _userPhotoUrl = userData['profileImageUrl'];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = 'Datos no encontrados';
            _userRole = 'N/A';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Error de carga';
          _userRole = 'N/A';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al cargar perfil: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.of(context).pop(); // Cerrar el drawer
  }

  void _viewFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_selectedIndex]),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/logo2.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.7),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _userPhotoUrl != null
                          ? () => _viewFullScreenImage(context, _userPhotoUrl!)
                          : null,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _userPhotoUrl != null
                            ? NetworkImage(_userPhotoUrl!)
                            : null,
                        child: _userPhotoUrl == null
                            ? const Icon(Icons.person, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Uso de variables previamente "unused" para mostrar info
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userRole.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Gestión de Grupos'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Gestión de Ciclos Escolares'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
            ListTile(
              leading: Icon(Icons.people, color: theme.colorScheme.primary),
              title: const Text('Gestión de Alumnos'),
              selected: _selectedIndex == 5,
              onTap: () => _onItemTapped(5),
            ),
            ListTile(
              leading: Icon(Icons.schedule, color: theme.colorScheme.primary),
              title: const Text('Gestión de Horarios de Grupo'),
              selected: _selectedIndex == 6,
              onTap: () => _onItemTapped(6),
            ),
            ListTile(
              leading:
                  Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary),
              title: const Text('Registro de Asistencia'),
              selected: _selectedIndex == 7,
              onTap: () => _onItemTapped(7),
            ),
            ListTile(
              leading: Icon(Icons.event_busy, color: theme.colorScheme.primary),
              title: const Text('Gestión de Días No Lectivos'),
              selected: _selectedIndex == 8,
              onTap: () => _onItemTapped(8),
            ),
            ListTile(
              leading: Icon(Icons.search, color: theme.colorScheme.primary),
              title: const Text('Consulta de Asistencia'),
              selected: _selectedIndex == 9,
              onTap: () => _onItemTapped(9),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                final bool? confirmed = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text(
                        '¿Estás seguro de que quieres cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return; // Check async gap
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}
