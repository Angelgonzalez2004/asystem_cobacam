import 'package:firebase_database/firebase_database.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final String type; // 'General' or 'Campus'
  final String? campus; // Required if type is 'Campus'
  final int timestamp;
  final String authorId;
  final String authorName;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    required this.type,
    this.campus,
    required this.timestamp,
    required this.authorId,
    required this.authorName,
  });

  factory AnnouncementModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return AnnouncementModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'General',
      campus: map['campus'],
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Administración',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'type': type,
      'campus': campus,
      'timestamp': timestamp,
      'authorId': authorId,
      'authorName': authorName,
    };
  }
}
