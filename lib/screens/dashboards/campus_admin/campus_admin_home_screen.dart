import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CampusAdminHomeScreen extends StatefulWidget {
  const CampusAdminHomeScreen({super.key});

  @override
  State<CampusAdminHomeScreen> createState() => _CampusAdminHomeScreenState();
}

class _CampusAdminHomeScreenState extends State<CampusAdminHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String? _campus;
  String _userName = 'Administrador';

  // Real stats
  int _studentCount = 0;
  int _teacherCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (mounted && snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _campus = data['campus'];
          _userName = data['fullName'] ?? 'Administrador';
        });

        // Mensaje de bienvenida
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            UiHelpers.showSnackBar(
                context, '¡Bienvenido(a), Admin $_userName!');
          }
        });

        await _fetchRealStats();
      }
    }
  }

  Future<void> _fetchRealStats() async {
    if (_campus == null) return;
    try {
      // Filtrar usuarios que pertenecen a este plantel y contar roles
      final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
      if (usersSnapshot.exists) {
        int students = 0;
        int teachers = 0;
        final data = usersSnapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value['campus'] == _campus) {
            final role = value['role']?.toString();
            if (role == 'Alumno') students++;
            if (role == 'Academica') teachers++;
          }
        });

        if (mounted) {
          setState(() {
            _studentCount = students;
            _teacherCount = teachers;
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching campus stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          WelcomeHeader(
            userName: _userName,
            role: 'ADMIN PLANTEL',
            subtitle: _campus != null ? 'Sede: $_campus' : 'Cargando sede...',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado del Plantel',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _isLoadingStats
                    ? const LinearProgressIndicator()
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 600 ? 2 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.5,
                        children: [
                          _buildStatCard('Alumnos Registrados',
                              '$_studentCount', Icons.people, Colors.blue),
                          _buildStatCard('Académicas Activas', '$_teacherCount',
                              Icons.school, Colors.teal),
                        ],
                      ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(Icons.campaign, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Avisos de tu Plantel',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<AnnouncementModel>>(
                  stream: _announcementService.getAnnouncementsStream(
                      _campus, false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final announcements = snapshot.data ?? [];
                    if (announcements.isEmpty) {
                      return const Text(
                          "No hay avisos recientes publicados por ti.");
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) =>
                          AnnouncementCard(announcement: announcements[index]),
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

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}
