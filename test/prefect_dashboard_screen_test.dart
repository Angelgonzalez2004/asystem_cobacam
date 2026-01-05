import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/prefect_dashboard_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/attendance_screen.dart';

void main() {
  group('PrefectDashboardScreen', () {
    testWidgets('renders correctly and shows navigation options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrefectDashboardScreen(),
        ),
      );

      // Verify AppBar title
      expect(find.text('Dashboard Prefecta'), findsOneWidget);

      // Verify presence of navigation options
      expect(find.text('Gestión de Alumnos'), findsOneWidget);
      expect(find.text('Gestión de Horarios de Grupo'), findsOneWidget);
      expect(find.text('Registro de Asistencia'), findsOneWidget);

      // Verify icons are present
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('navigates to StudentManagementScreen when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrefectDashboardScreen(),
        ),
      );

      await tester.tap(find.text('Gestión de Alumnos'));
      await tester.pumpAndSettle(); // Wait for navigation to complete

      expect(find.byType(StudentManagementScreen), findsOneWidget);
    });

    testWidgets('navigates to GroupScheduleManagementScreen when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrefectDashboardScreen(),
        ),
      );

      await tester.tap(find.text('Gestión de Horarios de Grupo'));
      await tester.pumpAndSettle(); // Wait for navigation to complete

      expect(find.byType(GroupScheduleManagementScreen), findsOneWidget);
    });

    testWidgets('navigates to AttendanceScreen when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrefectDashboardScreen(),
        ),
      );

      await tester.tap(find.text('Registro de Asistencia'));
      await tester.pumpAndSettle(); // Wait for navigation to complete

      expect(find.byType(AttendanceScreen), findsOneWidget);
    });
  });
}
