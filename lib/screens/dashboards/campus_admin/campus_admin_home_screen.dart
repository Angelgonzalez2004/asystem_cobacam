import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CampusAdminHomeScreen extends StatefulWidget {
  const CampusAdminHomeScreen({super.key});

  @override
  State<CampusAdminHomeScreen> createState() => _CampusAdminHomeScreenState();
}

class _CampusAdminHomeScreenState extends State<CampusAdminHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String? _campus;

  @override
  void initState() {
    super.initState();
    _loadCampus();
  }

  Future<void> _loadCampus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/campus').get();
      if (mounted && snapshot.exists) {
        setState(() {
          _campus = snapshot.value as String?;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome / Title
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Administración del Plantel',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // Tools Grid (using GridView inside Column requires height or shrinkWrap)
          GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildFeatureCard(
                context,
                index: 0,
                icon: Icons.manage_accounts_outlined,
                title: 'Usuarios',
                subtitle: 'Gestionar personal y alumnos.',
                color: Colors.blue.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 1,
                icon: Icons.bar_chart_rounded,
                title: 'Estadísticas',
                subtitle: 'Rendimiento y asistencia.',
                color: Colors.purple.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 2,
                icon: Icons.summarize_outlined,
                title: 'Reportes',
                subtitle: 'Generar reportes PDF/Excel.',
                color: Colors.teal.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 3,
                icon: Icons.pin_outlined,
                title: 'Accesos',
                subtitle: 'Códigos de registro.',
                color: Colors.orange.shade600,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),
          
          // Announcements Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Avisos Publicados',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          StreamBuilder<List<AnnouncementModel>>(
            stream: _announcementService.getAnnouncementsStream(_campus, false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text("No hay avisos recientes.")),
                );
              }

              // Show only a few recent ones or all? Let's show all in a constrained list or just list them.
              // Since we are in a SingleChildScrollView, we can use ListView.builder with shrinkWrap.
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return AnnouncementCard(
                    announcement: snapshot.data![index],
                    isAdmin: false, // Manage in dedicated screen
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required int index,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? theme.cardTheme.color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
