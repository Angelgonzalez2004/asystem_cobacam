import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile / Small Tablet Layout
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _selectedIndex == 0
                    ? 'Dashboard: ${widget.role}'
                    : (_selectedIndex == 1 ? 'Mi Perfil' : 'Configuración'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: false,
              backgroundColor: isDark ? null : Colors.white,
              foregroundColor:
                  isDark ? Colors.white : theme.colorScheme.onSurface,
              elevation: 0,
              iconTheme: IconThemeData(color: theme.colorScheme.primary),
            ),
            drawer: _buildDrawer(context),
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
                              _selectedIndex == 0
                                  ? 'Dashboard ${widget.role}'
                                  : (_selectedIndex == 1
                                      ? 'Mi Perfil'
                                      : 'Configuración'),
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

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                image: const DecorationImage(
                    image: AssetImage('assets/images/logo2.jpg'),
                    fit: BoxFit.cover,
                    opacity: 0.2)),
                                    accountName: const Text('Asystem Cobacam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    accountEmail: Text(widget.role, style: const TextStyle(fontSize: 14)),            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blueGrey),
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard_outlined,
                color: _selectedIndex == 0 ? theme.colorScheme.primary : null),
            title: Text('Inicio',
                style: TextStyle(
                    fontWeight: _selectedIndex == 0
                        ? FontWeight.bold
                        : FontWeight.normal)),
            selected: _selectedIndex == 0,
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(30))),
            onTap: () {
              _onItemTapped(0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.person_outline,
                color: _selectedIndex == 1 ? theme.colorScheme.primary : null),
            title: Text('Perfil',
                style: TextStyle(
                    fontWeight: _selectedIndex == 1
                        ? FontWeight.bold
                        : FontWeight.normal)),
            selected: _selectedIndex == 1,
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(30))),
            onTap: () {
              _onItemTapped(1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined,
                color: _selectedIndex == 2 ? theme.colorScheme.primary : null),
            title: Text('Configuración',
                style: TextStyle(
                    fontWeight: _selectedIndex == 2
                        ? FontWeight.bold
                        : FontWeight.normal)),
            selected: _selectedIndex == 2,
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(30))),
            onTap: () {
              _onItemTapped(2);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ListTile(
              leading:
                  Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text('Cerrar Sesión',
                  style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                await _handleLogout(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        _onItemTapped(index);
      },
      extended: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      selectedLabelTextStyle: TextStyle(
          color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle:
          TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
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
          label: Text('Configuración'),
        ),
      ],
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30.0),
        child: Image.asset('assets/images/logo1.png', height: 60),
      ),
    );
  }
}
