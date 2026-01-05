import 'package:flutter/material.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: [
          _buildDashboardCard(
            context,
            icon: Icons.grade,
            label: 'Mis Calificaciones',
            onTap: () {},
          ),
          _buildDashboardCard(
            context,
            icon: Icons.schedule,
            label: 'Mi Horario',
            onTap: () {},
          ),
          _buildDashboardCard(
            context,
            icon: Icons.badge,
            label: 'Mi Credencial',
            onTap: () {},
          ),
          _buildDashboardCard(
            context,
            icon: Icons.notifications,
            label: 'Notificaciones',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
