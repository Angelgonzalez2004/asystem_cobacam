import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 10) // New unique typeId
class Subject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  int semester;

  Subject({
    required this.id,
    required this.name,
    required this.semester,
  });

  factory Subject.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Subject(
      id: snapshot.key!,
      name: data['name'] ?? '',
      semester: data['semester'] ?? 0,
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
      'semester': semester,
    };
  }
}
