import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_groups_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_subjects_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/manage_teachers_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/academic/schedule_builder_screen.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AcademicHomeScreen extends StatefulWidget {
  const AcademicHomeScreen({super.key});

  @override
  State<AcademicHomeScreen> createState() => _AcademicHomeScreenState();
}

class _AcademicHomeScreenState extends State<AcademicHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  bool _isLoading = true;
  String _userName = 'Académica';
  String? _campus;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (mounted && snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _userName = data['fullName'] ?? 'Usuario';
          _campus = data['campus'];
          _isLoading = false;
        });

        // Mensaje de bienvenida
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) UiHelpers.showSnackBar(context, '¡Bienvenida, Académica $_userName!');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      child: Column(
        children: [
          WelcomeHeader(
            userName: _userName, 
            role: 'ACADÉMICA',
            subtitle: _campus != null ? 'Plantel: $_campus' : null,
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, 'Gestión Escolar'),
                const SizedBox(height: 16),
                
                // Cuadrícula de herramientas administrativas
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  childAspectRatio: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildAdminTile(context, 'Maestros', Icons.person_pin_rounded, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTeachersScreen()))),
                    _buildAdminTile(context, 'Materias', Icons.book_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageSubjectsScreen()))),
                    _buildAdminTile(context, 'Grupos', Icons.class_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageGroupsScreen()))),
                    _buildAdminTile(context, 'Horarios', Icons.grid_view_rounded, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleBuilderScreen()))),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Comunicados del Plantel'),
                const SizedBox(height: 16),
                
                StreamBuilder<List<AnnouncementModel>>(
                  stream: _announcementService.getAnnouncementsStream(_campus, false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final announcements = snapshot.data ?? [];
                    if (announcements.isEmpty) return const Text('No hay avisos hoy.');
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) => AnnouncementCard(announcement: announcements[index]),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAdminTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
