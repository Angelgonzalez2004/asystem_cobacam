import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResponsiveDashboard extends StatefulWidget {
  final String role;
  final Widget body;

  const ResponsiveDashboard({super.key, required this.role, required this.body});

  @override
  State<ResponsiveDashboard> createState() => _ResponsiveDashboardState();
}

class _ResponsiveDashboardState extends State<ResponsiveDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      widget.body, // Index 0: Home
      const ProfileScreen(), // Index 1: Profile
      const SettingsScreen(), // Index 2: Settings
    ];
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmed = await _showLogoutConfirmationDialog();
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<bool?> _showLogoutConfirmationDialog() {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Cierre de Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No', style: TextStyle(color: colors.secondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Sí, Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile Layout
          return Scaffold(
            appBar: AppBar(
              title: Text('Dashboard: ${widget.role}'),
              backgroundColor: colors.primary,
            ),
            drawer: _buildDrawer(context),
            body: _screens[_selectedIndex],
          );
        } else {
          // Web/Tablet Layout
          return Scaffold(
            body: Row(
              children: [
                _buildNavigationRail(),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                       AppBar(
                         title: Text('Dashboard: ${widget.role}'),
                         backgroundColor: colors.primary,
                         automaticallyImplyLeading: false, // No back button
                         actions: [
                           IconButton(
                             icon: const Icon(Icons.logout),
                             onPressed: () => _handleLogout(context),
                             tooltip: 'Cerrar Sesión',
                           ),
                         ],
                       ),
                       Expanded(child: _screens[_selectedIndex]),
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

  Widget _buildDrawer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colors.primary),
            child: Text('Asystem Cobacam\n(${widget.role})', style: TextStyle(color: colors.onPrimary, fontSize: 24)),
          ),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text('Inicio'), onTap: () {
            _onItemTapped(0);
            Navigator.pop(context);
          }),
          ListTile(leading: const Icon(Icons.person), title: const Text('Perfil'), onTap: () {
             _onItemTapped(1);
            Navigator.pop(context);
          }),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Configuración'), onTap: () {
             _onItemTapped(2);
            Navigator.pop(context);
          }),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: colors.error),
            title: Text('Cerrar Sesión', style: TextStyle(color: colors.error)),
            onTap: () async {
              Navigator.pop(context);
              await _handleLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) async {
        if (index == 3) { // Updated logout button index
          await _handleLogout(context);
        } else {
          _onItemTapped(index);
        }
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).colorScheme.surface,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Inicio'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Perfil'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Config.'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.logout),
          label: Text('Salir'),
        ),
      ],
    );
  }
}
