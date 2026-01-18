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
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/subject_model.dart';
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
  static const String _subjectsBox = 'subjectsBox';
  static const String _incidencesBox = 'incidencesBox';
  static const String _classSessionsBox =
      'classSessionsBox'; // Although HiveObject, might not need a top-level box

  Future<void> initHive() async {
    // Inicializar Hive en la ruta correcta del dispositivo
    if (!kIsWeb) {
      final appDocumentDirectory = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDirectory.path);
    } else {
      Hive.initFlutter(); // Initialize for web
    }
    debugPrint("✅ Hive.init complete.");

    // --- REGISTRO DE ADAPTADORES (DE SIMPLE A COMPLEJO) ---
    debugPrint("➡️ Registrando StudentAdapter...");
    Hive.registerAdapter(StudentAdapter());
    debugPrint("➡️ Registrando TeacherAdapter...");
    Hive.registerAdapter(TeacherAdapter());
    debugPrint("➡️ Registrando SubjectAdapter...");
    Hive.registerAdapter(SubjectAdapter());
    debugPrint("➡️ Registrando SchoolCycleAdapter...");
    Hive.registerAdapter(SchoolCycleAdapter());
    debugPrint("➡️ Registrando NonAttendanceDayAdapter...");
    Hive.registerAdapter(NonAttendanceDayAdapter());
    debugPrint("➡️ Registrando IncidenceAdapter...");
    Hive.registerAdapter(IncidenceAdapter());
    debugPrint("➡️ Registrando GroupAdapter...");
    Hive.registerAdapter(GroupAdapter());
    debugPrint("➡️ Registrando AttendanceRecordAdapter...");
    Hive.registerAdapter(AttendanceRecordAdapter());
    debugPrint("➡️ Registrando ClassSessionAdapter (dependencia)...");
    Hive.registerAdapter(ClassSessionAdapter());
    debugPrint("➡️ Registrando GroupScheduleAdapter (complejo)...");
    Hive.registerAdapter(GroupScheduleAdapter());
    debugPrint("✅ Todos los adaptadores registrados.");

    // --- APERTURA DE CAJAS (DE SIMPLE A COMPLEJO) ---
    debugPrint("➡️ Abriendo SchoolCyclesBox...");
    await Hive.openBox<SchoolCycle>(_schoolCyclesBox);
    debugPrint("✅ SchoolCyclesBox abierta.");

    debugPrint("➡️ Abriendo SubjectsBox...");
    await Hive.openBox<Subject>(_subjectsBox);
    debugPrint("✅ SubjectsBox abierta.");

    debugPrint("➡️ Abriendo TeachersBox...");
    await Hive.openBox<Teacher>(_teachersBox);
    debugPrint("✅ TeachersBox abierta.");

    debugPrint("➡️ Abriendo StudentsBox...");
    await Hive.openBox<Student>(_studentsBox);
    debugPrint("✅ StudentsBox abierta.");

    debugPrint("➡️ Abriendo NonAttendanceDaysBox...");
    await Hive.openBox<NonAttendanceDay>(_nonAttendanceDaysBox);
    debugPrint("✅ NonAttendanceDaysBox abierta.");

    debugPrint("➡️ Abriendo IncidencesBox...");
    await Hive.openBox<Incidence>(_incidencesBox);
    debugPrint("✅ IncidencesBox abierta.");

    debugPrint("➡️ Abriendo GroupsBox...");
    await Hive.openBox<Group>(_groupsBox);
    debugPrint("✅ GroupsBox abierta.");

    debugPrint("➡️ Abriendo AttendanceRecordsBox...");
    await Hive.openBox<AttendanceRecord>(_attendanceRecordsBox);
    debugPrint("✅ AttendanceRecordsBox abierta.");

    debugPrint("➡️ Abriendo ClassSessionsBox...");
    await Hive.openBox<ClassSession>(_classSessionsBox);
    debugPrint("✅ ClassSessionsBox abierta.");

    debugPrint("➡️ Abriendo GroupSchedulesBox...");
    await Hive.openBox<GroupSchedule>(_groupSchedulesBox);
    debugPrint("✅ GroupSchedulesBox abierta.");
    
    debugPrint("✅ Todas las cajas han sido abiertas.");
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
  Box<Subject> get subjectsBox => Hive.box<Subject>(_subjectsBox);
  Box<Incidence> get incidencesBox => Hive.box<Incidence>(_incidencesBox);
  Box<ClassSession> get classSessionsBox =>
      Hive.box<ClassSession>(_classSessionsBox);

  // Limpiar todas las cajas (útil para cerrar sesión o resetear)
  Future<void> clearAllBoxes() async {
    await studentsBox.clear();
    await groupsBox.clear();
    await groupSchedulesBox.clear();
    await nonAttendanceDaysBox.clear();
    await schoolCyclesBox.clear();
    await attendanceRecordsBox.clear();
    await teachersBox.clear();
    await subjectsBox.clear();
    await incidencesBox.clear();
    await classSessionsBox.clear();
  }

  // Cerrar todas las cajas
  Future<void> closeAllBoxes() async {
    await Hive.close();
  }
}
