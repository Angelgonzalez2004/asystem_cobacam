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
import 'package:asystem_cobacam/models/teacher_model.dart';

class HiveService {
  static const String _teachersBox = 'teachersBox';
  static const String _studentsBox = 'studentsBox';
  static const String _groupsBox = 'groupsBox';
  static const String _groupSchedulesBox = 'groupSchedulesBox';
  static const String _nonAttendanceDaysBox = 'nonAttendanceDaysBox';
  static const String _schoolCyclesBox = 'schoolCyclesBox';
  static const String _attendanceRecordsBox =
      'attendanceRecordsBox'; // For offline queue

  Future<void> initHive() async {
    // Inicializar Hive en la ruta correcta del dispositivo
    if (!kIsWeb) {
      // Hive for Flutter doesn't require path_provider on web
      final appDocumentDirectory = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDirectory.path);
    } else {
      Hive.initFlutter(); // Initialize for web
    }

    // Registrar todos los adaptadores generados
    Hive.registerAdapter(TeacherAdapter());
    Hive.registerAdapter(StudentAdapter());
    Hive.registerAdapter(GroupAdapter());
    Hive.registerAdapter(GroupScheduleAdapter());
    Hive.registerAdapter(NonAttendanceDayAdapter());
    Hive.registerAdapter(SchoolCycleAdapter());
    Hive.registerAdapter(AttendanceRecordAdapter());

    // Abrir las cajas (boxes) que se van a utilizar
    debugPrint('Hive: Abriendo StudentsBox...');
    await Hive.openBox<Student>(_studentsBox);
    debugPrint('Hive: StudentsBox abierta.');

    debugPrint('Hive: Abriendo GroupsBox...');
    await Hive.openBox<Group>(_groupsBox);
    debugPrint('Hive: GroupsBox abierta.');

    debugPrint('Hive: Abriendo GroupSchedulesBox...');
    await Hive.openBox<GroupSchedule>(_groupSchedulesBox);
    debugPrint('Hive: GroupSchedulesBox abierta.');

    debugPrint('Hive: Abriendo NonAttendanceDaysBox...');
    await Hive.openBox<NonAttendanceDay>(_nonAttendanceDaysBox);
    debugPrint('Hive: NonAttendanceDaysBox abierta.');

    debugPrint('Hive: Abriendo SchoolCyclesBox...');
    await Hive.openBox<SchoolCycle>(_schoolCyclesBox);
    debugPrint('Hive: SchoolCyclesBox abierta.');

    debugPrint('Hive: Abriendo AttendanceRecordsBox...');
    await Hive.openBox<AttendanceRecord>(_attendanceRecordsBox);
    debugPrint('Hive: AttendanceRecordsBox abierta.');

    debugPrint('Hive: Abriendo TeachersBox...');
    await Hive.openBox<Teacher>(_teachersBox);
    debugPrint('Hive: TeachersBox abierta.');
  }

  // Métodos de utilidad para acceder a las cajas
  Box<Student> get studentsBox => Hive.box<Student>(_studentsBox);
  Box<Group> get groupsBox => Hive.box<Group>(_groupsBox);
  Box<GroupSchedule> get groupSchedulesBox =>
      Hive.box<GroupSchedule>(_groupSchedulesBox);
  Box<NonAttendanceDay> get nonAttendanceDaysBox =>
      Hive.box<NonAttendanceDay>(_nonAttendanceDaysBox);
  Box<SchoolCycle> get schoolCyclesBox =>
      Hive.box<SchoolCycle>(_schoolCyclesBox);
  Box<AttendanceRecord> get attendanceRecordsBox =>
      Hive.box<AttendanceRecord>(_attendanceRecordsBox);
  Box<Teacher> get teachersBox => Hive.box<Teacher>(_teachersBox);

  // Limpiar todas las cajas (útil para cerrar sesión o resetear)
  Future<void> clearAllBoxes() async {
    await studentsBox.clear();
    await groupsBox.clear();
    await groupSchedulesBox.clear();
    await nonAttendanceDaysBox.clear();
    await schoolCyclesBox.clear();
    await attendanceRecordsBox.clear();
    await teachersBox.clear();
  }

  // Cerrar todas las cajas
  Future<void> closeAllBoxes() async {
    await Hive.close();
  }
}
