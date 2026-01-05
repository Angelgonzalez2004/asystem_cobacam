import 'package:asystem_cobacam/screens/dashboards/student/student_home_screen.dart';
import 'package:asystem_cobacam/widgets/responsive_dashboard.dart';
import 'package:flutter/material.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveDashboard(
      role: 'Alumno',
      body: StudentHomeScreen(),
    );
  }
}
