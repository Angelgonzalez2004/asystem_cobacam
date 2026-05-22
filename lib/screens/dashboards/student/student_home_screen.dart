import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class StudentHomeScreen extends StatefulWidget {
  final Function(String route)? onNavigate;
  const StudentHomeScreen({super.key, this.onNavigate});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String? _campus;
  String _userName = 'Estudiante';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (mounted && snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _campus = data['campus'];
          _userName = data['fullName'] ?? 'Estudiante';
        });

        // Mensaje de bienvenida sutil (Toast)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            UiHelpers.showSnackBar(
                context, '¡Bienvenido de vuelta, $_userName!');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WelcomeHeader(
                userName: _userName,
                role: 'ALUMNO',
                subtitle: _campus != null ? 'Plantel: $_campus' : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acciones Rápidas',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildDashboardCard(
                          context,
                          index: 0,
                          icon: Icons.badge_rounded,
                          label: 'Mi Credencial',
                          color: Colors.orange.shade500,
                          onTap: () => widget.onNavigate?.call('credencial_alumno'),
                        ),
                        _buildDashboardCard(
                          context,
                          index: 1,
                          icon: Icons.calendar_month_outlined,
                          label: 'Ciclos Escolares',
                          color: Colors.blue.shade500,
                          onTap: () => widget.onNavigate?.call('ciclos_escolares'),
                        ),
                        _buildDashboardCard(
                          context,
                          index: 2,
                          icon: Icons.event_busy_rounded,
                          label: 'Días Inhábiles',
                          color: Colors.red.shade400,
                          onTap: () => widget.onNavigate?.call('dias_no_lectivos'),
                        ),
                        _buildDashboardCard(
                          context,
                          index: 3,
                          icon: Icons.person_rounded,
                          label: 'Mi Perfil',
                          color: Colors.green.shade500,
                          onTap: () => widget.onNavigate?.call('profile'),
                        ),
                        _buildDashboardCard(
                          context,
                          index: 4,
                          icon: Icons.schedule_rounded,
                          label: 'Horario General',
                          color: Colors.indigo.shade500,
                          onTap: () => widget.onNavigate?.call('horario_general'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(Icons.feed_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Muro Informativo',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              StreamBuilder<List<AnnouncementModel>>(
                stream:
                    _announcementService.getAnnouncementsStream(_campus, false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator()));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No hay avisos recientes de la dirección."),
                    ));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return AnnouncementCard(
                          announcement: snapshot.data![index]);
                    },
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required int index,
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? theme.cardTheme.color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
