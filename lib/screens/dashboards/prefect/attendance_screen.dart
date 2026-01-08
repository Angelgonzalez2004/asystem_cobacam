import 'dart:async';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
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
  );
  late final AppSettingsService _appSettingsService;
  final TextEditingController _manualStudentIdController =
      TextEditingController();

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
  String? _lastProcessedStudentId;
  bool _isProcessing = true;
  bool _isManualInputMode = false;
  int _offlineRecordsCount = 0;

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
             _loadStudentsAndSchedules(online: true);
             UiHelpers.showSnackBar(context, '¡Conexión restablecida! Sincronizando datos...');
          }
        } else {
          _loadStudentsAndSchedules(online: false);
          UiHelpers.showSnackBar(context, 'Modo Offline activado. Los registros se guardarán localmente.', isError: true);
        }
        _loadOfflineAttendanceCount();
      }
    });
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }

      // Obtener el ciclo actual dinámicamente
      final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();
      final fetchedNonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(campus);

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
      _groupSchedulesRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/groupSchedules/$_currentSchoolCycle');
      _groupsRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/groups');

      _connectivityResult = await _connectivityService.checkConnectivity();

      // Listeners de Firebase
      _setupFirebaseListeners();
      
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
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
        // Combinar datos locales no sincronizados con los de la nube (por si uno tiene entrada y otro salida)
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
        // Ordenar por fecha de última modificación o simplemente el más reciente
        _todayAttendance.sort((a, b) {
           final aTime = a['exitTime'] ?? a['entryTime'] ?? '';
           final bTime = b['exitTime'] ?? b['entryTime'] ?? '';
           return bTime.compareTo(aTime);
        });
      });
    }
  }

  Future<void> _loadStudentsAndSchedules({required bool online}) async {
     // Si estamos online los streams se encargan.
     // Si estamos offline cargamos de Hive.
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
    _manualStudentIdController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcodeCapture) {
    if (!_isProcessing) return;
    final String? studentId = barcodeCapture.barcodes.first.rawValue;
    if (studentId == null) return;
    _processStudentId(studentId);
  }

  void _processManualStudentId(String studentId) {
    if (studentId.isEmpty) return;
    _processStudentId(studentId);
  }

  Future<void> _processStudentId(String studentId) async {
    if (!_isProcessing || _campus == null) return;
    
    // Evitar procesar el mismo ID repetidamente en segundos
    if (studentId == _lastProcessedStudentId) return;

    setState(() {
      _lastProcessedStudentId = studentId;
      _isProcessing = false;
    });

    // Validar Ciclo Actual
    if (_currentSchoolCycle.isEmpty) {
       UiHelpers.showSnackBar(context, 'No se ha detectado el ciclo escolar actual.', isError: true);
       _resumeProcessingAfterDelay();
       return;
    }

    // Validar Fines de Semana (Sábado = 6, Domingo = 7)
    final dayOfWeek = DateTime.now().weekday;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      UiHelpers.showSnackBar(context, 'Hoy es fin de semana. No se toman asistencias sábados y domingos.', isError: true);
      _resumeProcessingAfterDelay();
      return;
    }

    // Validar Día no lectivo
    if (_nonAttendanceDays.any((day) => DateFormat('yyyy-MM-dd').format(day.date) == _todayDate)) {
      UiHelpers.showSnackBar(context, 'Hoy es un día no lectivo. No se permiten registros.', isError: true);
      _resumeProcessingAfterDelay();
      return;
    }

    final Student? student = _studentsMap[studentId];
    if (student == null) {
      UiHelpers.showSnackBar(context, 'Matrícula "$studentId" no encontrada en este plantel.', isError: true);
      _resumeProcessingAfterDelay();
      return;
    }

    if (!student.isActive) {
      UiHelpers.showSnackBar(context, 'EL ALUMNO ESTÁ DADO DE BAJA.', isError: true);
      _resumeProcessingAfterDelay();
      return;
    }

    // Buscar record existente de hoy
    Map<String, dynamic> record = _todayAttendance.firstWhere(
      (rec) => rec['studentId'] == studentId,
      orElse: () => <String, dynamic>{},
    );

    // Detección inteligente de tipo de escaneo (Entrada o Salida)
    String scanType;
    if (!record.containsKey('entryTime')) {
      scanType = 'entry';
    } else if (!record.containsKey('exitTime')) {
      // Si tiene entrada, verificar que no fue hace "muy poco" (ej. 2 minutos) para evitar error de doble escaneo
      // A menos que sea manual
      if (!_isManualInputMode) {
         final entryTimeStr = record['entryTime'] as String;
         final entryTime = _parseTime(entryTimeStr);
         final now = DateTime.now();
         if (now.difference(entryTime).inMinutes < 2) {
            UiHelpers.showSnackBar(
              context, 
              'Asistencia registrada hace un momento.', 
              isError: true,
              duration: const Duration(seconds: 3)
            );
            _resumeProcessingAfterDelay();
            return;
         }
      }
      scanType = 'exit';
    } else {
      // Ya tiene ambos
      UiHelpers.showSnackBar(
        context, 
        'Asistencia registrada hace un momento (Entrada y Salida completas).', 
        isError: true,
        duration: const Duration(seconds: 3)
      );
      _resumeProcessingAfterDelay();
      return;
    }

    await _registerAttendance(student, scanType, record);
    
    _manualStudentIdController.clear();
    _resumeProcessingAfterDelay();
  }

  Future<void> _registerAttendance(Student student, String scanType, Map<String, dynamic> existingRecord) async {
    final String todayDayOfWeek = DateFormat('EEEE', 'es_MX').format(DateTime.now()).toLowerCase();
    
    // Obtener horario del grupo
    final List<GroupSchedule>? schedules = _groupSchedulesMap[student.group];
    final GroupSchedule? currentDaySchedule = schedules?.firstWhere(
      (s) => s.dayOfWeek.toLowerCase() == todayDayOfWeek,
      orElse: () => GroupSchedule(id: '', groupId: '', schoolCycle: '', dayOfWeek: '', entryTime: '', exitTime: ''),
    );

    if (currentDaySchedule == null || currentDaySchedule.entryTime.isEmpty) {
      UiHelpers.showSnackBar(context, 'El grupo ${student.group} no tiene horario registrado para hoy.', isError: true);
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

    if (scanType == 'entry') {
      record['entryTime'] = currentTime;
      
      // Lógica de tolerancia (15 min)
      final toleranceLimit = scheduledEntry.add(const Duration(minutes: 15));
      if (now.isAfter(toleranceLimit)) {
        needsReason = true;
        reasonTitle = 'Motivo de Retardo (Matrícula: ${student.studentId})';
        reasonsList = _tardyReasons;
        record['status'] = 'tarde';
      } else {
        record['status'] = 'presente';
        if (now.isAfter(scheduledEntry)) {
           UiHelpers.showSnackBar(context, 'Asistencia: ${student.fullName} - Tolerancia permitida.');
        } else {
           UiHelpers.showSnackBar(context, 'Asistencia: ${student.fullName} - A tiempo.');
        }
      }
    } else {
      // Exit
      record['exitTime'] = currentTime;
      if (now.isBefore(scheduledExit)) {
        needsReason = true;
        reasonTitle = 'Motivo de Salida Anticipada (${student.studentId})';
        reasonsList = _earlyExitReasons;
      } else {
        UiHelpers.showSnackBar(context, 'Salida: ${student.fullName} registrada.');
      }
    }

    if (needsReason) {
      final String? reason = await _showReasonDialog(reasonTitle, reasonsList);
      if (reason == null) {
        UiHelpers.showSnackBar(context, 'Registro cancelado por falta de motivo.', isError: true);
        return;
      }
      if (scanType == 'entry') {
        record['reasonTardy'] = reason;
      } else {
        record['reasonEarlyExit'] = reason;
      }
    }

    // Guardar
    try {
      final ConnectivityResult currentConnectivity = await _connectivityService.checkConnectivity();
      
      if (currentConnectivity == ConnectivityResult.none) {
        final attendanceRecord = AttendanceRecord.fromFirebaseMap(
          student.studentId,
          _todayDate,
          record,
          campusId: _campus!,
          schoolCycle: _currentSchoolCycle,
        );
        attendanceRecord.isSynced = false;
        await _hiveService.attendanceRecordsBox.put(attendanceRecord.uniqueKey, attendanceRecord);
        UiHelpers.showSnackBar(context, 'Registro guardado localmente (Sin Internet).');
      } else {
        await _attendanceRef!.child(student.studentId).set(record);
        // Si estaba en Hive, marcar como sincronizado o borrar
        final key = '${student.studentId}_$_todayDate';
        if (_hiveService.attendanceRecordsBox.containsKey(key)) {
           await _hiveService.attendanceRecordsBox.delete(key);
        }
      }
      _loadOfflineAttendanceCount();
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error al guardar asistencia.', isError: true);
    }
  }

  void _resumeProcessingAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastProcessedStudentId = null;
          _isProcessing = true;
        });
      }
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
                )),
                if (selectedReason == 'Otro (especificar)')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: customReasonController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Especifica el motivo'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMassAttendanceDialog,
        icon: const Icon(Icons.groups_rounded),
        label: Text('Asistencia Masiva ${_offlineRecordsCount > 0 ? "($_offlineRecordsCount)" : ""}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Scanner / Input Section
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
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
                              const Text('Modo de Entrada Manual', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                      
                      // Badge de Ciclo Actual
                      Positioned(
                        top: 16, left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                'Ciclo: $_currentSchoolCycle',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Overlay info
                      Positioned(
                        top: 16, right: 16,
                        child: IconButton.filledTonal(
                          onPressed: () => setState(() => _isManualInputMode = !_isManualInputMode),
                          icon: Icon(_isManualInputMode ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded),
                        ),
                      ),
                      
                      if (!_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),

              // Manual Entry Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _manualStudentIdController,
                  decoration: InputDecoration(
                    hintText: 'Escribe la matrícula aquí...',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () => _processManualStudentId(_manualStudentIdController.text),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  onSubmitted: _processManualStudentId,
                ),
              ),

              // History Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    Text('Registros de Hoy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: Text('${_todayAttendance.length}', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

              // Attendance History List
              Expanded(
                child: _todayAttendance.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: theme.dividerColor),
                        const SizedBox(height: 8),
                        Text('Esperando registros...', style: TextStyle(color: theme.hintColor)),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _todayAttendance.length,
                      itemBuilder: (context, index) {
                        final record = _todayAttendance[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor.withOpacity(0.05))),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              child: Text(record['studentFullName']?[0] ?? '?', style: TextStyle(color: theme.colorScheme.primary)),
                            ),
                            title: Text(record['studentFullName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('ID: ${record['studentId']} • ${record['group']}', style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (record['entryTime'] != null) 
                                      _buildTimeChip(record['entryTime'], Icons.login_rounded, Colors.green),
                                    const SizedBox(width: 4),
                                    if (record['exitTime'] != null)
                                      _buildTimeChip(record['exitTime'], Icons.logout_rounded, Colors.orange),
                                  ],
                                ),
                                if (record['status'] == 'tarde' || record['reasonEarlyExit'] != null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.info_outline, size: 14, color: Colors.redAccent),
                                  ),
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

  Widget _buildTimeChip(String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(time, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
