import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class PrefectHomeScreen extends StatelessWidget {
  const PrefectHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.report_problem_outlined,
            title: 'Reportar Incidencia',
            subtitle: 'Registrar un nuevo incidente o comportamiento.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => ReportIncidentScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.person_search,
            title: 'Consultar Asistencia de Alumnos',
            subtitle: 'Buscar y ver el historial de asistencia de un alumno.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceQueryScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.checklist,
            title: 'Pase de Lista General',
            subtitle: 'Realizar un pase de lista en áreas comunes o eventos.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => GeneralAttendanceScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.people,
            title: 'Gestión de Alumnos',
            subtitle: 'Altas, bajas y edición de información de estudiantes.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => StudentManagementScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.schedule,
            title: 'Gestión de Horarios de Grupo',
            subtitle: 'Configurar horarios de entrada y salida por grupo.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => GroupScheduleManagementScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.qr_code_scanner,
            title: 'Registro de Asistencia',
            subtitle: 'Escanear matrícula para entrada/salida de alumnos.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.calendar_today,
            title: 'Gestión de Ciclos Escolares',
            subtitle: 'Administrar los periodos académicos (A y B).',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SchoolCycleManagementScreen()));
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.event_busy,
            title: 'Gestión de Días No Lectivos',
            subtitle: 'Marcar días festivos, vacaciones u otros eventos sin asistencia.',
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => NonAttendanceManagementScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return OpenContainer(
      closedElevation: 2.0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      closedBuilder: (BuildContext context, VoidCallback openContainer) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: InkWell(
            onTap: openContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      openBuilder: (BuildContext context, VoidCallback _) {
        // This is a placeholder. In a real app, you would navigate to the correct screen.
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
          ),
          body: Center(
            child: Text('Screen for $title'),
          ),
        );
      },
      onClosed: (_) => {},
    );
  }
}
