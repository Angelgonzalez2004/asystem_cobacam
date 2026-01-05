import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

// Importar los modelos
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/attendance_record_model.dart';

class HiveService {
  static const String _studentsBox = 'studentsBox';
  static const String _groupsBox = 'groupsBox';
  static const String _groupSchedulesBox = 'groupSchedulesBox';
  static const String _nonAttendanceDaysBox = 'nonAttendanceDaysBox';
  static const String _schoolCyclesBox = 'schoolCyclesBox';
  static const String _attendanceRecordsBox = 'attendanceRecordsBox'; // For offline queue

  Future<void> initHive() async {
    // Inicializar Hive en la ruta correcta del dispositivo
    if (!kIsWeb) { // Hive for Flutter doesn't require path_provider on web
      final appDocumentDirectory = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDirectory.path);
    } else {
      Hive.initFlutter(); // Initialize for web
    }

    // Registrar todos los adaptadores generados
    Hive.registerAdapter(StudentAdapter());
    Hive.registerAdapter(GroupAdapter());
    Hive.registerAdapter(GroupScheduleAdapter());
    Hive.registerAdapter(NonAttendanceDayAdapter());
    Hive.registerAdapter(SchoolCycleAdapter());
    Hive.registerAdapter(AttendanceRecordAdapter());

    // Abrir las cajas (boxes) que se van a utilizar
    await Hive.openBox<Student>(_studentsBox);
    await Hive.openBox<Group>(_groupsBox);
    await Hive.openBox<List<GroupSchedule>>(_groupSchedulesBox); // Group schedules might be list per group
    await Hive.openBox<NonAttendanceDay>(_nonAttendanceDaysBox);
    await Hive.openBox<SchoolCycle>(_schoolCyclesBox);
    await Hive.openBox<AttendanceRecord>(_attendanceRecordsBox); // For offline records
  }

  // Métodos de utilidad para acceder a las cajas
  Box<Student> get studentsBox => Hive.box<Student>(_studentsBox);
  Box<Group> get groupsBox => Hive.box<Group>(_groupsBox);
  Box<List<GroupSchedule>> get groupSchedulesBox => Hive.box<List<GroupSchedule>>(_groupSchedulesBox);
  Box<NonAttendanceDay> get nonAttendanceDaysBox => Hive.box<NonAttendanceDay>(_nonAttendanceDaysBox);
  Box<SchoolCycle> get schoolCyclesBox => Hive.box<SchoolCycle>(_schoolCyclesBox);
  Box<AttendanceRecord> get attendanceRecordsBox => Hive.box<AttendanceRecord>(_attendanceRecordsBox);

  // Limpiar todas las cajas (útil para cerrar sesión o resetear)
  Future<void> clearAllBoxes() async {
    await studentsBox.clear();
    await groupsBox.clear();
    await groupSchedulesBox.clear();
    await nonAttendanceDaysBox.clear();
    await schoolCyclesBox.clear();
    await attendanceRecordsBox.clear();
  }

  // Cerrar todas las cajas
  Future<void> closeAllBoxes() async {
    await Hive.close();
  }
}
