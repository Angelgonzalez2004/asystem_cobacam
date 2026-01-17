import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:asystem_cobacam/widgets/welcome_header.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PrefectHomeScreen extends StatefulWidget {
  final String? campus;
  final Function(String route)? onNavigate;

  const PrefectHomeScreen({super.key, this.campus, this.onNavigate});

  @override
  State<PrefectHomeScreen> createState() => _PrefectHomeScreenState();
}

class _PrefectHomeScreenState extends State<PrefectHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  String _userName = 'Prefecto/a';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/fullName')
          .get();
      if (mounted && snapshot.exists) {
        setState(() {
          _userName = snapshot.value.toString();
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted)
            UiHelpers.showSnackBar(
                context, 'Módulo de Prefectura Activo. ¡Buen día, $_userName!');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeHeader(
            userName: _userName,
            role: 'PREFECTURA',
            subtitle: widget.campus != null
                ? 'Supervisando Plantel: ${widget.campus}'
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STATUS CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.query_builder_rounded,
                          color: theme.colorScheme.primary, size: 40),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estado de Operación',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Registro de asistencia activo',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green.shade400),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Acciones Rápidas',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 4 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _buildQuickAction(
                      context,
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Pase de Lista',
                      color: Colors.green, // Acción principal
                      onTap: () => widget.onNavigate?.call('lista'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.manage_search_rounded,
                      label: 'Consultar Asist.',
                      color: Colors.blue,
                      onTap: () =>
                          widget.onNavigate?.call('consulta_asistencia'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.badge_rounded,
                      label: 'Credenciales',
                      color: Colors.orange,
                      onTap: () => widget.onNavigate?.call('credenciales'),
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: 'Reportar Incidencia',
                      color: Colors.redAccent,
                      onTap: () => widget.onNavigate?.call('incidencia'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Icon(Icons.feed_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Comunicados Recientes',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          StreamBuilder<List<AnnouncementModel>>(
            stream: _announcementService.getAnnouncementsStream(
                widget.campus, false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator()));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text("No hay avisos para este plantel.")));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  return AnnouncementCard(announcement: announcements[index]);
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
