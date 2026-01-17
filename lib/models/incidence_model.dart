import 'package:hive/hive.dart';

part 'incidence_model.g.dart';

@HiveType(typeId: 6) // ID único para Hive
class Incidence {
  @HiveField(0)
  String id;

  @HiveField(1)
  String studentId;

  @HiveField(2)
  String studentName;

  @HiveField(3)
  String group;

  @HiveField(4)
  String type; // Ej: Uniforme, Conducta, Retardo

  @HiveField(5)
  String description; // Detalle opcional

  @HiveField(6)
  DateTime date;

  @HiveField(7)
  String campusId;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  String schoolCycle;

  @HiveField(10)
  String status; // 'Activo', 'Solucionado'

  @HiveField(11)
  String? resolutionReason;

  @HiveField(12)
  String? resolutionDetails;

  @HiveField(13)
  DateTime? resolutionDate;

  Incidence({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.group,
    required this.type,
    this.description = '',
    required this.date,
    required this.campusId,
    this.isSynced = false,
    required this.schoolCycle,
    this.status = 'Activo',
    this.resolutionReason,
    this.resolutionDetails,
    this.resolutionDate,
  });

  Map<String, dynamic> toFirebaseMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'group': group,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'campusId': campusId,
      'schoolCycle': schoolCycle,
      'status': status,
      'resolutionReason': resolutionReason,
      'resolutionDetails': resolutionDetails,
      'resolutionDate': resolutionDate?.toIso8601String(),
    };
  }

  factory Incidence.fromFirebaseMap(String id, Map<String, dynamic> data) {
    return Incidence(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      group: data['group'] ?? '',
      type: data['type'] ?? 'General',
      description: data['description'] ?? '',
      date: DateTime.tryParse(data['date'] ?? '') ?? DateTime.now(),
      campusId: data['campusId'] ?? '',
      isSynced: true,
      schoolCycle: data['schoolCycle'] ?? 'S/C',
      status: data['status'] ?? 'Activo',
      resolutionReason: data['resolutionReason'],
      resolutionDetails: data['resolutionDetails'],
      resolutionDate: data['resolutionDate'] != null
          ? DateTime.tryParse(data['resolutionDate'])
          : null,
    );
  }
}
