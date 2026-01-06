import 'package:asystem_cobacam/screens/common/profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/login_screen.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String role;
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  // Callback for Prefect tools or other specific navigations
  final Function(String route)? onNavigate;

  const AppDrawer({
    super.key,
    required this.role,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              image: const DecorationImage(
                image: AssetImage('assets/images/logo2.jpg'), // Fallback/Background pattern
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            accountName: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl!)
                  : null,
              child: profileImageUrl == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 24, color: theme.colorScheme.primary),
                    )
                  : null,
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.home_rounded,
                  title: 'Inicio',
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    // Already on home, essentially
                  },
                ),
                
                // --- PREFECT SPECIFIC TOOLS ---
                if (role == 'Prefecta') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('HERRAMIENTAS', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context, icon: Icons.qr_code_scanner_rounded, title: 'Scanner QR', onTap: () => onNavigate?.call('qr')),
                  _buildDrawerItem(context, icon: Icons.report_problem_rounded, title: 'Reportar Incidencia', onTap: () => onNavigate?.call('incidencia')),
                  _buildDrawerItem(context, icon: Icons.checklist_rounded, title: 'Pase de Lista', onTap: () => onNavigate?.call('lista')),
                  _buildDrawerItem(context, icon: Icons.people_outline_rounded, title: 'Alumnos', onTap: () => onNavigate?.call('alumnos')),
                  _buildDrawerItem(context, icon: Icons.schedule_rounded, title: 'Horarios', onTap: () => onNavigate?.call('horarios')),
                  _buildDrawerItem(context, icon: Icons.calendar_today_rounded, title: 'Ciclos Escolares', onTap: () => onNavigate?.call('ciclos')),
                  _buildDrawerItem(context, icon: Icons.event_busy_rounded, title: 'Días No Lectivos', onTap: () => onNavigate?.call('no_lectivos')),
                  const Divider(),
                ],

                // --- ADMIN SPECIFIC TOOLS ---
                if (role.contains('Administrativo')) ...[
                   _buildDrawerItem(
                    context,
                    icon: Icons.campaign_rounded,
                    title: 'Gestionar Avisos',
                    onTap: () => onNavigate?.call('manage_announcements'),
                  ),
                ],

                // Common Items
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: 'Mi Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SlideRightRoute(page: const ProfileScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Ajustes',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SlideRightRoute(page: const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDrawerItem(
              context,
              icon: Icons.logout_rounded,
              title: 'Cerrar Sesión',
              textColor: theme.colorScheme.error,
              iconColor: theme.colorScheme.error,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor ?? theme.iconTheme.color),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
