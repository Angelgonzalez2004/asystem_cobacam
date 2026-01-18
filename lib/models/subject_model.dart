import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 10)
class Subject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  int semester;
  @HiveField(3)
  String code;

  Subject({
    required this.id,
    required this.name,
    required this.semester,
    required this.code,
  });

  factory Subject.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Subject(
      id: snapshot.key!,
      name: data['name'] ?? '',
      semester: data['semester'] ?? 0,
      code: data['code'] ?? '',
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
      'semester': semester,
      'code': code,
    };
  }
}
