import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:flutter/material.dart';

class PrefectHomeScreen extends StatefulWidget {
  final String? campus;
  const PrefectHomeScreen({super.key, this.campus});

  @override
  State<PrefectHomeScreen> createState() => _PrefectHomeScreenState();
}

class _PrefectHomeScreenState extends State<PrefectHomeScreen> {
  final AnnouncementService _announcementService = AnnouncementService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Avisos y Comunicados',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        
        // Feed
        Expanded(
          child: StreamBuilder<List<AnnouncementModel>>(
            stream: _announcementService.getAnnouncementsStream(widget.campus, false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final announcements = snapshot.data ?? [];
              
              return NewsFeed(
                announcements: announcements,
                isAdmin: false, // Prefect cannot edit/delete
              );
            },
          ),
        ),
      ],
    );
  }
}
