import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'group_schedule_model.g.dart';

@HiveType(typeId: 2) // Unique typeId
class GroupSchedule {
  @HiveField(0)
  String id; // Firebase key
  @HiveField(1)
  String groupId;
  @HiveField(2)
  String schoolCycle;
  @HiveField(3)
  String dayOfWeek;
  @HiveField(4)
  String entryTime;
  @HiveField(5)
  String exitTime;

  GroupSchedule({
    required this.id,
    required this.groupId,
    required this.schoolCycle,
    required this.dayOfWeek,
    required this.entryTime,
    required this.exitTime,
  });

  // Factory constructor for creating a GroupSchedule from a Firebase DataSnapshot
  factory GroupSchedule.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return GroupSchedule(
      id: snapshot.key!,
      groupId: data['groupId'] ?? '',
      schoolCycle: data['schoolCycle'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? '',
      entryTime: data['entryTime'] ?? '',
      exitTime: data['exitTime'] ?? '',
    );
  }

  // Method for converting a GroupSchedule object to a Map for Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'groupId': groupId,
      'schoolCycle': schoolCycle,
      'dayOfWeek': dayOfWeek,
      'entryTime': entryTime,
      'exitTime': exitTime,
    };
  }
}
