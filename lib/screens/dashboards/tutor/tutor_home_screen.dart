import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:flutter/material.dart';

class TutorHomeScreen extends StatefulWidget {
  final Function(String route, {Object? arguments})? onNavigate;
  final Student? linkedStudent;
  final String? tutorName;
  final String? tutorCampus;
  
  const TutorHomeScreen({
    super.key,
    this.onNavigate,
    this.linkedStudent,
    this.tutorName,
    this.tutorCampus,
  });

  @override
  State<TutorHomeScreen> createState() => _TutorHomeScreenState();
}

class _TutorHomeScreenState extends State<TutorHomeScreen> {
  bool _showNoStudentMessage = false;

  @override
  void initState() {
    super.initState();
    // Show a help message if student is not found after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && widget.linkedStudent == null) {
        setState(() => _showNoStudentMessage = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AnnouncementService announcementService = AnnouncementService();

    if (widget.linkedStudent == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showNoStudentMessage) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  "Buscando alumno vinculado...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                const Icon(Icons.person_off_rounded, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  "No se encontró un alumno vinculado",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Asegúrate de haber ingresado la matrícula correcta al registrarte o contacta a la institución.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate?.call('profile'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text("Verificar mi perfil"),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeHeader(
            userName: widget.tutorName ?? 'Tutor',
            role: 'TUTOR',
            subtitle: 'Visualizando datos de: ${widget.linkedStudent!.fullName}',
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acciones Rápidas',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                     _buildDashboardCard(
                      context,
                      index: 0,
                      icon: Icons.person_search_rounded,
                      label: 'Datos del Alumno',
                      color: Colors.purple.shade400,
                      onTap: () => widget.onNavigate?.call('tutor_view_student_profile', arguments: widget.linkedStudent),
                    ),
                    _buildDashboardCard(
                      context,
                      index: 1,
                      icon: Icons.checklist_rtl_rounded,
                      label: 'Asistencia del Alumno',
                      color: Colors.cyan.shade500,
                      onTap: () => widget.onNavigate?.call('tutor_view_attendance', arguments: widget.linkedStudent),
                    ),
                    _buildDashboardCard(
                      context,
                      index: 2,
                      icon: Icons.badge_rounded,
                      label: 'Credencial del Alumno',
                      color: Colors.orange.shade500,
                      onTap: () => widget.onNavigate?.call('tutor_view_credential', arguments: widget.linkedStudent),
                    ),
                    _buildDashboardCard(
                      context,
                      index: 3,
                      icon: Icons.calendar_month_outlined,
                      label: 'Ciclos Escolares',
                      color: Colors.blue.shade500,
                      onTap: () => widget.onNavigate?.call('ciclos_escolares'),
                    ),
                     _buildDashboardCard(
                      context,
                      index: 4,
                      icon: Icons.event_busy_rounded,
                      label: 'Días Inhábiles',
                      color: Colors.red.shade400,
                      onTap: () => widget.onNavigate?.call('dias_no_lectivos'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(Icons.feed_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Muro Informativo',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          StreamBuilder<List<AnnouncementModel>>(
            stream: announcementService.getAnnouncementsStream(widget.tutorCampus, false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No hay avisos recientes de la dirección."),
                ));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return AnnouncementCard(announcement: snapshot.data![index]);
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required int index,
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? theme.cardTheme.color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

