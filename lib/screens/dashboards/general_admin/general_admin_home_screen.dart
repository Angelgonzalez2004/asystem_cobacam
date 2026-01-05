import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';

class GeneralAdminHomeScreen extends StatelessWidget {
  const GeneralAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Administración General',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildFeatureCard(
            context,
            index: 0,
            icon: Icons.query_stats_outlined,
            title: 'Ver Estadísticas Generales',
            subtitle: 'Visualizar datos y gráficas de todos los planteles.',
            color: Colors.indigo.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 1,
            icon: Icons.domain_add_outlined,
            title: 'Gestionar Planteles',
            subtitle: 'Añadir, editar o desactivar información de un plantel.',
            color: Colors.blue.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 2,
            icon: Icons.campaign_outlined,
            title: 'Anuncios Globales',
            subtitle: 'Enviar notificaciones a todos los usuarios del sistema.',
            color: Colors.orange.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 3,
            icon: Icons.shield_outlined,
            title: 'Supervisión del Sistema',
            subtitle: 'Monitorear la salud y el estado general del sistema.',
            color: Colors.red.shade600,
            onTap: () {},
          ),
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
        margin: const EdgeInsets.only(bottom: 16.0),
        color: isDark ? theme.cardTheme.color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
