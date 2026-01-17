class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final List<String>? imageUrls; // Cambiado de String? a List<String>?
  final String type; // 'General' or 'Campus'
  final String? campus;
  final int timestamp;
  final String authorId;
  final String authorName;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrls,
    required this.type,
    this.campus,
    required this.timestamp,
    required this.authorId,
    required this.authorName,
  });

  factory AnnouncementModel.fromMap(Map<dynamic, dynamic> map, String id) {
    // Manejar conversión de lista de Firebase
    List<String>? urls;
    if (map['imageUrls'] != null) {
      urls = List<String>.from(map['imageUrls']);
    } else if (map['imageUrl'] != null) {
      // Retrocompatibilidad con avisos viejos de una sola imagen
      urls = [map['imageUrl']];
    }

    return AnnouncementModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      imageUrls: urls,
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
      'imageUrls': imageUrls,
      'type': type,
      'campus': campus,
      'timestamp': timestamp,
      'authorId': authorId,
      'authorName': authorName,
    };
  }
}
