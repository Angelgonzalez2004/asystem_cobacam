import 'package:hive/hive.dart';

part 'attendance_record_model.g.dart';

@HiveType(typeId: 5) // Unique typeId for AttendanceRecord
class AttendanceRecord {
  @HiveField(0)
  String studentId;
  
  @HiveField(1)
  String studentFullName;
  
  @HiveField(2)
  String group;
  
  @HiveField(3)
  String date; // Format 'yyyy-MM-dd'
  
  @HiveField(4)
  String? entryTime; // Format 'HH:mm' (Puede ser nulo si no ha checado entrada)
  
  @HiveField(5)
  String? exitTime; // Format 'HH:mm' (Puede ser nulo si no ha salido)
  
  @HiveField(6)
  String? status; // e.g., 'presente', 'tarde', 'ausente', 'presente_masivo'
  
  @HiveField(7)
  String? reasonTardy;
  
  @HiveField(8)
  String? reasonEarlyExit;

  // For offline queue management
  @HiveField(9)
  bool isSynced; 

  @HiveField(10) // New field
  String campusId;

  @HiveField(11) // New field
  String schoolCycle;

  AttendanceRecord({
    required this.studentId,
    required this.studentFullName,
    required this.group,
    required this.date,
    this.entryTime,
    this.exitTime,
    this.status,
    this.reasonTardy,
    this.reasonEarlyExit,
    this.isSynced = false,
    required this.campusId, // New required field
    required this.schoolCycle, // New required field
  });

  // Getter for unique key for Hive, combining studentId and date
  // This ensures uniqueness per student per day
  String get uniqueKey => '${studentId}_$date';

  // Convert to Firebase map
  Map<String, dynamic> toFirebaseMap() {
    // CORRECCIÓN 1: Definir explícitamente el tipo del mapa como <String, dynamic>
    final Map<String, dynamic> map = {
      'studentFullName': studentFullName,
      'group': group,
      'date': date,
      'campusId': campusId, 
      'schoolCycle': schoolCycle,
      // 'isSynced': isSynced, // No se guarda en Firebase, es control local
    };
    
    // CORRECCIÓN 2: Usar el operador '!' para forzar el valor ya que validamos que no es null en el if
    if (entryTime != null) map['entryTime'] = entryTime!;
    if (exitTime != null) map['exitTime'] = exitTime!;
    if (status != null) map['status'] = status!;
    if (reasonTardy != null) map['reasonTardy'] = reasonTardy!;
    if (reasonEarlyExit != null) map['reasonEarlyExit'] = reasonEarlyExit!;
    
    return map;
  }

  // Factory from Firebase map for loading records
  factory AttendanceRecord.fromFirebaseMap(
    String studentId, 
    String date, 
    Map<String, dynamic> data, {
    required String campusId, 
    required String schoolCycle, 
  }) {
    // Extracción segura de datos: Si el campo no existe o es null, la variable será null
    final String? entryTimeValue = data['entryTime'] as String?;
    final String? exitTimeValue = data['exitTime'] as String?;
    final String? statusValue = data['status'] as String?;
    final String? reasonTardyValue = data['reasonTardy'] as String?;
    final String? reasonEarlyExitValue = data['reasonEarlyExit'] as String?;

    return AttendanceRecord(
      studentId: studentId,
      // Usamos '??' para proveer un valor por defecto si el nombre o grupo vienen nulos de la BD
      studentFullName: (data['studentFullName'] as String?) ?? 'NOMBRE_DESCONOCIDO',
      group: (data['group'] as String?) ?? 'GRUPO_DESCONOCIDO',
      date: date,
      entryTime: entryTimeValue,     // Puede ser null y es correcto
      exitTime: exitTimeValue,       // Puede ser null y es correcto
      status: statusValue,           // Puede ser null y es correcto
      reasonTardy: reasonTardyValue, // Puede ser null y es correcto
      reasonEarlyExit: reasonEarlyExitValue, // Puede ser null y es correcto
      isSynced: true, // Si viene de Firebase, significa que ya está sincronizado
      campusId: campusId,
      schoolCycle: schoolCycle,
    );
  }
}