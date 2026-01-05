import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class PrefectHomeScreen extends StatelessWidget {
  const PrefectHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel de Prefectura',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20.0,
                mainAxisSpacing: 20.0,
                childAspectRatio: 0.95,
                children: [
                  _buildFeatureCard(
                    context,
                    index: 0,
                    icon: Icons.report_problem_outlined,
                    title: 'Reportar Incidencia',
                    subtitle: 'Registrar incidentes.',
                    color: Colors.red.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 1,
                    icon: Icons.person_search_outlined,
                    title: 'Consultar Asistencia',
                    subtitle: 'Ver historial de alumno.',
                    color: Colors.blue.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 2,
                    icon: Icons.checklist_rtl_outlined,
                    title: 'Pase de Lista General',
                    subtitle: 'Asistencia en eventos.',
                    color: Colors.green.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 3,
                    icon: Icons.people_alt_outlined,
                    title: 'Gestión de Alumnos',
                    subtitle: 'Altas y bajas.',
                    color: Colors.purple.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 4,
                    icon: Icons.schedule_outlined,
                    title: 'Horarios de Grupo',
                    subtitle: 'Configurar entradas.',
                    color: Colors.orange.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 5,
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'Registro QR',
                    subtitle: 'Escanear entrada.',
                    color: Colors.teal.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 6,
                    icon: Icons.calendar_today_outlined,
                    title: 'Ciclos Escolares',
                    subtitle: 'Periodos A y B.',
                    color: Colors.indigo.shade500,
                    onTap: () {},
                  ),
                  _buildFeatureCard(
                    context,
                    index: 7,
                    icon: Icons.event_busy_outlined,
                    title: 'Días No Lectivos',
                    subtitle: 'Feriados y asuetos.',
                    color: Colors.pink.shade500,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required int index,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: OpenContainer(
        closedElevation: 0,
        closedColor: Colors.transparent,
        closedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: isDark ? theme.cardTheme.color : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: isDark
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: openContainer,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 32, color: color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        openBuilder: (BuildContext context, VoidCallback _) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(child: Text('Pantalla de $title (Placeholder)')),
          );
        },
        onClosed: (_) => {},
      ),
    );
  }
}
