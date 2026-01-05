import 'package:flutter/material.dart';

class GeneralAdminHomeScreen extends StatelessWidget {
  const GeneralAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.query_stats,
            title: 'Ver Estadísticas Generales',
            subtitle: 'Visualizar datos y gráficas de todos los planteles.',
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            icon: Icons.domain_add_outlined,
            title: 'Gestionar Planteles',
            subtitle: 'Añadir, editar o desactivar información de un plantel.',
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            icon: Icons.campaign,
            title: 'Anuncios Globales',
            subtitle: 'Enviar notificaciones a todos los usuarios del sistema.',
            onTap: () {},
          ),
           _buildFeatureCard(
            context,
            icon: Icons.shield_outlined,
            title: 'Supervisión del Sistema',
            subtitle: 'Monitorear la salud y el estado general del sistema.',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, size: 40, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),
    );
  }
}
