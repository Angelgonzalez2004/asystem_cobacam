import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'group_model.g.dart';

@HiveType(typeId: 1) // Unique typeId
class Group {
  @HiveField(0)
  String key;
  @HiveField(1)
  String name;
  @HiveField(2)
  int semester;
  @HiveField(3)
  int studentCount;
  @HiveField(4)
  String schoolCycleId;

  Group(
      {required this.key,
      required this.name,
      required this.semester,
      required this.studentCount,
      required this.schoolCycleId});

  factory Group.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Group(
      key: snapshot.key!,
      name: data['name'] ?? '',
      semester: data['semester'] ?? 0,
      studentCount: data['studentCount'] ?? 0,
      schoolCycleId: data['schoolCycleId'] ?? '',
    );
  }
}
