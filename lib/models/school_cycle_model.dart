import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hive/hive.dart';

part 'school_cycle_model.g.dart';

@HiveType(typeId: 4) // Unique typeId
class SchoolCycle {
  @HiveField(0)
  String id; // e.g., "2025-A"
  @HiveField(1)
  String type; // 'A', 'B', or 'Propedéutico'
  @HiveField(2)
  DateTime startDate;
  @HiveField(3)
  DateTime endDate;

  SchoolCycle({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  factory SchoolCycle.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return SchoolCycle(
      id: snapshot.key!,
      type: data['type'] ?? '',
      startDate: DateTime.parse(data['startDate']),
      endDate: DateTime.parse(data['endDate']),
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'type': type,
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'endDate': DateFormat('yyyy-MM-dd').format(endDate),
    };
  }
}
