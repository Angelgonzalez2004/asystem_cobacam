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

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/fullName').get();
      if (mounted && snapshot.exists) {
        setState(() {
          _userName = snapshot.value.toString();
        });
        // Mensaje de bienvenida
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) UiHelpers.showSnackBar(context, 'Portal de Administración General: ¡Hola, $_userName!');
        });
      }
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
                _buildSectionHeader(theme, 'Estado Global del Sistema'),
                const SizedBox(height: 16),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildGlobalStat('Planteles', '18', Icons.account_balance, Colors.indigo),
                    _buildGlobalStat('Docentes', '450', Icons.people_alt, Colors.blue),
                    _buildGlobalStat('Alumnos', '12,400', Icons.school, Colors.green),
                    _buildGlobalStat('Avisos Hoy', '5', Icons.campaign, Colors.orange),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Noticias del Sistema'),
                const SizedBox(height: 16),

                StreamBuilder<List<AnnouncementModel>>(
                  stream: _announcementService.getAnnouncementsStream(null, true), 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final announcements = snapshot.data ?? [];
                    if (announcements.isEmpty) return const Text("No hay avisos globales.");

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
        Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGlobalStat(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}