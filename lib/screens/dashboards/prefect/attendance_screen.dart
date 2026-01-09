import 'dart:async';
import 'package:asystem_cobacam/models/incidence_model.dart'; // Importar modelo
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // REMOVIDO: final TextEditingController _manualStudentIdController... 
  // Ahora usaremos el controller interno del Autocomplete

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
  Map<String, List<GroupSchedule>> _groupSchedulesMap = {};
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
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);

    _initData();

    _connectivitySubscription = _connectivityService.connectivityStream.listen((result) {
      if (mounted) {
        final bool wasOnline = _connectivityResult != ConnectivityResult.none;
        setState(() {
          _connectivityResult = result;
        });
        if (_connectivityResult != ConnectivityResult.none) {
          _syncOfflineAttendance();
          if (!wasOnline) {
             _loadStudentsAndSchedules(online: true);
             if (mounted) {
               UiHelpers.showSnackBar(context, '¡Conexión restablecida! Sincronizando datos...');
             }
          }
        } else {
          _loadStudentsAndSchedules(online: false);
          if (mounted) {
            UiHelpers.showSnackBar(context, 'Modo Offline activado.', isError: true);
          }
        }
        _loadOfflineAttendanceCount();
      }
    });
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');
      
      final prefs = await SharedPreferences.getInstance();

      String? campus;
      try {
        final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (userProfileSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
          campus = userData['campus'];
          if (campus != null) await prefs.setString('cached_campus', campus);
        }
      } catch (e) {
        debugPrint('Error obteniendo perfil online: $e');
      }

      // Si falló Firebase (sin red), usar caché
      campus ??= prefs.getString('cached_campus');

      if (campus == null) {
        throw Exception('El usuario no tiene un plantel asignado o requiere conexión para la primera configuración.');
      }

      final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();
      final fetchedNonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(campus);

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _nonAttendanceDays = fetchedNonAttendanceDays;
        _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      });

      _attendanceRef = FirebaseDatabase.instance.ref('planteles/$_campus/attendance/$_currentSchoolCycle/$_todayDate');
      _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_currentSchoolCycle');
      _groupSchedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/groupSchedules/$_currentSchoolCycle');
      _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');

      _connectivityResult = await _connectivityService.checkConnectivity();
      
      if (_connectivityResult == ConnectivityResult.none) {
         _loadStudentsAndSchedules(online: false);
      }

      _setupFirebaseListeners();
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error inicializando: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      final newGroupSchedulesMap = <String, List<GroupSchedule>>{};
      if (event.snapshot.exists) {
        for (final groupChild in event.snapshot.children) {
          final groupId = groupChild.key!;
          final List<GroupSchedule> schedulesForGroup = [];
          for (final dayChild in groupChild.children) {
            final data = Map<String, dynamic>.from(dayChild.value as Map);
            schedulesForGroup.add(GroupSchedule(
              id: dayChild.key!,
              groupId: groupId,
              schoolCycle: _currentSchoolCycle,
              dayOfWeek: dayChild.key!,
              entryTime: data['entryTime'] ?? '',
              exitTime: data['exitTime'] ?? '',
            ));
          }
          newGroupSchedulesMap[groupId] = schedulesForGroup;
        }
      }
      if (mounted) setState(() => _groupSchedulesMap = newGroupSchedulesMap);
    });

    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!.orderByChild('schoolCycleId').equalTo(_currentSchoolCycle).onValue.listen((event) {
        final List<Group> fetchedGroups = [];
        if (event.snapshot.exists) {
            for (final child in event.snapshot.children) {
              fetchedGroups.add(Group.fromSnapshot(child));
            }
        }
        if (mounted) setState(() => _groups = fetchedGroups);
    });
  }

  void _combineFirebaseAndHiveAttendance(List<Map<String, dynamic>> firebaseAttendance) {
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
        if (record.containsKey('entryTime')) existing['entryTime'] = record['entryTime'];
        if (record.containsKey('exitTime')) existing['exitTime'] = record['exitTime'];
        if (record.containsKey('status')) existing['status'] = record['status'];
        if (record.containsKey('reasonTardy')) existing['reasonTardy'] = record['reasonTardy'];
        if (record.containsKey('reasonEarlyExit')) existing['reasonEarlyExit'] = record['reasonEarlyExit'];
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
           final newGroupSchedulesMap = <String, List<GroupSchedule>>{};
           for (var entry in groupSchedulesBox.toMap().entries) {
              newGroupSchedulesMap[entry.key as String] = List<GroupSchedule>.from(entry.value);
           }
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
    
    // Si hay un borde activo (cooldown visual), ignorar escaneos
    if (_scannerBorderColor != Colors.transparent) {
      return;
    }

    final String? studentId = barcodeCapture.barcodes.first.rawValue;
    if (studentId == null) {
      return;
    }
    _processStudentId(studentId);
  }

  // --- LOGICA DE PROCESAMIENTO ---
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

    if (_currentSchoolCycle.isEmpty) { triggerError('Error: No hay ciclo escolar activo.'); return; }
    
    final dayOfWeek = DateTime.now().weekday;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) { triggerError('Hoy es fin de semana.'); return; }
    
    if (_nonAttendanceDays.any((day) => DateFormat('yyyy-MM-dd').format(day.date) == _todayDate)) { triggerError('Hoy es día no lectivo.'); return; }

    final Student? student = _studentsMap[studentId];
    if (student == null) { triggerError('Matrícula "$studentId" no encontrada.'); return; }
    
    if (!student.isActive) { triggerError('ALUMNO DADO DE BAJA.'); return; }

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

  Future<void> _registerAttendance(Student student, String scanType, Map<String, dynamic> existingRecord) async {
    final String todayDayOfWeek = DateFormat('EEEE', 'es_MX').format(DateTime.now()).toLowerCase();
    
    final List<GroupSchedule>? schedules = _groupSchedulesMap[student.group];
    final GroupSchedule? currentDaySchedule = schedules?.firstWhere(
      (s) => s.dayOfWeek.toLowerCase() == todayDayOfWeek,
      orElse: () => GroupSchedule(id: '', groupId: '', schoolCycle: '', dayOfWeek: '', entryTime: '', exitTime: ''),
    );

    if (currentDaySchedule == null || currentDaySchedule.entryTime.isEmpty) {
      _triggerFeedback(false);
      UiHelpers.showSnackBar(context, 'Grupo ${student.group} sin horario hoy.', isError: true);
      return;
    }

    final DateTime now = DateTime.now();
    final String currentTime = DateFormat('HH:mm').format(now);
    final DateTime scheduledEntry = _parseTime(currentDaySchedule.entryTime);
    final DateTime scheduledExit = _parseTime(currentDaySchedule.exitTime);

    final Map<String, dynamic> record = Map<String, dynamic>.from(existingRecord);
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
      if (scanType == 'entry') record['reasonTardy'] = reason;
      else record['reasonEarlyExit'] = reason;
    }

    _triggerFeedback(true, isWarning: isWarning);

    try {
      final ConnectivityResult currentConnectivity = await _connectivityService.checkConnectivity();
      if (currentConnectivity == ConnectivityResult.none) {
        final attendanceRecord = AttendanceRecord.fromFirebaseMap(
          student.studentId, _todayDate, record, campusId: _campus!, schoolCycle: _currentSchoolCycle,
        );
        attendanceRecord.isSynced = false;
        await _hiveService.attendanceRecordsBox.put(attendanceRecord.uniqueKey, attendanceRecord);
      } else {
        await _attendanceRef!.child(student.studentId).set(record);
        final key = '${student.studentId}_$_todayDate';
        if (_hiveService.attendanceRecordsBox.containsKey(key)) {
           await _hiveService.attendanceRecordsBox.delete(key);
        }
      }
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al guardar.', isError: true);
    }
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
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<String?> _showReasonDialog(String title, List<String> predefinedReasons) async {
    String? selectedReason;
    final customReasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, stfSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...predefinedReasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) => stfSetState(() => selectedReason = val),
                  activeColor: Theme.of(context).primaryColor,
                )),
                if (selectedReason == 'Otro (especificar)')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: customReasonController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Especifica el motivo', border: OutlineInputBorder()),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedReason == null ? null : () {
                final result = selectedReason == 'Otro (especificar)' ? customReasonController.text.trim() : selectedReason;
                if (selectedReason == 'Otro (especificar)' && result!.isEmpty) return;
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
  void _showQuickIncidenceModal(String studentId, String studentName, String group) {
     showModalBottomSheet(
       context: context,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (context) => Container(
         padding: const EdgeInsets.all(24),
         height: 380, // Altura fija cómoda
         child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Reportar Incidencia: $studentName', 
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                 maxLines: 1, overflow: TextOverflow.ellipsis
               ),
               const SizedBox(height: 4),
               Text('Grupo: $group', style: const TextStyle(color: Colors.grey, fontSize: 12)),
               const SizedBox(height: 20),
               Expanded(
                 child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                       _quickIncidenceBtn(studentId, studentName, group, 'Uniforme', Icons.checkroom, Colors.blue),
                       _quickIncidenceBtn(studentId, studentName, group, 'Cabello', Icons.face, Colors.brown),
                       _quickIncidenceBtn(studentId, studentName, group, 'Celular', Icons.phone_android, Colors.purple),
                       _quickIncidenceBtn(studentId, studentName, group, 'Conducta', Icons.gavel, Colors.red),
                       _quickIncidenceBtn(studentId, studentName, group, 'Retardo', Icons.timer_off, Colors.orange),
                       _quickIncidenceBtn(studentId, studentName, group, 'Otro', Icons.edit_note, Colors.grey),
                    ],
                 ),
               )
            ]
         ),
       )
     );
  }

  Widget _quickIncidenceBtn(String sid, String sName, String grp, String type, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Cerrar modal rápido
        _saveQuickIncidence(sid, sName, grp, type);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuickIncidence(String sid, String sName, String grp, String type) async {
    try {
      final newRef = FirebaseDatabase.instance.ref('planteles/$_campus/incidents').push();
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
      );
      // Guardar (Si no hay red, la persistencia de Firebase lo maneja, no necesitamos Hive manual crítico para esto ahora)
      await newRef.set(incidence.toFirebaseMap());
      if (mounted) UiHelpers.showSnackBar(context, '⚠️ Incidencia "$type" registrada.');
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al guardar reporte.', isError: true);
    }
  }

  // --- DASHBOARD WIDGETS ---
  
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMassAttendanceDialog,
        icon: const Icon(Icons.groups_rounded),
        label: Text('Masiva ${_offlineRecordsCount > 0 ? "($_offlineRecordsCount)" : ""}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 1. STATS DASHBOARD
              _buildStatsDashboard(theme),

              // 2. SCANNER / INPUT
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _scannerBorderColor, 
                      width: _scannerBorderColor == Colors.transparent ? 0 : 6
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_scannerBorderColor == Colors.transparent ? 24 : 18),
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
                                Icon(Icons.keyboard_rounded, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                const Text('Modo Manual Activado', style: TextStyle(color: Colors.white70, fontSize: 16)),
                              ],
                            ),
                          ),
                        
                        // Botones Flotantes (Flash y Cámara)
                        if (!_isManualInputMode)
                          Positioned(
                            bottom: 16, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filled(
                                  onPressed: () {
                                    _scannerController.toggleTorch();
                                    setState(() => _isFlashOn = !_isFlashOn);
                                  },
                                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                                  style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                                ),
                                const SizedBox(width: 24),
                                IconButton.filled(
                                  onPressed: () {
                                    _scannerController.switchCamera();
                                    setState(() => _cameraFacing = (_cameraFacing == CameraFacing.back ? CameraFacing.front : CameraFacing.back));
                                  },
                                  icon: const Icon(Icons.cameraswitch_rounded),
                                  style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        
                        // Badge de Ciclo
                        Positioned(
                          top: 16, left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 8),
                                Text(
                                  'Ciclo: $_currentSchoolCycle',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Botón Switch Modo
                        Positioned(
                          top: 16, right: 16,
                          child: IconButton.filled(
                            onPressed: () => setState(() => _isManualInputMode = !_isManualInputMode),
                            icon: Icon(_isManualInputMode ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded),
                            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                          ),
                        ),

                         if (!_isProcessing && _scannerBorderColor == Colors.transparent)
                            const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. MANUAL ENTRY (Buscador Predictivo Mejorado)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
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
                  // VISTA PERSONALIZADA DE RESULTADOS
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
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    option.fullName.isNotEmpty ? option.fullName[0] : '?',
                                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(option.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Matrícula: ${option.studentId} • Grupo: ${option.group}'),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Buscar por Nombre o Matrícula...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    );
                  },
                ),
              ),

              // 4. HISTORIAL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text('Actividad Reciente', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Spacer(),
                  ],
                ),
              ),

              Expanded(
                flex: 3,
                child: _todayAttendance.isEmpty
                  ? Center(child: Text('Sin registros hoy', style: TextStyle(color: theme.hintColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _todayAttendance.length,
                      itemBuilder: (context, index) {
                        final record = _todayAttendance[index];
                        final studentId = record['studentId'] as String;
                        final studentName = record['studentFullName'] as String;
                        final group = record['group'] as String;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                              child: Text(studentName.isNotEmpty ? studentName[0] : '?', style: TextStyle(color: theme.colorScheme.primary, fontSize: 14)),
                            ),
                            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('$studentId • $group', style: const TextStyle(fontSize: 11)),
                            // TRAILING ACTIONS: Hora + Botón de Reporte
                            trailing: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                           if (record['status'] == 'tarde') const Icon(Icons.access_time_filled, color: Colors.orange, size: 14),
                                           if (record['entryTime'] != null) ...[const SizedBox(width: 4), Text(record['entryTime'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green))],
                                           if (record['exitTime'] != null) ...[const Text(' - ', style: TextStyle(fontSize: 10)), Text(record['exitTime'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple))],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  // BOTÓN DE REPORTE RÁPIDO
                                  IconButton(
                                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                    onPressed: () => _showQuickIncidenceModal(studentId, studentName, group),
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
    String? type; // entry, exit
    String? scope; // all, group
    String? groupId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, stfSetState) {
          return AlertDialog(
            title: const Text('Asistencia Masiva'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tipo de Registro:'),
                Row(
                  children: [
                    Expanded(child: ChoiceChip(label: const Text('Entrada'), selected: type == 'entry', onSelected: (v) => stfSetState(() => type = 'entry'))),
                    const SizedBox(width: 8),
                    Expanded(child: ChoiceChip(label: const Text('Salida'), selected: type == 'exit', onSelected: (v) => stfSetState(() => type = 'exit'))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Alcance:'),
                Row(
                  children: [
                    Expanded(child: ChoiceChip(label: const Text('Todo el Plantel'), selected: scope == 'all', onSelected: (v) => stfSetState(() => scope = 'all'))),
                    const SizedBox(width: 8),
                    Expanded(child: ChoiceChip(label: const Text('Por Grupo'), selected: scope == 'group', onSelected: (v) => stfSetState(() => scope = 'group'))),
                  ],
                ),
                if (scope == 'group') ...[
                  const SizedBox(height: 16),
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No hay grupos registrados en este ciclo ($_currentSchoolCycle).',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Selecciona Grupo'),
                      value: groupId,
                      items: _groups
                          .map((group) => DropdownMenuItem(value: group.name, child: Text(group.name)))
                          .toList(),
                      onChanged: (val) => stfSetState(() => groupId = val),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: (type == null || scope == null || (scope == 'group' && groupId == null)) ? null : () {
                  Navigator.pop(context);
                  _performMassiveAttendance(type!, scope!, groupId);
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performMassiveAttendance(String type, String scope, String? gId) async {
    final students = _studentsMap.values.where((s) {
       if (!s.isActive) return false;
       if (scope == 'group') return s.group == gId;
       return true;
    }).toList();

    if (students.isEmpty) {
      UiHelpers.showSnackBar(context, 'No hay alumnos para registrar.', isError: true);
      return;
    }

    // Preguntar por motivo general
    final String? reason = await _showReasonDialog(
      'Motivo General para Registro Masivo ($type)', 
      type == 'entry' ? _tardyReasons : _earlyExitReasons
    );
    
    if (reason == null) return;

    setState(() => _isLoading = true);
    final currentTime = DateFormat('HH:mm').format(DateTime.now());
    
    try {
      final Map<String, dynamic> updates = {};
      for (var s in students) {
        final path = s.studentId;
        final existing = _todayAttendance.firstWhere((rec) => rec['studentId'] == s.studentId, orElse: () => <String, dynamic>{});
        
        final Map<String, dynamic> record = Map<String, dynamic>.from(existing);
        record['studentFullName'] = s.fullName;
        record['group'] = s.group;
        record['campusId'] = _campus;
        record['schoolCycle'] = _currentSchoolCycle;
        record['date'] = _todayDate;
        record['studentId'] = s.studentId;

        if (type == 'entry') {
          record['entryTime'] = currentTime;
          record['status'] = 'presente_masivo';
          record['reasonTardy'] = reason;
        } else {
          record['exitTime'] = currentTime;
          record['reasonEarlyExit'] = reason;
        }
        updates[path] = record;
      }

      await _attendanceRef!.update(updates);
      UiHelpers.showSnackBar(context, 'Asistencia masiva de $type completada para ${students.length} alumnos.');
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error en registro masivo.', isError: true);
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
        final ref = FirebaseDatabase.instance.ref('planteles/${r.campusId}/attendance/${r.schoolCycle}/${r.date}/${r.studentId}');
        await ref.set(r.toFirebaseMap());
        await box.delete(r.uniqueKey);
      } catch (e) {
        debugPrint('Error sync: $e');
      }
    }
    _loadOfflineAttendanceCount();
  }

  Future<void> _loadOfflineAttendanceCount() async {
    final count = _hiveService.attendanceRecordsBox.values.where((r) => !r.isSynced).length;
    if (mounted) setState(() => _offlineRecordsCount = count);
  }
}