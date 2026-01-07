import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_access_codes_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_announcements_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:asystem_cobacam/widgets/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ResponsiveDashboard extends StatefulWidget {
  final String role;
  final Widget body;

  const ResponsiveDashboard(
      {super.key, required this.role, required this.body});

  @override
  State<ResponsiveDashboard> createState() => _ResponsiveDashboardState();
}

class _ResponsiveDashboardState extends State<ResponsiveDashboard> {
  String _userName = 'Cargando...';
  String _userRole = '';
  String _userEmail = '';
  String? _userProfileUrl;
  String? _userCampus;
  DatabaseReference? _userRef;

  // Control de sub-pantallas internas
  Widget? _activeSubScreen;
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    _currentTitle = 'Dashboard ${widget.role}';
    _initUserData();
  }
  
  void _initUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email ?? '';
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _userRef!.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<Object?, Object?>.from(event.snapshot.value as Map);
            if (mounted) {
              setState(() {
                _userName = data['fullName']?.toString() ?? 'Usuario';
                _userRole = data['role']?.toString() ?? widget.role;
                _userProfileUrl = data['profileImageUrl']?.toString();
                _userCampus = data['campus']?.toString();
              });
            }
          } catch (e) {
            debugPrint("Error parsing user data in dashboard: $e");
          }
        }
      });
    }
  }

  void _onNavigate(String route) {
    setState(() {
      if (route == 'home') {
        _activeSubScreen = null;
        _currentTitle = 'Dashboard $_userRole';
      } else if (route == 'profile') {
        _activeSubScreen = const ProfileScreen(isEmbedded: true);
        _currentTitle = 'Mi Perfil';
      } else if (route == 'settings') {
        _activeSubScreen = const SettingsScreen(isEmbedded: true);
        _currentTitle = 'Ajustes';
      } else if (route == 'manage_announcements') {
        Navigator.push(context, SlideRightRoute(
          page: ManageAnnouncementsScreen(
            campus: _userCampus,
            isGeneralAdmin: _userRole.contains('General'),
          )
        ));
      } else if (route == 'manage_access_codes') {
        Navigator.push(context, SlideRightRoute(
          page: ManageAccessCodesScreen(
            campus: _userCampus,
            isGeneralAdmin: _userRole.contains('General'),
          )
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: isDark ? null : Colors.white,
        foregroundColor: isDark ? Colors.white : theme.colorScheme.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
      ),
      drawer: AppDrawer(
        role: _userRole,
        userName: _userName,
        userEmail: _userEmail,
        profileImageUrl: _userProfileUrl,
        onNavigate: _onNavigate,
      ),
      body: FadeInUp(
        key: ValueKey(_activeSubScreen == null ? 'home' : _activeSubScreen.runtimeType.toString()),
        child: _activeSubScreen ?? widget.body,
      ),
    );
  }
}