import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 10)
class Subject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;

  Subject({
    required this.id,
    required this.name,
  });

  factory Subject.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Subject(
      id: snapshot.key!,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
    };
  }
}
