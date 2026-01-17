import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class GeneralAdminHomeScreen extends StatefulWidget {
  const GeneralAdminHomeScreen({super.key});

  @override
  State<GeneralAdminHomeScreen> createState() => _GeneralAdminHomeScreenState();
}

class _GeneralAdminHomeScreenState extends State<GeneralAdminHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String _userName = 'Admin General';

  // Real stats
  int _totalStudents = 0;
  int _totalAcademies = 0;
  int _totalPlants = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/fullName')
          .get();
      if (mounted && snapshot.exists) {
        setState(() => _userName = snapshot.value.toString());
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            UiHelpers.showSnackBar(context,
                'Portal de Administración General: ¡Hola, $_userName!');
          }
        });
      }
    }
    await _fetchRealStats();
  }

  Future<void> _fetchRealStats() async {
    try {
      final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
      if (usersSnapshot.exists) {
        int students = 0;
        int academies = 0;
        final data = usersSnapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final role = value['role']?.toString();
          if (role == 'Alumno') students++;
          if (role == 'Academica') academies++;
        });

        // Contar planteles únicos
        final plantelesSnapshot =
            await FirebaseDatabase.instance.ref('planteles').get();
        int plants =
            plantelesSnapshot.exists ? plantelesSnapshot.children.length : 0;

        if (mounted) {
          setState(() {
            _totalStudents = students;
            _totalAcademies = academies;
            _totalPlants = plants;
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
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
            role: 'ADMINISTRACIÓN GENERAL',
            subtitle: 'Supervisión de todo el Sistema COBACAM',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, 'Estado Real del Sistema'),
                const SizedBox(height: 16),
                _isLoadingStats
                    ? const Center(child: LinearProgressIndicator())
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 900
                            ? 4
                            : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildGlobalStat('Planteles', '$_totalPlants',
                              Icons.account_balance, Colors.indigo),
                          _buildGlobalStat('Académicas', '$_totalAcademies',
                              Icons.people_alt, Colors.blue),
                          _buildGlobalStat('Alumnos', '$_totalStudents',
                              Icons.school, Colors.green),
                          _buildGlobalStat('Actividad', 'Alta', Icons.insights,
                              Colors.orange),
                        ],
                      ),
                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Noticias del Sistema'),
                const SizedBox(height: 16),
                StreamBuilder<List<AnnouncementModel>>(
                  stream:
                      _announcementService.getAnnouncementsStream(null, true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final announcements = snapshot.data ?? [];
                    if (announcements.isEmpty) {
                      return const Text("No hay avisos globales.");
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

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGlobalStat(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
