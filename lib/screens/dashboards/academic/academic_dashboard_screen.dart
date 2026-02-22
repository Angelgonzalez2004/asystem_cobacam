import 'package:asystem_cobacam/screens/dashboards/academic/academic_home_screen.dart';
import 'package:asystem_cobacam/widgets/responsive_dashboard.dart';
import 'package:flutter/material.dart';

class AcademicDashboardScreen extends StatelessWidget {
  const AcademicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveDashboard(
      role: 'Académica',
      bodyBuilder: (onNavigate, _, __, ___) => AcademicHomeScreen(onNavigate: onNavigate),
    );
  }
}
