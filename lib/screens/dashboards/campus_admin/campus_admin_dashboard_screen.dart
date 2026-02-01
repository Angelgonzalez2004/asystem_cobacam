import 'package:asystem_cobacam/screens/dashboards/campus_admin/campus_admin_home_screen.dart';
import 'package:asystem_cobacam/widgets/responsive_dashboard.dart';
import 'package:flutter/material.dart';

class CampusAdminDashboardScreen extends StatelessWidget {
  const CampusAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveDashboard(
      role: 'Admin por Plantel',
      bodyBuilder: (onNavigate) => CampusAdminHomeScreen(onNavigate: onNavigate),
    );
  }
}
