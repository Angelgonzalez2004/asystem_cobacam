import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_announcements_screen.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
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
  int _selectedIndex = 0;
  late List<Widget> _screens;
  
  // User Data State
  String _userName = 'Cargando...';
  String _userRole = '';
  String _userEmail = '';
  String? _userProfileUrl;
  String? _userCampus;
  DatabaseReference? _userRef;

  @override
  void initState() {
    super.initState();
    // Initial basic screens
    _screens = [
      widget.body, // Index 0: Home
      const ProfileScreen(), // Index 1: Profile
      const SettingsScreen(), // Index 2: Settings
    ];
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
                
                _updateScreensBasedOnRole();
              });
            }
          } catch (e) {
            debugPrint("Error parsing user data in dashboard: $e");
          }
        }
      });
    } else {
        setState(() {
            _userRole = widget.role;
        });
    }
  }

  void _updateScreensBasedOnRole() {
    // Reset base screens
    final baseScreens = [
      widget.body,
      const ProfileScreen(),
      const SettingsScreen(),
    ];

    if (_userRole.contains('Administrativo')) {
      // Add Management Screen at Index 3
      baseScreens.add(
        ManageAnnouncementsScreen(
          campus: _userCampus,
          isGeneralAdmin: _userRole.contains('General'),
        )
      );
    }

    _screens = baseScreens;
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Cerrar Sesión',
      content: '¿Estás seguro de que quieres salir?',
      confirmText: 'Cerrar Sesión',
      isDestructive: true,
    );

    if (confirmed) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _onNavigate(String route) {
    if (route == 'manage_announcements') {
      setState(() {
        _selectedIndex = 3; // Index of ManageAnnouncementsScreen
      });
    } else {
        // Handle other routes if necessary
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Ensure index is valid
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile / Small Tablet Layout
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _getTitleForIndex(_selectedIndex),
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
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _screens[_selectedIndex],
              ),
            ),
          );
        } else {
          // Desktop / Large Tablet Layout
          return Scaffold(
            body: Row(
              children: [
                _buildNavigationRail(theme),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        color: isDark ? null : Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTitleForIndex(_selectedIndex),
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              child: IconButton(
                                icon: Icon(Icons.logout,
                                    color: theme.colorScheme.error),
                                onPressed: () => _handleLogout(context),
                                tooltip: 'Cerrar Sesión',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: FadeInUp(
                              key: ValueKey(_selectedIndex),
                              child: _screens[_selectedIndex]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  String _getTitleForIndex(int index) {
    if (index == 0) return 'Panel de Control';
    if (index == 1) return 'Mi Perfil';
    if (index == 2) return 'Configuración';
    if (index == 3) return 'Gestión de Avisos';
    return 'Dashboard';
  }

  Widget _buildNavigationRail(ThemeData theme) {
    final destinations = <NavigationRailDestination>[
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Inicio'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Perfil'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Configuración'),
        ),
    ];

    // Add Admin destinations dynamically for Desktop Rail
    if (_userRole.contains('Administrativo')) {
       destinations.add(const NavigationRailDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: Text('Avisos'),
       ));
    }

    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      extended: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      selectedLabelTextStyle: TextStyle(
          color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle:
          TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      destinations: destinations,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30.0),
        child: Image.asset('assets/images/logo1.png', height: 60),
      ),
    );
  }
}
