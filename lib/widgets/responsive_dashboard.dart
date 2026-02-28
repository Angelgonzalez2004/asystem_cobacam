import 'package:asystem_cobacam/screens/dashboards/tutor/tutor_view_attendance_screen.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/screens/common/view_student_profile_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/student/student_credential_screen.dart';
import 'package:asystem_cobacam/screens/common/general_user_profile_screen.dart';
import 'package:asystem_cobacam/screens/common/settings_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_access_codes_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/admin_common/manage_announcements_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/non_attendance_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/school_cycle_management_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_viewer_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/teacher_schedule_viewer_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/manage_cycle_teachers_screen.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/group_schedule_management_screen.dart';
import 'package:asystem_cobacam/screens/common/faq_screen.dart';
import 'package:asystem_cobacam/screens/common/about_us_screen.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:asystem_cobacam/widgets/app_drawer.dart';
import 'package:asystem_cobacam/widgets/refresh_app_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ResponsiveDashboard extends StatefulWidget {
  final String role;
  final Widget Function(
    Function(String route, {Object? arguments}) onNavigate,
    Student? linkedStudent,
    String? userName,
    String? userCampus,
  ) bodyBuilder;

  const ResponsiveDashboard(
      {super.key, required this.role, required this.bodyBuilder});

  @override
  State<ResponsiveDashboard> createState() => _ResponsiveDashboardState();
}

class _ResponsiveDashboardState extends State<ResponsiveDashboard> {
  String _userName = 'Cargando...';
  String _userRole = '';
  String _userEmail = '';
  String? _userProfileUrl;
  String? _userCampus;
  DatabaseReference? _userRef;

  late AppSettingsService _appSettingsService;

  Widget? _activeSubScreen;
  String _currentTitle = '';

  // State for Tutor's linked student
  Student? _linkedStudent;

  @override
  void initState() {
    super.initState();
    _currentTitle = 'Dashboard ${widget.role}';
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _initUserData();
  }

