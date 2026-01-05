import 'package:flutter/material.dart';

class CampusAdminHomeScreen extends StatelessWidget {
  const CampusAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.manage_accounts,
            title: 'Gestionar Usuarios',
            subtitle: 'Aprobar, editar o eliminar usuarios del plantel.',
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            icon: Icons.bar_chart,
            title: 'Ver Estadísticas del Plantel',
            subtitle: 'Visualizar gráficas de asistencia y rendimiento.',
            onTap: () {},
          ),
          _buildFeatureCard(
            context,
            icon: Icons.summarize_outlined,
            title: 'Generar Reportes',
            subtitle: 'Crear y exportar reportes de asistencia o académicos.',
            onTap: () {},
          ),
           _buildFeatureCard(
            context,
            icon: Icons.pin,
            title: 'Administrar Códigos de Acceso',
            subtitle: 'Ver y regenerar los códigos de acceso para su plantel.',
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
