import 'dart:io';
import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AnnouncementService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('announcements');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create Announcement
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String type,
    String? campus,
    required String authorId,
    required String authorName,
    File? imageFile,
  }) async {
    String? imageUrl;
    // Simple ID generation without external package
    String id = '${DateTime.now().millisecondsSinceEpoch}_${authorId.substring(0, 5)}';

    if (imageFile != null) {
      final storageRef = _storage.ref().child('announcements/$id.jpg');
      await storageRef.putFile(imageFile);
      imageUrl = await storageRef.getDownloadURL();
    }

    final announcement = AnnouncementModel(
      id: id,
      title: title,
      message: message,
      imageUrl: imageUrl,
      type: type,
      campus: campus,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      authorId: authorId,
      authorName: authorName,
    );

    await _dbRef.child(id).set(announcement.toMap());
  }

  // Update Announcement
  Future<void> updateAnnouncement(AnnouncementModel announcement, File? newImage) async {
    String? imageUrl = announcement.imageUrl;

    if (newImage != null) {
      // Upload new image
      final storageRef = _storage.ref().child('announcements/${announcement.id}.jpg');
      await storageRef.putFile(newImage);
      imageUrl = await storageRef.getDownloadURL();
    }

    // Create updated map
    Map<String, dynamic> updates = announcement.toMap();
    updates['imageUrl'] = imageUrl; // Update URL if changed

    await _dbRef.child(announcement.id).update(updates);
  }

  // Delete Announcement
  Future<void> deleteAnnouncement(String id, String? imageUrl) async {
    await _dbRef.child(id).remove();
    if (imageUrl != null) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } catch (e) {
        // Image might not exist or already deleted
      }
    }
  }

  // Get Stream of Announcements (Filtered by User Role/Campus)
  Stream<List<AnnouncementModel>> getAnnouncementsStream(String? userCampus, bool isGeneralAdmin) {
    return _dbRef.orderByChild('timestamp').onValue.map((event) {
      final List<AnnouncementModel> announcements = [];
      if (event.snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      
      data.forEach((key, value) {
        final announcement = AnnouncementModel.fromMap(value, key);
        
        // Filter Logic
        bool show = false;

        if (isGeneralAdmin) {
          // General Admin sees EVERYTHING? Or just what they posted? 
          // Requirement: "General puede subir, modificar, eliminar o ver los avisos o lo que publique"
          // Assuming General Admin should see ALL announcements to moderate, or at least General ones.
          // Let's show everything for now for General Admin so they can manage content.
          show = true; 
        } else {
          // Normal User (Student, Prefect, Campus Admin)
          if (announcement.type == 'General') {
            show = true;
          } else if (announcement.type == 'Campus' && announcement.campus == userCampus) {
            show = true;
          }
        }

        if (show) {
          announcements.add(announcement);
        }
      });

      // Sort by timestamp descending (newest first)
      announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return announcements;
    });
  }
}
