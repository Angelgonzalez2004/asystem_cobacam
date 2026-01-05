import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

part 'non_attendance_day_model.g.dart';

@HiveType(typeId: 3) // Unique typeId
class NonAttendanceDay {
  @HiveField(0)
  String id; // Firebase key (e.g., YYYY-MM-DD format for easy lookup)
  @HiveField(1)
  String campusId;
  @HiveField(2)
  DateTime date;
  @HiveField(3)
  String? reason;

  NonAttendanceDay({
    required this.id,
    required this.campusId,
    required this.date,
    this.reason,
  });

  factory NonAttendanceDay.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return NonAttendanceDay(
      id: snapshot.key!,
      campusId: data['campusId'] ?? '',
      date: DateTime.parse(data['date']),
      reason: data['reason'],
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'campusId': campusId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'reason': reason,
    };
  }
}
