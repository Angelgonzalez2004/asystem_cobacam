import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isAdmin; 
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Autor y Fecha)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'OFICIAL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
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

          // Galería de Imágenes (Si existen)
          if (announcement.imageUrls != null && announcement.imageUrls!.isNotEmpty)
            _buildGallery(announcement.imageUrls!),

          // Contenido
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
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(List<String> urls) {
    if (urls.length == 1) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(image: NetworkImage(urls[0]), fit: BoxFit.cover),
        ),
      );
    }

    // Cuadrícula para múltiples imágenes (estilo Facebook/Twitter)
    return SizedBox(
      height: 250,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: urls.length >= 2 ? 2 : 1,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: urls.length > 4 ? 4 : urls.length,
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(urls[index], fit: BoxFit.cover),
              if (index == 3 && urls.length > 4)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${urls.length - 3}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          );
        },
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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