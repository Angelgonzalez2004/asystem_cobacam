import 'dart:io';
import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';

class AnnouncementService {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('announcements');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Obtener stream de avisos filtrados
  Stream<List<AnnouncementModel>> getAnnouncementsStream(
      String? campusId, bool isGeneralAdmin,
      {bool isManagementMode = false}) {
    return _dbRef.onValue.map((event) {
      final List<AnnouncementModel> announcements = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        data.forEach((key, value) {
          final announcement = AnnouncementModel.fromMap(value, key);

          // LÓGICA DE FILTRADO ESTRICTA

          // 1. Si es Admin General, SOLO ve avisos Generales (no de planteles)
          if (isGeneralAdmin) {
            if (announcement.type == 'General') {
              announcements.add(announcement);
            }
          }
          // 2. Si es usuario de Plantel (Alumno o Admin)
          else {
            if (isManagementMode) {
              // MODO GESTIÓN (Admin Plantel): Solo ve lo de SU plantel para editar/borrar
              // No debe ver lo General aquí para no confundirse
              if (campusId != null && announcement.campus == campusId) {
                announcements.add(announcement);
              }
            } else {
              // MODO VISUALIZACIÓN (Home): Ve Generales + Su Plantel
              if (announcement.type == 'General' ||
                  (campusId != null && announcement.campus == campusId)) {
                announcements.add(announcement);
              }
            }
          }
        });
        // Ordenar por fecha reciente
        announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      return announcements;
    });
  }

  // PUBLICAR AVISO CON MÚLTIPLES IMÁGENES (FIX WEB)
  Future<void> publishAnnouncement({
    required String title,
    required String message,
    required String type,
    required String authorId,
    required String authorName,
    String? campus,
    List<XFile>? images,
  }) async {
    final List<String> imageUrls = [];

    // 1. Subir cada imagen a Storage
    if (images != null && images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        final String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference ref = _storage.ref().child('announcements/$fileName');

        if (kIsWeb) {
          // FIX PARA WEB: Usar putData en lugar de putFile
          final bytes = await images[i].readAsBytes();
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          // PARA MÓVIL: Usar putFile
          await ref.putFile(File(images[i].path));
        }

        final String url = await ref.getDownloadURL();
        imageUrls.add(url);
      }
    }

    // 2. Guardar en Realtime Database
    final String newId = _dbRef.push().key!;
    final announcement = AnnouncementModel(
      id: newId,
      title: title,
      message: message,
      type: type,
      authorId: authorId,
      authorName: authorName,
      campus: campus,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
    );

    await _dbRef.child(newId).set(announcement.toMap());
  }

  // Eliminar Aviso
  Future<void> deleteAnnouncement(AnnouncementModel announcement) async {
    // 1. Eliminar imágenes de Storage si existen
    if (announcement.imageUrls != null) {
      for (String url in announcement.imageUrls!) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint('Error deleting image from storage: $e');
        }
      }
    }
    // 2. Eliminar de DB
    await _dbRef.child(announcement.id).remove();
  }

  // Actualizar Aviso
  Future<void> updateAnnouncement(String id, Map<String, dynamic> data) async {
    await _dbRef.child(id).update(data);
  }
}
