import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String? _campus;

  @override
  void initState() {
    super.initState();
    _loadCampus();
  }

  Future<void> _loadCampus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/campus').get();
      if (mounted && snapshot.exists) {
        setState(() {
          _campus = snapshot.value as String?;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Grid
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'Bienvenido, Estudiante',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20.0,
                mainAxisSpacing: 20.0,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    context,
                    index: 0,
                    icon: Icons.grade_outlined,
                    label: 'Mis Calificaciones',
                    color: Colors.blue.shade600,
                    onTap: () {},
                  ),
                  _buildDashboardCard(
                    context,
                    index: 1,
                    icon: Icons.schedule_outlined,
                    label: 'Mi Horario',
                    color: Colors.teal.shade500,
                    onTap: () {},
                  ),
                  _buildDashboardCard(
                    context,
                    index: 2,
                    icon: Icons.badge_outlined,
                    label: 'Mi Credencial',
                    color: Colors.orange.shade500,
                    onTap: () {},
                  ),
                  _buildDashboardCard(
                    context,
                    index: 3,
                    icon: Icons.notifications_none_outlined,
                    label: 'Notificaciones',
                    color: Colors.purple.shade500,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.feed_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Avisos Institucionales',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              StreamBuilder<List<AnnouncementModel>>(
                stream: _announcementService.getAnnouncementsStream(_campus, false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No hay avisos por el momento."),
                    ));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
      },
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
      child: Card(
        elevation: 0,
        color: isDark ? theme.cardTheme.color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
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
