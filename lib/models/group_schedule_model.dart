import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import 'class_session_model.dart';

part 'group_schedule_model.g.dart';

@HiveType(typeId: 2)
class GroupSchedule {
  @HiveField(0)
  String id;
  @HiveField(1)
  String groupId;
  @HiveField(2)
  String schoolCycle;
  @HiveField(3)
  Map<String, List<ClassSession>> dailySchedules;

  GroupSchedule({
    required this.id,
    required this.groupId,
    required this.schoolCycle,
    required this.dailySchedules,
  });

  factory GroupSchedule.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final schedules = <String, List<ClassSession>>{};

    if (data['dailySchedules'] is Map) {
      final dailySchedulesData = data['dailySchedules'] as Map;
      dailySchedulesData.forEach((day, sessions) {
        if (sessions is List) {
          schedules[day] = sessions
              .map((sessionData) =>
                  ClassSession.fromMap(Map<String, dynamic>.from(sessionData)))
              .toList();
        }
      });
    }

    return GroupSchedule(
      id: snapshot.key!,
      groupId: snapshot.key!, // Corrected
      schoolCycle: data['schoolCycle'] ?? '',
      dailySchedules: schedules,
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'groupId': groupId,
      'schoolCycle': schoolCycle,
      'dailySchedules': dailySchedules.map(
        (day, sessions) =>
            MapEntry(day, sessions.map((s) => s.toMap()).toList()),
      ),
    };
  }
}
