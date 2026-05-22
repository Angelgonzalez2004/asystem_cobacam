import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_faq_screen.dart';
import 'package:asystem_cobacam/screens/common/general_user_profile_screen.dart';
import 'package:asystem_cobacam/screens/common/about_us_screen.dart'; // NEW IMPORT
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
  final Function(String route, {Object? arguments})? onNavigate;

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

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header Institucional Premium Personalizado
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
              ),
              image: DecorationImage(
                image: AssetImage('assets/images/logo2.jpg'),
                fit: BoxFit.cover,
                opacity: 0.05,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'drawer_profile_pic',
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: profileImageUrl != null
                                ? Image.network(
                                    profileImageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Icon(Icons.person,
                                        size: 28, color: theme.colorScheme.primary),
                                  )
                                : Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                        fontSize: 22, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFACC15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
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
                    onNavigate?.call('home'); // Reset to home index
                  },
                ),

                // --- PREFECTA SPECIFIC TOOLS ---
                if (role == 'Prefecta') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('HERRAMIENTAS',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.checklist_rounded,
                      title: 'Pase de Lista',
                      onTap: () => onNavigate?.call('lista')),
                  _buildDrawerItem(context,
                      icon: Icons.history_edu_rounded,
                      title: 'Consulta de Asistencias',
                      onTap: () => onNavigate?.call('consulta_asistencia')),
                  _buildDrawerItem(context,
                      icon: Icons.badge_outlined,
                      title: 'Generador de Credenciales',
                      onTap: () => onNavigate?.call('credenciales')),
                  _buildDrawerItem(context,
                      icon: Icons.warning_amber_rounded,
                      title: 'Reporte de Incidencias',
                      onTap: () => onNavigate?.call('incidencia')),
                  _buildDrawerItem(context,
                      icon: Icons.bar_chart_rounded,
                      title: 'Estadísticas y Métricas',
                      onTap: () => onNavigate?.call('stats')),

                  _buildDrawerItem(context,
                      icon: Icons.people_outline_rounded,
                      title: 'Alumnos',
                      onTap: () => onNavigate?.call('alumnos')),
                  
                  // ITEM TEMPORAL DE PRUEBAS
                  _buildDrawerItem(context,
                      icon: Icons.bolt_rounded,
                      title: 'Test de Asistencia (PRUEBAS)',
                      iconColor: Colors.orange,
                      onTap: () => onNavigate?.call('test_asistencia')),

                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('ADMINISTRACIÓN',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.calendar_month_outlined,
                      title: 'Gestión de Ciclos Escolares',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        onNavigate?.call('ciclos');
                      }),
                  _buildDrawerItem(context,
                      icon: Icons.event_busy_rounded, // Using the same icon as in NonAttendanceManagementScreen for consistency
                      title: 'Días No Lectivos',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        onNavigate?.call('no_lectivos');
                      }),
                  _buildDrawerItem(context,
                      icon: Icons.timer_outlined,
                      title: 'Horarios Generales (Entrada/Salida)',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        onNavigate?.call('prefecta_horarios_generales');
                      }),

                  const Divider(),
                   Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('VISUALIZACIÓN',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.grid_view_rounded,
                      title: 'Visor de Horario (Grupo)',
                      onTap: () => onNavigate?.call('visor_grupo')),
                  _buildDrawerItem(context,
                      icon: Icons.person_search_rounded,
                      title: 'Visor de Horario (Maestro)',
                      onTap: () => onNavigate?.call('visor_maestro')),
                  const Divider(),

                  _buildDrawerItem(context,
                      icon: Icons.help_outline_rounded,
                      title: 'Manual Operativo (FAQ)',
                      onTap: () => onNavigate?.call('faq')),
                  const Divider(),
                ],

                // --- ADMIN SPECIFIC TOOLS ---
                if (role.contains('Administrativo')) ...[
                  _buildDrawerItem(context,
                      icon: Icons.help_outline_rounded,
                      title: 'Manual Operativo (FAQ)',
                      onTap: () => onNavigate?.call('faq')),
                  _buildDrawerItem(
                    context,
                    icon: Icons.campaign_rounded,
                    title: 'Gestionar Avisos',
                    onTap: () => onNavigate?.call('manage_announcements'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.vpn_key_rounded,
                    title: 'Llaves de Registro',
                    onTap: () => onNavigate?.call('manage_access_codes'),
                  ),
                ],

                // --- GENERAL ADMIN SPECIFIC TOOLS ---
                if (role == 'Personal Administrativo General') ...[
                  const Divider(),
                   Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('CONTENIDO',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.integration_instructions_outlined,
                    title: 'Gestionar Manual',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageFaqScreen()));
                    },
                  ),
                ],



                // --- ACADÉMICA SPECIFIC TOOLS ---
                if (role == 'Academica') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('HORARIOS',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.grid_view_rounded,
                      title: 'Visor de Horario (Grupo)',
                      onTap: () => onNavigate?.call('visor_grupo')),
                  _buildDrawerItem(context,
                      icon: Icons.person_search_rounded,
                      title: 'Visor de Horario (Maestro)',
                      onTap: () => onNavigate?.call('visor_maestro')),
                  _buildDrawerItem(context,
                      icon: Icons.schedule_rounded,
                      title: 'Gestión de Horarios',
                      onTap: () => onNavigate?.call('manage_group_schedules')),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('PERSONAL',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.person_pin_rounded,
                      title: 'Gestionar Personal Docente',
                      onTap: () => onNavigate?.call('manage_teachers')),
                  _buildDrawerItem(context,
                      icon: Icons.help_outline_rounded,
                      title: 'Manual Operativo (FAQ)',
                      onTap: () => onNavigate?.call('faq')),
                  const Divider(),
                ],

                // --- TUTOR SPECIFIC TOOLS ---
                if (role == 'Tutor') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('SEGUIMIENTO',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.person_search_rounded,
                      title: 'Datos del Alumno',
                      onTap: () => onNavigate?.call('tutor_view_student_profile')),
                  _buildDrawerItem(context,
                      icon: Icons.checklist_rtl_rounded,
                      title: 'Asistencia del Alumno',
                      onTap: () => onNavigate?.call('tutor_view_attendance')),
                  _buildDrawerItem(context,
                      icon: Icons.badge_rounded,
                      title: 'Credencial del Alumno',
                      onTap: () => onNavigate?.call('tutor_view_credential')),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('INFORMACIÓN ESCOLAR',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.calendar_month_outlined,
                      title: 'Ciclos Escolares',
                      onTap: () => onNavigate?.call('ciclos_escolares')),
                  _buildDrawerItem(context,
                      icon: Icons.event_busy_rounded,
                      title: 'Días Inhábiles',
                      onTap: () => onNavigate?.call('dias_no_lectivos')),
                  const Divider(),
                  _buildDrawerItem(context,
                      icon: Icons.help_outline_rounded,
                      title: 'Manual Operativo (FAQ)',
                      onTap: () => onNavigate?.call('faq')),
                  const Divider(),
                ],

                // --- ALUMNO SPECIFIC TOOLS ---
                if (role == 'Alumno') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('INFORMACIÓN ESCOLAR',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey)),
                  ),
                  _buildDrawerItem(context,
                      icon: Icons.calendar_month_outlined,
                      title: 'Ciclos Escolares',
                      onTap: () => onNavigate?.call('ciclos_escolares')),
                  _buildDrawerItem(context,
                      icon: Icons.event_busy_rounded,
                      title: 'Días Inhábiles',
                      onTap: () => onNavigate?.call('dias_no_lectivos')),
                  _buildDrawerItem(context,
                      icon: Icons.schedule_rounded,
                      title: 'Horario General',
                      onTap: () => onNavigate?.call('horario_general')),
                  const Divider(),
                  _buildDrawerItem(context,
                      icon: Icons.badge_rounded,
                      title: 'Mi Credencial',
                      onTap: () => onNavigate?.call('credencial_alumno')),
                  _buildDrawerItem(context,
                      icon: Icons.help_outline_rounded,
                      title: 'Manual Operativo (FAQ)',
                      onTap: () => onNavigate?.call('faq')),
                  const Divider(),
                ],


                // Common Items
                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'Sobre Nosotros',
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    if (onNavigate != null) {
                      onNavigate!.call('about_us');
                    } else {
                      Navigator.push(context,
                          SlideRightRoute(page: const AboutUsScreen()));
                    }
                  },
                ),
                _buildDrawerItem( // Re-enable for all roles, including Alumno
                  context,
                  icon: Icons.person_outline_rounded,
                  title: 'Mi Perfil', // Retained title
                  onTap: () {
                    Navigator.pop(context); // Solo este pop
                    if (onNavigate != null) {
                      onNavigate!.call('profile');
                    } else {
                      Navigator.push(context,
                          SlideRightRoute(page: const GeneralUserProfileScreen()));
                    }
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Ajustes',
                  onTap: () {
                    Navigator.pop(context); // Solo este pop
                    if (onNavigate != null) {
                      onNavigate!.call('settings');
                    } else {
                      Navigator.push(context,
                          SlideRightRoute(page: const SettingsScreen()));
                    }
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
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text(
                        '¿Estás seguro de que deseas salir del sistema?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: Colors.white),
                        child: const Text('Salir'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
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
