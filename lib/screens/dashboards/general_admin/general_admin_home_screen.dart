import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:flutter/material.dart';

class GeneralAdminHomeScreen extends StatelessWidget {
  const GeneralAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AnnouncementService announcementService = AnnouncementService();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Administración General',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          
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
                icon: Icons.query_stats_outlined,
                title: 'Estadísticas Globales',
                subtitle: 'Datos de todos los planteles.',
                color: Colors.indigo.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 1,
                icon: Icons.domain_add_outlined,
                title: 'Planteles',
                subtitle: 'Gestionar infraestructura.',
                color: Colors.blue.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 2,
                icon: Icons.campaign_outlined,
                title: 'Anuncios Globales',
                subtitle: 'Notificar a todo el sistema.',
                color: Colors.orange.shade600,
                onTap: () {},
              ),
              _buildFeatureCard(
                context,
                index: 3,
                icon: Icons.shield_outlined,
                title: 'Sistema',
                subtitle: 'Monitoreo y salud.',
                color: Colors.red.shade600,
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
                Icon(Icons.feed_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Muro de Noticias Global',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          StreamBuilder<List<AnnouncementModel>>(
            stream: announcementService.getAnnouncementsStream(null, true), // isGeneralAdmin = true
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text("No hay avisos en el sistema.")),
                );
              }

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