  void _initUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email ?? '';
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _userRef!.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<Object?, Object?>.from(event.snapshot.value as Map);
            if (mounted) {
              setState(() {
                _userName = data['fullName']?.toString() ?? 'Usuario';
                _userRole = data['role']?.toString() ?? widget.role;
                _userProfileUrl = data['profileImageUrl']?.toString();
                _userCampus = data['campus']?.toString();
              });
              // If user is a tutor, find their linked student
              if (_userRole == 'Tutor' && _linkedStudent == null) {
                _loadLinkedStudentData(user.uid);
              }
            }
          } catch (e) {
            debugPrint("Error parsing user data in dashboard: $e");
          }
        }
      });
    }
  }

  Future<void> _loadLinkedStudentData(String tutorId) async {
    // Si no hay campus definido en el perfil del tutor, no podemos saber dónde buscar alumnos
    if (_userCampus == null || _userCampus!.isEmpty) {
      debugPrint("⚠️ No se puede buscar alumno: Campus del tutor es nulo o vacío.");
      return;
    }

    try {
      debugPrint("🔍 Buscando alumno vinculado para Tutor UID: $tutorId en plantel: $_userCampus");
      final currentSchoolCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      Student? foundStudent;

      // 1. INTENTO EN EL CICLO ACTUAL (MÁS RÁPIDO)
      if (currentSchoolCycleId.isNotEmpty) {
        final activeCycleRef = FirebaseDatabase.instance.ref('planteles/$_userCampus/students/$currentSchoolCycleId');
        final activeCycleSnapshot = await activeCycleRef.get();
        
        if (activeCycleSnapshot.exists) {
          for (final studentSnapshot in activeCycleSnapshot.children) {
            try {
              final val = studentSnapshot.value;
              if (val == null || val is! Map) {
                debugPrint("⏭️ Saltando nodo no válido (posible 'Ninguna'): $val");
                continue;
              }
              final studentData = Map<dynamic, dynamic>.from(val);
              final rawGuardianIds = studentData['guardianUserIds'];
              
              List<String> guardianIds = [];
              if (rawGuardianIds is List) {
                guardianIds = List<String>.from(rawGuardianIds);
              } else if (rawGuardianIds is Map) {
                guardianIds = rawGuardianIds.values.map((e) => e.toString()).toList();
              }

              if (guardianIds.contains(tutorId)) {
                foundStudent = Student.fromSnapshot(studentSnapshot);
                debugPrint("✅ Alumno encontrado en ciclo actual: ${foundStudent.fullName}");
                break;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      // 2. BÚSQUEDA GLOBAL EN TODOS LOS CICLOS DEL PLANTEL (FALLBACK)
      if (foundStudent == null) {
        debugPrint("⏳ Buscando en todos los ciclos del plantel...");
        final allStudentsRef = FirebaseDatabase.instance.ref('planteles/$_userCampus/students');
        final allCyclesSnapshot = await allStudentsRef.get();
        
        if (allCyclesSnapshot.exists) {
          for (final cycleSnapshot in allCyclesSnapshot.children) {
            for (final studentSnapshot in cycleSnapshot.children) {
              try {
                final studentData = Map<dynamic, dynamic>.from(studentSnapshot.value as Map);
                final rawGuardianIds = studentData['guardianUserIds'];
                
                List<String> guardianIds = [];
                if (rawGuardianIds is List) {
                  guardianIds = List<String>.from(rawGuardianIds);
                } else if (rawGuardianIds is Map) {
                  guardianIds = rawGuardianIds.values.map((e) => e.toString()).toList();
                }

                if (guardianIds.contains(tutorId)) {
                  foundStudent = Student.fromSnapshot(studentSnapshot);
                  debugPrint("✅ Alumno encontrado en ciclo histórico: ${foundStudent.fullName}");
                  break;
                }
              } catch (e) {
                continue;
              }
            }
            if (foundStudent != null) break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _linkedStudent = foundStudent;
        });
        if (foundStudent == null) {
          debugPrint("❌ No se encontró ningún alumno vinculado para el tutor $tutorId");
        }
      }
    } catch (e) {
      debugPrint("🚨 Error crítico buscando alumno: $e");
    }
  }

  void _onNavigate(String route, {Object? arguments}) {
    // For tutor-specific routes that need the student object, pass it from here
    final Object? finalArguments = (arguments ?? _linkedStudent);

    setState(() {
      if (route == 'home') {
        _activeSubScreen = null;
        _currentTitle = 'Dashboard $_userRole';
      } else if (route == 'profile') {
        _activeSubScreen = const GeneralUserProfileScreen(isEmbedded: true);
        _currentTitle = 'Mi Perfil';
      } else if (route == 'settings') {
        _activeSubScreen = const SettingsScreen(isEmbedded: true);
        _currentTitle = 'Ajustes';
      } else if (route == 'manage_announcements') {
        Navigator.push(context, SlideRightRoute(page: ManageAnnouncementsScreen(campus: _userCampus, isGeneralAdmin: _userRole.contains('General'))));
      } else if (route == 'manage_access_codes') {
        Navigator.push(context, SlideRightRoute(page: ManageAccessCodesScreen(campus: _userCampus, isGeneralAdmin: _userRole.contains('General'))));
      } else if (route == 'horarios') {
        _activeSubScreen = const GroupScheduleManagementScreen(isReadOnlyUser: true);
        _currentTitle = 'Horarios';
      } else if (route == 'manage_group_schedules') {
        _activeSubScreen = const GroupScheduleManagementScreen(isReadOnlyUser: false);
        _currentTitle = 'Gestión de Horarios';
      } else if (route == 'visor_grupo') {
        _activeSubScreen = const GroupScheduleViewerScreen();
        _currentTitle = 'Visor de Horario (Grupo)';
      } else if (route == 'visor_maestro') {
        _activeSubScreen = const TeacherScheduleViewerScreen();
        _currentTitle = 'Visor de Horario (Maestro)';
      } else if (route == 'manage_teachers') {
        if (_userCampus != null) {
          _appSettingsService.getCurrentSchoolCycleId().then((schoolCycleId) {
            Navigator.push(context, SlideRightRoute(page: ManageCycleTeachersScreen(campusId: _userCampus!, schoolCycleId: schoolCycleId)));
          });
          _currentTitle = 'Gestionar Personal Docente';
        }
      } else if (route == 'faq') {
        _activeSubScreen = const FaqScreen();
        _currentTitle = 'Manual Operativo (FAQ)';
      } else if (route == 'about_us') {
        _activeSubScreen = const AboutUsScreen();
        _currentTitle = 'Sobre Nosotros';
      } else if (route == 'credencial_alumno') {
        _activeSubScreen = const StudentCredentialScreen();
        _currentTitle = 'Mi Credencial';
      } else if (route == 'ciclos_escolares') {
        _activeSubScreen = const SchoolCycleManagementScreen(isReadOnly: true);
        _currentTitle = 'Ciclos Escolares';
      } else if (route == 'dias_no_lectivos') {
        _activeSubScreen = const NonAttendanceManagementScreen(isReadOnly: true);
        _currentTitle = 'Días Inhábiles';
      } else if (route == 'tutor_view_credential') {
        final student = finalArguments as Student?;
        if (student != null) {
          _activeSubScreen = StudentCredentialScreen(student: student, campusId: _userCampus);
          _currentTitle = 'Credencial de ${student.fullName.split(' ').first}';
        }
      } else if (route == 'tutor_view_student_profile') {
        final student = finalArguments as Student?;
        if (student != null) {
          _activeSubScreen = ViewStudentProfileScreen(student: student);
          _currentTitle = 'Perfil de ${student.fullName.split(' ').first}';
        }
      } else if (route == 'tutor_view_attendance') {
        final student = finalArguments as Student?;
        if (student != null) {
          _activeSubScreen = TutorViewAttendanceScreen(student: student, campusId: _userCampus);
          _currentTitle = 'Asistencia de ${student.fullName.split(' ').first}';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: isDark ? null : Colors.white,
        foregroundColor: isDark ? Colors.white : theme.colorScheme.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        actions: const [
          RefreshAppButton(),
          SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        role: _userRole,
        userName: _userName,
        userEmail: _userEmail,
        profileImageUrl: _userProfileUrl,
        onNavigate: _onNavigate,
      ),
      body: FadeInUp(
        key: ValueKey(_activeSubScreen == null ? 'home' : _activeSubScreen.runtimeType.toString()),
        child: _activeSubScreen ?? widget.bodyBuilder(_onNavigate, _linkedStudent, _userName, _userCampus),
      ),
    );
  }
}
