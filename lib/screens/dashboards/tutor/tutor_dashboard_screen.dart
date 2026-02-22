import 'package:asystem_cobacam/screens/dashboards/tutor/tutor_home_screen.dart';
import 'package:asystem_cobacam/widgets/responsive_dashboard.dart';
import 'package:flutter/material.dart';

class TutorDashboardScreen extends StatelessWidget {
  const TutorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveDashboard(
      role: 'Tutor',
      bodyBuilder: (onNavigate, linkedStudent, userName, userCampus) => TutorHomeScreen(
        onNavigate: onNavigate,
        linkedStudent: linkedStudent,
        tutorName: userName,
        tutorCampus: userCampus,
      ),
    );
  }
}
