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
  String? email;
  @HiveField(3)
  String? specialty;

  Teacher({
    required this.id,
    required this.name,
    this.email,
    this.specialty,
  });

  factory Teacher.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Teacher(
      id: snapshot.key!,
      name: data['name'] ?? '',
      email: data['email'],
      specialty: data['specialty'],
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
      'email': email,
      'specialty': specialty,
    };
  }
}
