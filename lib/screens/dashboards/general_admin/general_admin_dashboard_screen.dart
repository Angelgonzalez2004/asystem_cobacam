import 'package:asystem_cobacam/screens/dashboards/general_admin/general_admin_home_screen.dart';
import 'package:asystem_cobacam/widgets/responsive_dashboard.dart';
import 'package:flutter/material.dart';

class GeneralAdminDashboardScreen extends StatelessWidget {
  const GeneralAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveDashboard(
      role: 'Admin General',
      bodyBuilder: (onNavigate) => GeneralAdminHomeScreen(onNavigate: onNavigate),
    );
  }
}
