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

  static const String _appSettingsBox = 'appSettingsBox'; // Para configuraciones generales
  
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
    debugPrint("➡️ Registrando adaptadores...");
    Hive.registerAdapter(StudentAdapter());
    Hive.registerAdapter(TeacherAdapter());
    Hive.registerAdapter(SubjectAdapter());
    Hive.registerAdapter(SchoolCycleAdapter());
    Hive.registerAdapter(NonAttendanceDayAdapter());
    Hive.registerAdapter(IncidenceAdapter());
    Hive.registerAdapter(GroupAdapter());
    Hive.registerAdapter(AttendanceRecordAdapter());
    Hive.registerAdapter(ClassSessionAdapter());
    Hive.registerAdapter(GroupScheduleAdapter());
    debugPrint("✅ Todos los adaptadores registrados.");

    // --- APERTURA DE CAJAS (CONCURRENTEMENTE) ---
    debugPrint("➡️ Abriendo todas las cajas de Hive...");
    try {
      await Future.wait([
        Hive.openBox<SchoolCycle>(_schoolCyclesBox),
        Hive.openBox<Subject>(_subjectsBox),
        Hive.openBox<Teacher>(_teachersBox),
        Hive.openBox<Student>(_studentsBox),
        Hive.openBox<NonAttendanceDay>(_nonAttendanceDaysBox),
        Hive.openBox<Incidence>(_incidencesBox),
        Hive.openBox<Group>(_groupsBox),
        Hive.openBox<AttendanceRecord>(_attendanceRecordsBox),
        Hive.openBox<ClassSession>(_classSessionsBox),
        Hive.openBox<GroupSchedule>(_groupSchedulesBox),
        Hive.openBox(_appSettingsBox), // Caja genérica para ajustes
      ]);
      debugPrint("✅ Todas las cajas han sido abiertas correctamente.");
    } catch (e) {
      debugPrint("🚨 ERROR CRÍTICO al abrir una o más cajas de Hive: $e");
      // Opcional: Podrías querer re-lanzar el error o manejarlo de alguna manera
      // para evitar que la app continúe en un estado inconsistente.
      rethrow;
    }
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
  Box get appSettingsBox => Hive.box(_appSettingsBox); // Getter para la nueva caja

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
    await appSettingsBox.clear(); // Limpiar también la nueva caja
  }


  // Cerrar todas las cajas
  Future<void> closeAllBoxes() async {
    await Hive.close();
  }
}
