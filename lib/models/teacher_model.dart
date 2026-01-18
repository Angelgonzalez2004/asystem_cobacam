import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'teacher_model.g.dart';

@HiveType(typeId: 11)
class Teacher {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  List<String> subjects;

  Teacher({
    required this.id,
    required this.name,
    this.subjects = const [],
  });

  factory Teacher.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final subjectsFromDb = data['subjects'];
    List<String> subjectsList = [];
    if (subjectsFromDb is List) {
      subjectsList = List<String>.from(subjectsFromDb.map((item) => item.toString()));
    } else if (subjectsFromDb is Map) {
      // Handle cases where Firebase might store a list as a map with integer keys
      subjectsList = List<String>.from(subjectsFromDb.values.map((item) => item.toString()));
    }
    
    return Teacher(
      id: snapshot.key!,
      name: data['name'] ?? '',
      subjects: subjectsList,
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
      'subjects': subjects,
    };
  }
}
