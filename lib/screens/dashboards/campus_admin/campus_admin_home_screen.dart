import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';

class CampusAdminHomeScreen extends StatelessWidget {
  const CampusAdminHomeScreen({super.key});

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
              'Administración del Plantel',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildFeatureCard(
            context,
            index: 0,
            icon: Icons.manage_accounts_outlined,
            title: 'Gestionar Usuarios',
            subtitle: 'Aprobar, editar o eliminar usuarios del plantel.',
            color: Colors.blue.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 1,
            icon: Icons.bar_chart_rounded,
            title: 'Ver Estadísticas del Plantel',
            subtitle: 'Visualizar gráficas de asistencia y rendimiento.',
            color: Colors.purple.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 2,
            icon: Icons.summarize_outlined,
            title: 'Generar Reportes',
            subtitle: 'Crear y exportar reportes de asistencia o académicos.',
            color: Colors.teal.shade600,
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            index: 3,
            icon: Icons.pin_outlined,
            title: 'Administrar Códigos de Acceso',
            subtitle: 'Ver y regenerar los códigos de acceso para su plantel.',
            color: Colors.orange.shade600,
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
