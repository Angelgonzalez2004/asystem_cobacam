import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isAdmin; // If true, show edit/delete options
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.isAdmin = false,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final date = DateTime.fromMillisecondsSinceEpoch(announcement.timestamp);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Author & Date)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    announcement.authorName.isNotEmpty ? announcement.authorName[0].toUpperCase() : 'A',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (announcement.type == 'General')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'GENERAL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
          ),

          // Image (if exists)
          if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty)
            GestureDetector(
              onTap: () {
                // TODO: Show full screen image
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(announcement.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsFeed extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final bool isAdmin;
  final Function(AnnouncementModel)? onDelete;
  final Function(AnnouncementModel)? onEdit;

  const NewsFeed({
    super.key,
    required this.announcements,
    this.isAdmin = false,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay avisos recientes',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: AnnouncementCard(
            announcement: announcements[index],
            isAdmin: isAdmin,
            onDelete: () => onDelete?.call(announcements[index]),
            onEdit: () => onEdit?.call(announcements[index]),
          ),
        );
      },
    );
  }
}
