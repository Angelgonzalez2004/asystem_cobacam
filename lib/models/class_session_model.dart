import 'package:hive/hive.dart';

part 'class_session_model.g.dart';

@HiveType(typeId: 12) // New unique typeId
class ClassSession extends HiveObject {
  @HiveField(0)
  String startTime;
  @HiveField(1)
  String endTime;
  @HiveField(2)
  String? subjectId;
  @HiveField(3)
  String? teacherId;
  @HiveField(4)
  String subjectName; // Denormalized
  @HiveField(5)
  String? teacherName; // Denormalized
  @HiveField(6)
  String? groupName; // Denormalized, for teacher's view

  ClassSession({
    required this.startTime,
    required this.endTime,
    this.subjectId,
    this.teacherId,
    this.subjectName = 'Libre',
    this.teacherName,
    this.groupName,
  });

  factory ClassSession.fromMap(Map<String, dynamic> map) {
    return ClassSession(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      subjectId: map['subjectId'],
      teacherId: map['teacherId'],
      subjectName: map['subjectName'] ?? 'Libre',
      teacherName: map['teacherName'],
      groupName: map['groupName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'subjectName': subjectName,
      'teacherName': teacherName,
      'groupName': groupName,
    };
  }

  // Helper to check if the slot is a break
  bool get isBreak => subjectName.toLowerCase() == 'receso';

  // Helper to check if the slot is free
  bool get isFree => subjectId == null && !isBreak;
}
