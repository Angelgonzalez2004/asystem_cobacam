import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:async';
import 'dart:io'; // Required for File
import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // Required for getApplicationDocumentsDirectory
import 'package:asystem_cobacam/utils/web_downloader.dart'; // Required for WebDownloader
import 'package:flutter/foundation.dart' show kIsWeb; // Required for kIsWeb

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [BarcodeFormat.code128, BarcodeFormat.qrCode],
  );

  late final AppSettingsService _appSettingsService;
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;

  DatabaseReference? _attendanceRef;
  DatabaseReference? _studentsRef;
  DatabaseReference? _groupSchedulesRef;
  DatabaseReference? _groupsRef;

  StreamSubscription<DatabaseEvent>? _attendanceSubscription;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;
  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  List<Map<String, dynamic>> _todayAttendance = [];
  Map<String, Student> _studentsMap = {};
  Map<String, GroupSchedule> _groupSchedulesMap = {};
  List<Group> _groups = [];
  List<NonAttendanceDay> _nonAttendanceDays = [];

  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = '';
  String _todayDate = '';

  // Logic Control
  String? _lastProcessedStudentId;
  bool _isProcessing = true;
  bool _isManualInputMode = false;
  int _offlineRecordsCount = 0;

  // Visual Feedback State
  Color _scannerBorderColor = Colors.transparent;
  bool _isFlashOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  final List<String> _tardyReasons = [
    'Enfermedad',
    'Cita médica',
    'Problemas familiares',
    'Tráfico',
    'Transporte público',
    'Otro (especificar)',
  ];

  final List<String> _earlyExitReasons = [
    'Enfermedad',
    'Cita médica',
    'Problemas familiares',
    'Emergencia',
    'Otro (especificar)',
  ];

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);

    _initData();

    _connectivitySubscription =
        _connectivityService.connectivityStream.listen((result) {
      if (mounted) {
        final bool wasOnline = _connectivityResult != ConnectivityResult.none;
        setState(() {
          _connectivityResult = result;
        });
        if (_connectivityResult != ConnectivityResult.none) {
          _syncOfflineAttendance();
          if (!wasOnline) {
            _syncFirebaseData();
            if (mounted) {
              UiHelpers.showSnackBar(
                  context, '¡Conexión restablecida! Sincronizando datos...');
            }
          }
        } else {
          _loadStudentsAndSchedules(online: false);
          if (mounted) {
            UiHelpers.showSnackBar(context, 'Modo Offline activado.',
                isError: true);
          }
        }
        _loadOfflineAttendanceCount();
      }
    });
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final prefs = await SharedPreferences.getInstance();

      String? campus;
      try {
        final userProfileSnapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .get();
        if (userProfileSnapshot.exists) {
          final userData =
              Map<String, dynamic>.from(userProfileSnapshot.value as Map);
          campus = userData['campus'];
          if (campus != null) await prefs.setString('cached_campus', campus);
        }
      } catch (e) {
        debugPrint('Error obteniendo perfil online: $e');
      }

      campus ??= prefs.getString('cached_campus');

      if (campus == null) {
        throw Exception(
            'El usuario no tiene un plantel asignado o requiere conexión para la primera configuración.');
      }

      final dynamicSchoolCycle =
          await _appSettingsService.getCurrentSchoolCycleId();
      final fetchedNonAttendanceDays =
          await _appSettingsService.getAllNonAttendanceDays(campus);

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _nonAttendanceDays = fetchedNonAttendanceDays;
        _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      });

      _attendanceRef = FirebaseDatabase.instance.ref(
          'planteles/$_campus/attendance/$_currentSchoolCycle/$_todayDate');
      _studentsRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/students/$_currentSchoolCycle');
      _groupSchedulesRef = FirebaseDatabase.instance.ref(
          'planteles/$_campus/schedules/$_currentSchoolCycle');
      _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');

      _connectivityResult = await _connectivityService.checkConnectivity();

      if (_connectivityResult == ConnectivityResult.none) {
        _loadStudentsAndSchedules(online: false);
      }

      _setupFirebaseListeners();
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error inicializando: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncFirebaseData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        await _connectivityService.checkConnectivity() ==
            ConnectivityResult.none) {
      return;
    }

    try {
      final userProfileSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get()
          .timeout(const Duration(seconds: 5));
      if (userProfileSnapshot.exists) {
        final userData =
            Map<String, dynamic>.from(userProfileSnapshot.value as Map);
        if (userData['campus'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_campus', userData['campus']);
          if (mounted) setState(() => _campus = userData['campus']);
        }
      }

      final onlineCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      final onlineNonAttendance =
          await _appSettingsService.getAllNonAttendanceDays(_campus!);

      if (mounted) {
        setState(() {
          _currentSchoolCycle = onlineCycleId;
          _nonAttendanceDays = onlineNonAttendance;
        });
      }

      _setupFirebaseRefs();
      _setupFirebaseListeners();
    } catch (e) {
      debugPrint("Background sync failed: $e");
    }
  }

  void _setupFirebaseRefs() {
    if (_campus == null || _currentSchoolCycle.isEmpty) return;
    _attendanceRef = FirebaseDatabase.instance.ref(
        'planteles/$_campus/attendance/$_currentSchoolCycle/$_todayDate');
    _studentsRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/students/$_currentSchoolCycle');
    _groupSchedulesRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/schedules/$_currentSchoolCycle');
    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
  }

  void _setupFirebaseListeners() {
    if (_attendanceRef == null) return;

    _attendanceSubscription?.cancel();
    _attendanceSubscription = _attendanceRef!.onValue.listen((event) {
      final newAttendance = <Map<String, dynamic>>[];
      if (event.snapshot.exists) {
        for (var child in event.snapshot.children) {
          if (child.value != null) {
            final record = Map<String, dynamic>.from(child.value as Map);
            record['studentId'] = child.key;
            newAttendance.add(record);
          }
        }
      }
      _combineFirebaseAndHiveAttendance(newAttendance);
    });

    _studentsSubscription?.cancel();
    _studentsSubscription = _studentsRef!.onValue.listen((event) {
      final newStudentsMap = <String, Student>{};
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          final student = Student.fromSnapshot(child);
          newStudentsMap[student.studentId] = student;
        }
      }
      if (mounted) setState(() => _studentsMap = newStudentsMap);
    });

    _groupSchedulesSubscription?.cancel();
    _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
      final newGroupSchedulesMap = <String, GroupSchedule>{};
      if (event.snapshot.exists) {
        for (final groupChild in event.snapshot.children) {
          final groupId = groupChild.key!;
          newGroupSchedulesMap[groupId] =
              GroupSchedule.fromSnapshot(groupChild);
        }
      }
      _hiveService.groupSchedulesBox.putAll(newGroupSchedulesMap);
      if (mounted) setState(() => _groupSchedulesMap = newGroupSchedulesMap);
    });

    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!
        .orderByChild('schoolCycleId')
        .equalTo(_currentSchoolCycle)
        .onValue
        .listen((event) {
      final List<Group> fetchedGroups = [];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          fetchedGroups.add(Group.fromSnapshot(child));
        }
      }
      if (mounted) setState(() => _groups = fetchedGroups);
    });
  }

  void _combineFirebaseAndHiveAttendance(
      List<Map<String, dynamic>> firebaseAttendance) {
    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;

    final List<Map<String, dynamic>> hiveAttendance = attendanceRecordsBox.values
        .where((record) =>
            record.date == _todayDate &&
            record.campusId == _campus &&
            record.schoolCycle == _currentSchoolCycle &&
            !record.isSynced)
        .map((record) => record.toFirebaseMap()..['studentId'] = record.studentId)
        .toList();

    final Map<String, Map<String, dynamic>> combinedAttendance = {};

    for (var record in firebaseAttendance) {
      combinedAttendance[record['studentId']] = record;
    }

    for (var record in hiveAttendance) {
      if (!combinedAttendance.containsKey(record['studentId'])) {
        combinedAttendance[record['studentId']] = record;
      } else {
        final existing = combinedAttendance[record['studentId']]!;
        if (record.containsKey('entryTime')) {
          existing['entryTime'] = record['entryTime'];
        }
        if (record.containsKey('exitTime')) {
          existing['exitTime'] = record['exitTime'];
        }
        if (record.containsKey('status')) existing['status'] = record['status'];
        if (record.containsKey('reasonTardy')) {
          existing['reasonTardy'] = record['reasonTardy'];
        }
        if (record.containsKey('reasonEarlyExit')) {
          existing['reasonEarlyExit'] = record['reasonEarlyExit'];
        }
      }
    }

    if (mounted) {
      setState(() {
        _todayAttendance = combinedAttendance.values.toList();
        _todayAttendance.sort((a, b) {
          final aTime = a['exitTime'] ?? a['entryTime'] ?? '';
          final bTime = b['exitTime'] ?? b['entryTime'] ?? '';
          return bTime.compareTo(aTime);
        });
      });
    }
  }

  Future<void> _loadStudentsAndSchedules({required bool online}) async {
    if (!online) {
      final studentsBox = _hiveService.studentsBox;
      final groupSchedulesBox = _hiveService.groupSchedulesBox;

      if (studentsBox.isNotEmpty) {
        final newStudentsMap = <String, Student>{};
        for (var student in studentsBox.values) {
          newStudentsMap[student.studentId] = student;
        }
        if (mounted) setState(() => _studentsMap = newStudentsMap);
      }

      if (groupSchedulesBox.isNotEmpty) {
        final newGroupSchedulesMap = <String, GroupSchedule>{};
        groupSchedulesBox.toMap().forEach((key, value) {
          newGroupSchedulesMap[key.toString()] = value;
        });
        if (mounted) setState(() => _groupSchedulesMap = newGroupSchedulesMap);
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _attendanceSubscription?.cancel();
    _studentsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    _groupsSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcodeCapture) {
    if (!_isProcessing) {
      return;
    }

    if (_scannerBorderColor != Colors.transparent) {
      return;
    }

    final String? studentId = barcodeCapture.barcodes.first.rawValue;
    if (studentId == null) {
      return;
    }
    _processStudentId(studentId);
  }

  bool _isDayValidForAttendance(Function(String) onError) {
    if (_currentSchoolCycle.isEmpty) {
      onError('Error: No hay ciclo escolar activo.');
      return false;
    }

    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      onError('Hoy es fin de semana (No hay asistencia).');
      return false;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    if (_nonAttendanceDays.any((day) {
      final dayStr = DateFormat('yyyy-MM-dd').format(day.date);
      return dayStr == todayStr;
    })) {
      onError('Hoy está marcado como día no lectivo.');
      return false;
    }

    return true;
  }

  Future<void> _processStudentId(String studentId) async {
    if (!_isProcessing || _campus == null) return;
    if (studentId == _lastProcessedStudentId) return;

    setState(() {
      _lastProcessedStudentId = studentId;
      _isProcessing = false;
    });

    void triggerError(String msg) {
      _triggerFeedback(false);
      UiHelpers.showSnackBar(context, msg, isError: true);
      _resumeProcessingAfterDelay();
    }

    if (!_isDayValidForAttendance(triggerError)) return;

    final Student? student = _studentsMap[studentId];
    if (student == null) {
      triggerError('Matrícula "$studentId" no encontrada.');
      return;
    }

    if (!student.isActive) {
      triggerError('ALUMNO DADO DE BAJA.');
      return;
    }

    Map<String, dynamic> record = _todayAttendance.firstWhere(
      (rec) => rec['studentId'] == studentId,
      orElse: () => <String, dynamic>{},
    );

    String scanType;
    if (!record.containsKey('entryTime')) {
      scanType = 'entry';
    } else if (!record.containsKey('exitTime')) {
      if (!_isManualInputMode) {
        final entryTimeStr = record['entryTime'] as String;
        final entryTime = _parseTime(entryTimeStr);
        if (DateTime.now().difference(entryTime).inMinutes < 2) {
          triggerError('Ya se registró la entrada hace un momento.');
          return;
        }
      }
      scanType = 'exit';
    } else {
      triggerError('El alumno ya completó su jornada hoy.');
      return;
    }

    await _registerAttendance(student, scanType, record);
    _resumeProcessingAfterDelay();
  }

  Future<void> _registerAttendance(
      Student student, String scanType, Map<String, dynamic> existingRecord) async {
    final DateTime now = DateTime.now();
    final String todayDayOfWeek =
        DateFormat('EEEE', 'es_MX').format(now).toLowerCase();

    String targetGroupId = student.group;
    try {
      final groupObj = _groups.firstWhere((g) => g.name == student.group);
      targetGroupId = groupObj.key;
    } catch (_) {
    }

    final GroupSchedule? groupSchedule = _groupSchedulesMap[targetGroupId];

    DateTime scheduledEntry =
        DateTime(now.year, now.month, now.day, 7, 0); 
    DateTime scheduledExit =
        DateTime(now.year, now.month, now.day, 14, 0); 

    // Check for capitalized day name (e.g. "Viernes") as stored in DB
    final String capitalizedDay = todayDayOfWeek.isNotEmpty
        ? todayDayOfWeek[0].toUpperCase() + todayDayOfWeek.substring(1)
        : todayDayOfWeek;

    List<ClassSession>? todaySessions;
    if (groupSchedule != null) {
      if (groupSchedule.dailySchedules.containsKey(todayDayOfWeek)) {
        todaySessions = groupSchedule.dailySchedules[todayDayOfWeek];
      } else if (groupSchedule.dailySchedules.containsKey(capitalizedDay)) {
        todaySessions = groupSchedule.dailySchedules[capitalizedDay];
      }
    }

    if (todaySessions != null && todaySessions.isNotEmpty) {
      if (true) { // Wrapper to maintain indentation or just simplify
        final earliestSession = todaySessions.reduce(
            (a, b) => a.startTime.compareTo(b.startTime) < 0 ? a : b);
        final latestSession = todaySessions
            .reduce((a, b) => a.endTime.compareTo(b.endTime) > 0 ? a : b);

        try {
          final entryParts = earliestSession.startTime.split(':');
          scheduledEntry = DateTime(now.year, now.month, now.day,
              int.parse(entryParts[0]), int.parse(entryParts[1]));
        } catch (_) {}
        try {
          final exitParts = latestSession.endTime.split(':');
          scheduledExit = DateTime(now.year, now.month, now.day,
              int.parse(exitParts[0]), int.parse(exitParts[1]));
        } catch (_) {}
      }
    } else {
      _triggerFeedback(false);
      UiHelpers.showSnackBar(context, 'Grupo ${student.group} sin horario hoy.',
          isError: true);
      return;
    }

    final String currentTime = DateFormat('HH:mm').format(now);

    final Map<String, dynamic> record =
        Map<String, dynamic>.from(existingRecord);
    record['studentFullName'] = student.fullName;
    record['group'] = student.group;
    record['campusId'] = _campus;
    record['schoolCycle'] = _currentSchoolCycle;
    record['date'] = _todayDate;
    record['studentId'] = student.studentId;

    bool needsReason = false;
    String reasonTitle = '';
    List<String> reasonsList = [];
    bool isWarning = false;

    if (scanType == 'entry') {
      record['entryTime'] = currentTime;
      final toleranceLimit = scheduledEntry.add(const Duration(minutes: 15));
      if (now.isAfter(toleranceLimit)) {
        needsReason = true;
        reasonTitle = 'Motivo de Retardo';
        reasonsList = _tardyReasons;
        record['status'] = 'tarde';
        isWarning = true;
      } else {
        record['status'] = 'presente';
      }
    } else {
      record['exitTime'] = currentTime;
      if (now.isBefore(scheduledExit)) {
        needsReason = true;
        reasonTitle = 'Salida Anticipada';
        reasonsList = _earlyExitReasons;
        isWarning = true;
      }
    }

    if (needsReason) {
      final String? reason = await _showReasonDialog(reasonTitle, reasonsList);
      if (reason == null) {
        _triggerFeedback(false);
        UiHelpers.showSnackBar(context, 'Registro cancelado.', isError: true);
        return;
      }
      if (scanType == 'entry') {
        record['reasonTardy'] = reason;
      } else {
        record['reasonEarlyExit'] = reason;
      }
    }

    _checkAndShowMedicalAlert(student);

    _triggerFeedback(true, isWarning: isWarning);

    try {
      final ConnectivityResult currentConnectivity =
          await _connectivityService.checkConnectivity();
      if (currentConnectivity == ConnectivityResult.none) {
        final attendanceRecord = AttendanceRecord.fromFirebaseMap(
          student.studentId,
          _todayDate,
          record,
          campusId: _campus!,
          schoolCycle: _currentSchoolCycle,
        );
        attendanceRecord.isSynced = false;
        await _hiveService.attendanceRecordsBox
            .put(attendanceRecord.uniqueKey, attendanceRecord);
      } else {
        await _attendanceRef!.child(student.studentId).set(record);
        
        // --- ENVÍO DE NOTIFICACIÓN AL TUTOR ---
        if (student.guardianUserIds != null && student.guardianUserIds!.isNotEmpty) {
          NotificationService.sendAttendanceNotification(
            studentName: student.fullName,
            guardianIds: student.guardianUserIds!,
            type: scanType == 'entry' ? 'entrada' : 'salida',
            time: currentTime,
            campusName: _campus ?? 'Cobacam',
          ).catchError((e) => debugPrint('Error enviando notificación: $e'));
        }
        
        final key = '${student.studentId}_$_todayDate';
        if (_hiveService.attendanceRecordsBox.containsKey(key)) {
          await _hiveService.attendanceRecordsBox.delete(key);
        }
      }
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al guardar.', isError: true);
      }
    }
  }

  void _checkAndShowMedicalAlert(Student student) {
    if (!student.medicalAlert) return;

    final cleanAllergies = (student.allergies ?? '').trim();
    final cleanConditions = (student.healthConditions ?? '').trim();
    final cleanStatus = (student.generalHealthStatus ?? '').trim();

    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.red, width: 2)),
        title: const Row(
          children: [
            Icon(Icons.medical_services_outlined, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
                child: Text('ALERTA MÉDICA',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El alumno ${student.fullName} requiere atención especial:',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildMedicalInfoBox(
                'ESTADO GENERAL',
                cleanStatus.isNotEmpty ? cleanStatus : 'No especificado'),
            if (cleanConditions.isNotEmpty && cleanConditions.toLowerCase() != 'ninguna')
              _buildMedicalInfoBox('CONDICIONES', cleanConditions),
            if (cleanAllergies.isNotEmpty && cleanAllergies.toLowerCase() != 'ninguna')
              _buildMedicalInfoBox('ALERGIAS', cleanAllergies),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('ENTENDIDO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMedicalInfoBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.brown)),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
          child: Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  void _triggerFeedback(bool isSuccess, {bool isWarning = false}) {
    if (!mounted) return;
    setState(() {
      if (!isSuccess) {
        _scannerBorderColor = Colors.red;
        HapticFeedback.heavyImpact();
      } else if (isWarning) {
        _scannerBorderColor = Colors.orange;
        HapticFeedback.mediumImpact();
      } else {
        _scannerBorderColor = Colors.green;
        HapticFeedback.lightImpact();
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scannerBorderColor = Colors.transparent);
    });
  }

  void _resumeProcessingAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isProcessing = true);
    });
  }

  DateTime _parseTime(String time) {
    if (time.isEmpty) return DateTime.now();
    try {
      final parts = time.split(':');
      final now = DateTime.now();
      return DateTime(
          now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<String?> _showReasonDialog(
      String title, List<String> predefinedReasons) async {
    String? selectedReason;
    final customReasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, stfSetState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...predefinedReasons.map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (val) =>
                          stfSetState(() => selectedReason = val),
                      activeColor: Theme.of(context).primaryColor,
                    )),
                if (selectedReason == 'Otro (especificar)')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: customReasonController,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Especifica el motivo',
                          border: OutlineInputBorder()),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final result = selectedReason == 'Otro (especificar)'
                          ? customReasonController.text.trim()
                          : selectedReason;
                      if (selectedReason == 'Otro (especificar)' &&
                          result!.isEmpty) {
                        return;
                      }
                      Navigator.pop(context, result);
                    },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  // --- NUEVA LÓGICA DE INCIDENCIA RÁPIDA ---
  final List<String> _incidenceTypesFull = [
    'Uniforme Incompleto', 'Cabello/Corte no permitido', 'Uso de Celular sin autorización',
    'Falta de Respeto a Autoridad', 'Daño a Mobiliario o Instalaciones', 'Salida del Plantel sin Pase',
    'Retardo injustificado', 'Incumplimiento de Tareas/Material', 'Agresión Física o Verbal',
    'Robo o Extorsión', 'Vandalismo o Grafiti', 'Consumo de Sustancias Prohibidas',
    'Acoso Escolar (Bullying)', 'Falsificación de Firmas/Documentos', 'Interrupción de la Labor Docente',
    'Lenguaje Obsceno o Inapropiado', 'Consumo de Alimentos en Aula', 'Desobediencia a Instrucciones',
    'Copia en Examen o Plagio', 'Riña o Connatos de Violencia', 'Portación de Objetos Peligrosos',
    'Inasistencia Injustificada (Saltarse clases)', 'Uso de Gorras o Lentes de Sol en Aula', 'Otro'
  ];

  final Map<String, IconData> _incidenceIconsFull = {
    'Uniforme Incompleto': Icons.checkroom,
    'Cabello/Corte no permitido': Icons.face,
    'Uso de Celular sin autorización': Icons.phonelink_ring,
    'Falta de Respeto a Autoridad': Icons.sentiment_very_dissatisfied,
    'Daño a Mobiliario o Instalaciones': Icons.chair,
    'Salida del Plantel sin Pase': Icons.door_back_door,
    'Retardo injustificado': Icons.access_time,
    'Incumplimiento de Tareas/Material': Icons.assignment_late,
    'Agresión Física o Verbal': Icons.back_hand,
    'Robo o Extorsión': Icons.security,
    'Vandalismo o Grafiti': Icons.brush,
    'Consumo de Sustancias Prohibidas': Icons.smoke_free,
    'Acoso Escolar (Bullying)': Icons.groups_outlined,
    'Falsificación de Firmas/Documentos': Icons.description,
    'Interrupción de la Labor Docente': Icons.volume_up,
    'Lenguaje Obsceno o Inapropiado': Icons.record_voice_over,
    'Consumo de Alimentos en Aula': Icons.restaurant,
    'Desobediencia a Instrucciones': Icons.gavel,
    'Copia en Examen o Plagio': Icons.auto_fix_normal,
    'Riña o Connatos de Violencia': Icons.sports_kabaddi,
    'Portación de Objetos Peligrosos': Icons.priority_high,
    'Inasistencia Injustificada (Saltarse clases)': Icons.event_busy,
    'Uso de Gorras o Lentes de Sol en Aula': Icons.accessibility,
    'Otro': Icons.more_horiz,
  };

  void _showQuickIncidenceModal(
      String studentId, String studentName, String group) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Reportar Incidencia: $studentName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Grupo: $group',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _incidenceTypesFull.length,
                    itemBuilder: (context, index) {
                      final type = _incidenceTypesFull[index];
                      final icon = _incidenceIconsFull[type] ?? Icons.warning;
                      return _quickIncidenceBtn(studentId, studentName,
                          group, type, icon, theme.colorScheme.primary);
                    },
                  ),
                )
              ])),
    );
  }

  Widget _quickIncidenceBtn(String sid, String sName, String grp, String type,
      IconData icon, Color color) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);

        String finalType = type;
        if (type == 'Otro') {
          final String? reason = await _showReasonDialog(
              'Especificar Incidencia', ['Otro (especificar)']);
          if (reason == null) return;
          finalType = "Otro: $reason";
        }

        _saveQuickIncidence(sid, sName, grp, finalType);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuickIncidence(
      String sid, String sName, String grp, String type) async {
    try {
      final newRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/incidents')
          .push();
      final incidence = Incidence(
        id: newRef.key!,
        studentId: sid,
        studentName: sName,
        group: grp,
        type: type,
        description: 'Reporte Rápido desde Pase de Lista',
        date: DateTime.now(),
        campusId: _campus!,
        isSynced: true,
        schoolCycle: _currentSchoolCycle,
      );
      await newRef.set(incidence.toFirebaseMap());
      if (mounted) UiHelpers.showSnackBar(context, '⚠️ Incidencia "$type" registrada.');
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al guardar reporte.', isError: true);
    }
  }

  Widget _buildStatsDashboard(ThemeData theme) {
    int total = _todayAttendance.length;
    int entradas = _todayAttendance.where((r) => r.containsKey('entryTime')).length;
    int salidas = _todayAttendance.where((r) => r.containsKey('exitTime')).length;
    int tardes = _todayAttendance.where((r) => r['status'] == 'tarde').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(total.toString(), 'Total', Colors.blue, Icons.list_alt),
          _statItem(entradas.toString(), 'Entradas', Colors.green, Icons.login),
          _statItem(salidas.toString(), 'Salidas', Colors.purple, Icons.logout),
          _statItem(tardes.toString(), 'Tardes', Colors.orange, Icons.access_time_filled),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMassAttendanceDialog,
        icon: const Icon(Icons.groups_rounded),
        label: Text(
            'Masiva ${_offlineRecordsCount > 0 ? "($_offlineRecordsCount)" : ""}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Opciones',
                      onSelected: (value) {
                        if (value == 'download') _showDownloadOptionsDialog();
                        if (value == 'upload') _showImportOptionsDialog();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Descargar Plantilla'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'upload',
                          child: Row(
                            children: [
                              Icon(Icons.upload_file, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Importar Excel'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildStatsDashboard(theme),
                Expanded(
                  flex: 4,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _scannerBorderColor,
                        width: _scannerBorderColor == Colors.transparent ? 0 : 6,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          _scannerBorderColor == Colors.transparent ? 24 : 18),
                      child: Stack(
                        children: [
                          if (!_isManualInputMode)
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
                            )
                          else
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.keyboard_rounded,
                                      size: 64,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  const Text('Modo Manual Activado',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 16)),
                                ],
                              ),
                            ),
                          if (!_isManualInputMode)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton.filled(
                                    onPressed: () {
                                      _scannerController.toggleTorch();
                                      setState(() => _isFlashOn = !_isFlashOn);
                                    },
                                    icon: Icon(_isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off),
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.white24,
                                        foregroundColor: Colors.white),
                                  ),
                                  const SizedBox(width: 24),
                                  IconButton.filled(
                                    onPressed: () {
                                      _scannerController.switchCamera();
                                      setState(() => _cameraFacing =
                                          (_cameraFacing == CameraFacing.back
                                              ? CameraFacing.front
                                              : CameraFacing.back));
                                    },
                                    icon: const Icon(Icons.cameraswitch_rounded),
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.white24,
                                        foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ciclo: $_currentSchoolCycle',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: IconButton.filled(
                              onPressed: () => setState(() =>
                                  _isManualInputMode = !_isManualInputMode),
                              icon: Icon(_isManualInputMode
                                  ? Icons.qr_code_scanner_rounded
                                  : Icons.keyboard_rounded),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87),
                            ),
                          ),
                          if (!_isProcessing &&
                              _scannerBorderColor == Colors.transparent)
                            const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Autocomplete<Student>(
                    displayStringForOption: (Student option) => option.fullName,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Student>.empty();
                      }
                      return _studentsMap.values.where((Student option) {
                        final input = textEditingValue.text.toLowerCase();
                        return option.fullName.toLowerCase().contains(input) ||
                            option.studentId.contains(input);
                      });
                    },
                    onSelected: (Student selection) {
                      _processStudentId(selection.studentId);
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8.0,
                          borderRadius: BorderRadius.circular(16),
                          color: theme.cardColor,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 32,
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Student option = options.elementAt(index);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    child: Text(
                                      option.fullName.isNotEmpty
                                          ? option.fullName[0]
                                          : '?',
                                      style: TextStyle(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(option.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      'Matrícula: ${option.studentId} • Grupo: ${option.group}'),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Nombre o Matrícula...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor:
                              isDark ? Colors.white10 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text('Actividad Reciente',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _todayAttendance.isEmpty
                      ? Center(
                          child: Text('Sin registros hoy',
                              style: TextStyle(color: theme.hintColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _todayAttendance.length,
                          itemBuilder: (context, index) {
                            final record = _todayAttendance[index];
                            final studentId = record['studentId'] as String;
                            final studentName =
                                record['studentFullName'] as String;
                            final group = record['group'] as String;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Colors.grey.withOpacity(0.1))),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  child: Text(
                                    studentName.isNotEmpty
                                        ? studentName[0]
                                        : '?',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 14),
                                  ),
                                ),
                                title: Text(studentName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text('$studentId • $group',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (record['status'] == 'tarde')
                                              const Icon(
                                                  Icons.access_time_filled,
                                                  color: Colors.orange,
                                                  size: 14),
                                            if (record['entryTime'] != null) ...[
                                              const SizedBox(width: 4),
                                              Text(record['entryTime'],
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.green))
                                            ],
                                            if (record['exitTime'] != null) ...[
                                              const Text(' - ',
                                                  style: TextStyle(fontSize: 10)),
                                              Text(record['exitTime'],
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.purple))
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.redAccent),
                                      onPressed: () => _showQuickIncidenceModal(
                                          studentId, studentName, group),
                                      tooltip: 'Reportar Incidencia',
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showMassAttendanceDialog() {
    if (!_isDayValidForAttendance((msg) =>
        UiHelpers.showSnackBar(context, msg, isError: true))) {
      return;
    }

    const String type = 'exit';
    String? scope;
    String? groupId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, stfSetState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.purple),
                SizedBox(width: 10),
                Text('Salida Masiva'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Esta acción registrará la salida de los alumnos que ingresaron hoy y aún no han salido.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                const Text('Seleccionar Alcance:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: ChoiceChip(
                            label: const Text('Todo el Plantel'),
                            selected: scope == 'all',
                            onSelected: (v) =>
                                stfSetState(() => scope = 'all'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: ChoiceChip(
                            label: const Text('Por Grupo'),
                            selected: scope == 'group',
                            onSelected: (v) =>
                                stfSetState(() => scope = 'group'))),
                  ],
                ),
                if (scope == 'group') ...[
                  const SizedBox(height: 16),
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No hay grupos registrados en este ciclo ($_currentSchoolCycle).',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Selecciona Grupo',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.groups)),
                      value: groupId,
                      items: _groups
                          .map((group) => DropdownMenuItem(
                              value: group.name, child: Text(group.name)))
                          .toList(),
                      onChanged: (val) => stfSetState(() => groupId = val),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white),
                onPressed: (scope == null ||
                        (scope == 'group' && groupId == null))
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _performMassiveAttendance(type, scope!, groupId);
                      },
                child: const Text('Confirmar Salida'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performMassiveAttendance(
      String type, String scope, String? gId) async {
    final students = _studentsMap.values.where((s) {
      if (!s.isActive) return false;
      if (scope == 'group') return s.group == gId;
      return true;
    }).toList();

    if (students.isEmpty) {
      UiHelpers.showSnackBar(context, 'No hay alumnos para registrar.',
          isError: true);
      return;
    }

    final String? reason = await _showReasonDialog(
        'Motivo General para Registro Masivo ($type)',
        type == 'entry' ? _tardyReasons : _earlyExitReasons);

    if (reason == null) return;

    setState(() => _isLoading = true);
    final currentTime = DateFormat('HH:mm').format(DateTime.now());

    int successCount = 0;

    try {
      final Map<String, dynamic> updates = {};
      for (var s in students) {
        final path = s.studentId;
        final existing = _todayAttendance.firstWhere(
            (rec) => rec['studentId'] == s.studentId,
            orElse: () => <String, dynamic>{});

        final Map<String, dynamic> record =
            Map<String, dynamic>.from(existing);

        bool shouldUpdate = false;

        if (type == 'entry') {
          if (!record.containsKey('entryTime')) {
            record['entryTime'] = currentTime;
            record['status'] = 'presente_masivo';
            record['reasonTardy'] = reason;
            shouldUpdate = true;
          }
        } else {
          if (record.containsKey('entryTime') &&
              !record.containsKey('exitTime')) {
            record['exitTime'] = currentTime;
            record['reasonEarlyExit'] = reason;
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          if (!record.containsKey('studentId')) {
            record['studentFullName'] = s.fullName;
            record['group'] = s.group;
            record['campusId'] = _campus;
            record['schoolCycle'] = _currentSchoolCycle;
            record['date'] = _todayDate;
            record['studentId'] = s.studentId;
          }
          updates[path] = record;
          successCount++;
        }
      }

      if (updates.isNotEmpty) {
        await _attendanceRef!.update(updates);
        UiHelpers.showSnackBar(context,
            'Asistencia masiva de $type aplicada a $successCount alumnos (se omitieron ${students.length - successCount}).');
      } else {
        UiHelpers.showSnackBar(
            context, 'Ningún alumno requería actualización de $type.',
            isError: true);
      }
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error en registro masivo.',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOfflineAttendance() async {
    final box = _hiveService.attendanceRecordsBox;
    final unsynced = box.values.where((r) => !r.isSynced).toList();
    if (unsynced.isEmpty) return;

    for (var r in unsynced) {
      try {
        final ref = FirebaseDatabase.instance.ref(
            'planteles/${r.campusId}/attendance/${r.schoolCycle}/${r.date}/${r.studentId}');
        await ref.set(r.toFirebaseMap());
        await box.delete(r.uniqueKey);
      } catch (e) {
        debugPrint('Error sync: $e');
      }
    }
    _loadOfflineAttendanceCount();
  }

  Future<void> _loadOfflineAttendanceCount() async {
    final count = _hiveService.attendanceRecordsBox.values
        .where((r) => !r.isSynced)
        .length;
    if (mounted) setState(() => _offlineRecordsCount = count);
  }

  String _getScheduledTimeForStudent(Student student, String type) {
    if (_groupSchedulesMap.isEmpty) return '';

    String targetGroupId = student.group;
    try {
      final groupObj = _groups.firstWhere((g) => g.name == student.group);
      targetGroupId = groupObj.key;
    } catch (_) {
    }

    final GroupSchedule? groupSchedule = _groupSchedulesMap[targetGroupId];

    if (groupSchedule == null) return '';

    List<ClassSession>? todaySessions;
    // Use Spanish capitalized days to match DB keys
    List<String> weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

    for (var day in weekdays) {
      if (groupSchedule.dailySchedules.containsKey(day) && groupSchedule.dailySchedules[day]!.isNotEmpty) {
        todaySessions = groupSchedule.dailySchedules[day];
        break;
      }
    }

    if (todaySessions == null || todaySessions.isEmpty) return '';

    if (type == 'entry') {
      final earliestSession = todaySessions.reduce(
          (a, b) => a.startTime.compareTo(b.startTime) < 0 ? a : b);
      return earliestSession.startTime;
    } else {
      final latestSession = todaySessions
          .reduce((a, b) => a.endTime.compareTo(b.endTime) > 0 ? a : b);
      return latestSession.endTime;
    }
  }


  Future<void> _showDownloadOptionsDialog() async {
    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(
          context, 'Error: No se ha inicializado el plantel o ciclo escolar.',
          isError: true);
      return;
    }

    String? selectedType;

    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo de Plantilla de Asistencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Entrada'),
              value: 'entry',
              groupValue: selectedType,
              onChanged: (value) {
                selectedType = value;
                Navigator.pop(context, value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Salida'),
              value: 'exit',
              groupValue: selectedType,
              onChanged: (value) {
                selectedType = value;
                Navigator.pop(context, value);
              },
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        _generateExcelTemplate(value);
      }
    });
  }

  Future<void> _generateExcelTemplate(String type) async {
    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(context, 'Error: No se ha inicializado el plantel o ciclo escolar.', isError: true);
      return;
    }

    final List<Student> activeStudents = _studentsMap.values
        .where((s) => s.isActive && s.schoolCycle == _currentSchoolCycle)
        .toList();
    activeStudents.sort((a, b) => a.fullName.compareTo(b.fullName));

    var excel = excel_lib.Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Asistencia');
    excel_lib.Sheet sheet = excel['Asistencia'];

    // --- ESTILO PARA CENTRAR Y FUENTES ---
    final centerStyle = excel_lib.CellStyle(
      horizontalAlign: excel_lib.HorizontalAlign.Center,
      verticalAlign: excel_lib.VerticalAlign.Center,
    );
    final headerStyle = excel_lib.CellStyle(
      horizontalAlign: excel_lib.HorizontalAlign.Center,
      verticalAlign: excel_lib.VerticalAlign.Center,
      bold: true,
      fontColorHex: excel_lib.ExcelColor.white,
      backgroundColorHex: excel_lib.ExcelColor.fromHexString("#2196F3"), // Deep Blue
    );

    List<String> headers = [
      'Matrícula',
      'Nombre',
      'Grupo',
      'Fecha',
      'Hora Actual ${type == 'entry' ? 'Entrada' : 'Salida'}', // Now for manual input
      'Hora Programada',
      'Asistencia',
      'Motivo de Incidencia',
      'Observaciones'
    ];
    // Apply header style
    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = excel_lib.TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }
      
    for (int i = 0; i < activeStudents.length; i++) {
      final student = activeStudents[i];
      final rowNum = i + 2; // Excel rows are 1-indexed, headers are row 1
      
      // Matrícula (Col A, index 0)
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue(student.studentId);
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum - 1)).cellStyle = centerStyle;

      // Nombre (Col B, index 1)
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue(student.fullName);
      // No center style for name as it might be long

      // Grupo (Col C, index 2)
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue(student.group);
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowNum - 1)).cellStyle = centerStyle;

      // Fecha (Col D, index 3) - Formula + Short Date Format
      var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowNum - 1));
      dateCell.value = excel_lib.FormulaCellValue('IF(A$rowNum="", "", IF(D$rowNum<>0, D$rowNum, TODAY()))');
      dateCell.cellStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        numberFormat: excel_lib.NumFormat.standard_14, // Short date format
      );
      
      // Hora Actual Entrada/Salida (Col E, index 4) - NOW MANUAL INPUT
      // This cell will be left empty or with a default hint, no formula here
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowNum - 1)).value =
          excel_lib.TextCellValue(''); // Empty for manual input
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowNum - 1)).cellStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        numberFormat: excel_lib.NumFormat.standard_20, // Explicitly set time format
      );

      // Hora Programada (Col F, index 5)
      final scheduledTime = _getScheduledTimeForStudent(student, type);
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue(scheduledTime);
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowNum - 1)).cellStyle = centerStyle;

      // Asistencia (Col G, index 6) - Based on manual input in Col E
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowNum - 1))
          .value = excel_lib.FormulaCellValue('IF(E$rowNum="", "No", "Si")');
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowNum - 1)).cellStyle = centerStyle;

      // Motivo de Incidencia (Col H, index 7)
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue('');
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowNum - 1)).cellStyle = centerStyle;

      // Observaciones (Col I, index 8)
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowNum - 1))
          .value = excel_lib.TextCellValue('');
      // No center style for observations as it might be long
    }

    // --- AUTO-AJUSTE DE ANCHOS DE COLUMNA Y CENTRADO ---
    sheet.setColumnAutoFit(0); // Matrícula
    sheet.setColumnAutoFit(1); // Nombre
    sheet.setColumnAutoFit(2); // Grupo
    sheet.setColumnAutoFit(3); // Fecha
    sheet.setColumnAutoFit(4); // Hora Actual E/S
    sheet.setColumnAutoFit(5); // Hora Programada
    sheet.setColumnAutoFit(6); // Asistencia
    sheet.setColumnAutoFit(7); // Motivo Incidencia
    sheet.setColumnAutoFit(8); // Observaciones
    // Optionally set minimum widths if autofit is too small
    sheet.setColumnWidth(0, 15.0); // Matrícula
    sheet.setColumnWidth(1, 35.0); // Nombre
    sheet.setColumnWidth(2, 12.0); // Grupo
    sheet.setColumnWidth(3, 15.0); // Fecha
    sheet.setColumnWidth(4, 20.0); // Hora Actual E/S
    sheet.setColumnWidth(5, 20.0); // Hora Programada
    sheet.setColumnWidth(6, 15.0); // Asistencia
    sheet.setColumnWidth(7, 30.0); // Motivo Incidencia
    sheet.setColumnWidth(8, 40.0); // Observaciones
      
    excel_lib.Sheet instructionsSheet = excel['INSTRUCCIONES'];
    instructionsSheet.appendRow([excel_lib.TextCellValue('INSTRUCCIONES PARA EL USO DE LA PLANTILLA DE ASISTENCIA')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('Esta plantilla está diseñada para registrar la asistencia de ${type == 'entry' ? 'ENTRADAS' : 'SALIDAS'}.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('Contiene los datos de todos los alumnos activos de este plantel y ciclo escolar.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('COLUMNAS:')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('A: Matrícula del Alumno')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('B: Nombre Completo del Alumno')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('C: Grupo al que pertenece el Alumno')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('D: Fecha (se auto-completa con la fecha actual si está vacía, con formato corto de fecha)')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('E: Hora Actual ${type == 'entry' ? 'Entrada' : 'Salida'} (PARA INSERTAR MANUALMENTE LA HORA. Si está vacía, "Asistencia" será "No")')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('F: Hora Programada (Hora de ${type == 'entry' ? 'entrada' : 'salida'} según el horario del alumno)')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('G: Asistencia (Si/No - basado en si la columna "Hora Actual" tiene un valor)')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('H: Motivo de Incidencia (Escribir el motivo si aplica)')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('I: Observaciones (Para cualquier nota adicional)')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
      
    // Add the formula as an instruction in J2 (or nearby) with different styling
    instructionsSheet.cell(excel_lib.CellIndex.indexByString("J2")).value = excel_lib.TextCellValue('Fórmula Opcional (Columna E):');
    instructionsSheet.cell(excel_lib.CellIndex.indexByString("J2")).cellStyle = excel_lib.CellStyle(bold: true);
    var formulaCellK2 = instructionsSheet.cell(excel_lib.CellIndex.indexByString("K2"));
    formulaCellK2.value = excel_lib.TextCellValue('=SI(A2="", "", SI(E2<>0, E2, AHORA()))');
    formulaCellK2.cellStyle = excel_lib.CellStyle(
      fontColorHex: excel_lib.ExcelColor.fromHexString("#FF5722"), // Orange color
      bold: true,
      italic: true,
    );
      
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('*** IMPORTANTE: HABILITAR CÁLCULO ITERATIVO EN EXCEL ***')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('Para que las fórmulas de "Fecha" (Columna D) y "Asistencia" (Columna G) funcionen correctamente, y si usa la fórmula de "Hora Actual" (Columna E), necesita habilitar el cálculo iterativo en Excel:')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('Pasos para Excel (Windows/macOS):')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('1. Vaya a "Archivo" > "Opciones" (en macOS, "Excel" > "Preferencias").')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('2. Seleccione "Fórmulas".')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('3. En la sección "Opciones de cálculo", marque la casilla "Habilitar cálculo iterativo".')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('4. Asegúrese de que "Iteraciones máximas" esté en 1.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('5. "Cambio máximo" puede dejarse en 0,001 (valor por defecto).')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('Modo de Uso Sugerido:')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('1. Busque al alumno por "Matrícula" (Ctrl+B) o "Nombre" (Ctrl+B).')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('2. Para registrar una asistencia, simplemente edite la celda correspondiente en la columna "Hora Actual ${type == 'entry' ? 'Entrada' : 'Salida'}" (Columna E) o añada una observación en la Columna I. Las celdas "Fecha" (D) y "Asistencia" (G) se auto-actualizarán.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('3. La columna "Asistencia" (G) se actualizará automáticamente a "Si" una vez que la "Hora Actual ${type == 'entry' ? 'Entrada' : 'Salida'}" (E) tenga un valor.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('4. Si desea auto-completar la hora, COPIE la fórmula que se encuentra en la celda K2 de esta hoja (=SI(A2="", "", SI(E2<>0, E2, AHORA()))) y PEGUE como texto en la celda correspondiente de la columna "Hora Actual ${type == 'entry' ? 'Entrada' : 'Salida'}" (E).')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('5. No modifique directamente las celdas de las columnas D y G si ya tienen valores que desea conservar, a menos que entienda el comportamiento de las fórmulas iterativas.')]);
    instructionsSheet.appendRow([excel_lib.TextCellValue('6. Después de registrar las asistencias en la plantilla, puede usar la función "Importar Excel" en la aplicación para subir los datos.')]);

    var fileBytes = excel.save();

    if (fileBytes != null) {
      final String formattedDate = DateFormat('dd_MM_yyyy').format(DateTime.now());
      final String baseName = type == 'entry' ? 'ASISTENCIAS_ENTRADA' : 'ASISTENCIAS_SALIDA';
      final String fileName = '$baseName-$formattedDate.xlsx';

      if (kIsWeb) {
        await WebDownloader.downloadFile(Uint8List.fromList(fileBytes), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        if (context.mounted) {
          UiHelpers.showSnackBar(
              context, 'Archivo guardado en ${directory.path}/$fileName');
        }
      }

      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'Plantilla de ${type == 'entry' ? 'entrada' : 'salida'} generada exitosamente.');
      }
    }
  }

  Future<void> _showImportOptionsDialog() async {
    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(
          context, 'Error: No se ha inicializado el plantel o ciclo escolar.',
          isError: true);
      return;
    }

    String? selectedType; 

    selectedType = await showDialog<String>( 
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo de Plantilla a Importar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Plantilla de Entrada'),
              value: 'entry',
              groupValue: selectedType,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Plantilla de Salida'),
              value: 'exit',
              groupValue: selectedType,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selectedType != null) {
      _importAttendanceFromExcel(selectedType);
    }
  }

  Future<void> _importAttendanceFromExcel(String importType) async {
    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(
          context, 'Error: No se ha inicializado el plantel o ciclo escolar.',
          isError: true);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
        UiHelpers.showSnackBar(context, 'Importando archivo Excel...');

        final bytes = result.files.single.bytes!;
        final excel_lib.Excel excel = excel_lib.Excel.decodeBytes(bytes);
        final sheet = excel.sheets.values.first;

        int importedCount = 0;
        int errorCount = 0;
        List<String> errors = [];

        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          String? studentId = row[2]?.value?.toString().trim();
          String? dateStr = row[3]?.value?.toString().trim();
          String? entryTimeStr = row[4]?.value?.toString().trim();
          String? exitTimeStr = row[5]?.value?.toString().trim();
          String? faltasStr = row[6]?.value?.toString().trim();
          String? observacionIncidenciasStr = row[7]?.value?.toString().trim();

          if (studentId == null || studentId.isEmpty) {
            errors.add('Fila ${i + 1}: Matrícula vacía. Esta fila será omitida.');
            errorCount++;
            continue;
          }
          if (dateStr == null || dateStr.isEmpty) {
            errors.add('Fila ${i + 1}: Fecha vacía para $studentId. Esta fila será omitida.');
            errorCount++;
            continue;
          }
          final Student? student = _studentsMap[studentId];
          if (student == null) {
            errors.add('Fila ${i + 1}: Matrícula "$studentId" no encontrada. Esta fila será omitida.');
            errorCount++;
            continue;
          }
          if (!student.isActive) {
            errors.add('Fila ${i + 1}: Alumno "$studentId" está dado de baja. Esta fila será omitida.');
            errorCount++;
            continue;
          }
          try {
            DateFormat('yyyy-MM-dd').parse(dateStr);
          } catch (_) {
            errors.add('Fila ${i + 1}: Formato de fecha "$dateStr" inválido para $studentId (esperado YYYY-MM-DD). Esta fila será omitida.');
            errorCount++;
            continue;
          }

          if (entryTimeStr != null &&
              entryTimeStr.isNotEmpty &&
              !RegExp(r'^\d{2}:\d{2}$').hasMatch(entryTimeStr)) {
            errors.add('Fila ${i + 1}: Formato de hora de entrada "$entryTimeStr" inválido. Se ignorará.');
            errorCount++;
            entryTimeStr = null;
          }
          if (exitTimeStr != null &&
              exitTimeStr.isNotEmpty &&
              !RegExp(r'^\d{2}:\d{2}$').hasMatch(exitTimeStr)) {
            errors.add('Fila ${i + 1}: Formato de hora de salida "$exitTimeStr" inválido. Se ignorará.');
            errorCount++;
            exitTimeStr = null;
          }

          if ((entryTimeStr == null || entryTimeStr.isEmpty) &&
              (exitTimeStr == null || exitTimeStr.isEmpty) &&
              (faltasStr == null || faltasStr.isEmpty) &&
              (observacionIncidenciasStr == null ||
                  observacionIncidenciasStr.isEmpty)) {
            errors.add('Fila ${i + 1}: No se encontró registro de asistencia ni incidencia para $studentId. Sin cambios.');
            errorCount++;
          }

          try {
            await _processImportedAttendanceRecord(
              student: student,
              date: dateStr,
              entryTime: entryTimeStr,
              exitTime: exitTimeStr,
              faltas: faltasStr,
              observacionIncidencias: observacionIncidenciasStr,
            );
            importedCount++;
          } catch (e) {
            errors.add('Fila ${i + 1}: Error inesperado para $studentId - ${e.toString()}');
            errorCount++;
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          String message =
              'Importación finalizada: $importedCount registros exitosos, $errorCount errores.';
          if (errorCount > 0) {
            UiHelpers.showSnackBar(context, message, isError: true);
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Errores de Importación'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (context, idx) => Text(errors[idx]),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ),
            );
          } else {
            UiHelpers.showSnackBar(context, message);
          }
        }
      } else {
        if (mounted) {
          UiHelpers.showSnackBar(context, 'No se seleccionó ningún archivo.',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        UiHelpers.showSnackBar(context, 'Error al importar Excel: ${e.toString()}',
            isError: true);
      }
    }
  }

  Future<void> _processImportedAttendanceRecord({
    required Student student,
    required String date,
    String? entryTime,
    String? exitTime,
    String? faltas, 
    String? observacionIncidencias, 
  }) async {
    final ConnectivityResult currentConnectivity =
        await _connectivityService.checkConnectivity();

    final DateTime recordDate = DateFormat('yyyy-MM-dd').parse(date);
    final String todayDayOfWeek =
        DateFormat('EEEE', 'es_MX').format(recordDate).toLowerCase();

    Map<String, dynamic> existingRecord = _todayAttendance.firstWhere(
      (rec) => rec['studentId'] == student.studentId && rec['date'] == date,
      orElse: () => <String, dynamic>{},
    );

    final Map<String, dynamic> record =
        Map<String, dynamic>.from(existingRecord);
    record['studentFullName'] = student.fullName;
    record['group'] = student.group;
    record['campusId'] = _campus;
    record['schoolCycle'] = _currentSchoolCycle;
    record['date'] = date;
    record['studentId'] = student.studentId;

    bool isEntryProvided = entryTime != null && entryTime.isNotEmpty;
    bool isExitProvided = exitTime != null && exitTime.isNotEmpty;
    bool isFaltasProvided = faltas != null &&
        faltas.isNotEmpty &&
        (faltas.toLowerCase() == 'si' || faltas == '1');
    bool isObservacionIncidenciasProvided =
        observacionIncidencias != null && observacionIncidencias.isNotEmpty;

    DateTime? scheduledEntry;
    DateTime? scheduledExit;
    final GroupSchedule? groupSchedule = _groupSchedulesMap[student.group];

    final String capitalizedDay = todayDayOfWeek.isNotEmpty
        ? todayDayOfWeek[0].toUpperCase() + todayDayOfWeek.substring(1)
        : todayDayOfWeek;

    List<ClassSession>? todaySessions;
    if (groupSchedule != null) {
      if (groupSchedule.dailySchedules.containsKey(todayDayOfWeek)) {
        todaySessions = groupSchedule.dailySchedules[todayDayOfWeek];
      } else if (groupSchedule.dailySchedules.containsKey(capitalizedDay)) {
        todaySessions = groupSchedule.dailySchedules[capitalizedDay];
      }
    }

    if (todaySessions != null && todaySessions.isNotEmpty) {
      if (true) {
        final earliestSession = todaySessions.reduce(
            (a, b) => a.startTime.compareTo(b.startTime) < 0 ? a : b);
        final latestSession = todaySessions
            .reduce((a, b) => a.endTime.compareTo(b.endTime) > 0 ? a : b);

        try {
          final entryParts = earliestSession.startTime.split(':');
          scheduledEntry = DateTime(recordDate.year, recordDate.month,
              recordDate.day, int.parse(entryParts[0]), int.parse(entryParts[1]));
        } catch (e) {
          debugPrint('Error parsing scheduled entry time: $e');
        }
        try {
          final exitParts = latestSession.endTime.split(':');
          scheduledExit = DateTime(recordDate.year, recordDate.month,
              recordDate.day, int.parse(exitParts[0]), int.parse(exitParts[1]));
        } catch (e) {
          debugPrint('Error parsing scheduled exit time: $e');
        }
      }
    }

    if (isEntryProvided) {
      record['entryTime'] = entryTime;
      if (scheduledEntry != null) {
        final actualEntryTime = DateFormat('HH:mm')
            .parse('$date $entryTime');
        final toleranceLimit =
            scheduledEntry.add(const Duration(minutes: 15)); 

        if (actualEntryTime.isAfter(toleranceLimit)) {
          record['status'] = 'tarde';
          record['reasonTardy'] =
              observacionIncidencias ?? 'Retardo por importación (sin especificar)';
        } else {
          record['status'] = 'presente';
        }
      } else {
        record['status'] = 'presente_importado';
      }
    } else if (isFaltasProvided) {
      record['status'] = 'falta';
      record['reasonFaltas'] =
          observacionIncidencias ?? 'Falta registrada por importación';
    }

    if (isExitProvided) {
      record['exitTime'] = exitTime;
      if (scheduledExit != null) {
        final actualExitTime = DateFormat('HH:mm').parse('$date $exitTime');
        if (actualExitTime.isBefore(scheduledExit)) {
          record['reasonEarlyExit'] = observacionIncidencias ??
              'Salida anticipada por importación (sin especificar)';
        }
      }
    }

    if (isEntryProvided || isExitProvided || isFaltasProvided) {
      if (currentConnectivity == ConnectivityResult.none) {
        final attendanceRecord = AttendanceRecord.fromFirebaseMap(
          student.studentId,
          date,
          record,
          campusId: _campus!,
          schoolCycle: _currentSchoolCycle,
        );
        attendanceRecord.isSynced = false;
        await _hiveService.attendanceRecordsBox
            .put(attendanceRecord.uniqueKey, attendanceRecord);
      } else {
        final attendanceRefForDate = FirebaseDatabase.instance.ref(
            'planteles/$_campus/attendance/$_currentSchoolCycle/$date');
        await attendanceRefForDate.child(student.studentId).set(record);
        final key = '${student.studentId}_$date';
        if (_hiveService.attendanceRecordsBox.containsKey(key)) {
          await _hiveService.attendanceRecordsBox.delete(key);
        }
      }
    }

    if (isObservacionIncidenciasProvided) {
      try {
        final newRef = FirebaseDatabase.instance
            .ref('planteles/$_campus/incidents')
            .push();
        final incidence = Incidence(
          id: newRef.key!,
          studentId: student.studentId,
          studentName: student.fullName,
          group: student.group,
          type: faltas ?? 'General',
          description: observacionIncidencias,
          date: recordDate,
          campusId: _campus!,
          isSynced: currentConnectivity !=
              ConnectivityResult.none,
          schoolCycle: _currentSchoolCycle,
        );
        if (currentConnectivity == ConnectivityResult.none) {
          debugPrint(
              'Incidencia "${incidence.type}" no guardada localmente (Modo Offline).');
          if (mounted) {
            UiHelpers.showSnackBar(context,
                'Incidencia "${incidence.type}" no guardada localmente (Modo Offline). Se guardará al restaurar conexión.',
                isError: true);
          }
        } else {
          await newRef.set(incidence.toFirebaseMap());
        }
      } catch (e) {
        debugPrint('Error saving imported incidence: $e');
        if (mounted) {
          UiHelpers.showSnackBar(context,
              'Error al guardar incidencia importada: ${e.toString()}',
              isError: true);
        }
      }
    }
  }
}