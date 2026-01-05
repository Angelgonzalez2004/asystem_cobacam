import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:asystem_cobacam/widgets/spinning_logo.dart';
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
  final TextEditingController _manualStudentIdController = TextEditingController();

  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;

  DatabaseReference? _attendanceRef;
  DatabaseReference? _studentsRef;
  DatabaseReference? _groupSchedulesRef;

  StreamSubscription<DatabaseEvent>? _attendanceSubscription;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  List<Map<String, dynamic>> _todayAttendance = [];
  Map<String, Student> _studentsMap = {};
  Map<String, List<GroupSchedule>> _groupSchedulesMap = {};
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
    'Enfermedad', 'Cita médica', 'Problemas familiares', 'Tráfico',
    'Transporte público', 'Otro (especificar)',
  ];

  final List<String> _earlyExitReasons = [
    'Enfermedad', 'Cita médica', 'Problemas familiares', 'Emergencia',
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
          _loadStudentsAndSchedules(online: true);
          if (wasOnline) {
             _showSuccessSnackBar('¡Conexión a Internet restablecida! Sincronizando datos...');
          }
        } else {
          _loadStudentsAndSchedules(online: false);
          _showErrorSnackBar(
            '¡Ups! Parece que no hay internet 📡. '
            'No te preocupes, puedes seguir registrando asistencias. '
            'Cuando el internet regrese, tus datos se sincronizarán automáticamente.'
          );
        }
        _loadOfflineAttendanceCount();
      }
    });
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');

      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

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

      _connectivityResult = await _connectivityService.checkConnectivity();

      if (_connectivityResult != ConnectivityResult.none) {
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
        }, onError: (error) {
          if (mounted) _showErrorSnackBar('Error al cargar asistencia: ${error.toString()}');
        });
      } else {
        await _loadTodayAttendanceFromHive();
      }

      _studentsSubscription = _studentsRef!.onValue.listen((event) {
        final newStudentsMap = <String, Student>{};
        if (event.snapshot.exists) {
          for (final child in event.snapshot.children) {
            final student = Student.fromSnapshot(child);
            newStudentsMap[student.studentId] = student;
          }
        }
        if (mounted) setState(() => _studentsMap = newStudentsMap);
      }, onError: (error) {
        if (mounted) _showErrorSnackBar('Error al cargar alumnos: ${error.toString()}');
      });

      _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
        final newGroupSchedulesMap = <String, List<GroupSchedule>>{};
        if (event.snapshot.exists) {
          for (final groupChild in event.snapshot.children) {
            final groupId = groupChild.key!;
            final List<GroupSchedule> schedulesForGroup = [];
            for (final dayChild in groupChild.children) {
              schedulesForGroup.add(GroupSchedule(
                id: dayChild.key!,
                groupId: groupId,
                schoolCycle: _currentSchoolCycle,
                dayOfWeek: dayChild.key!,
                entryTime: (dayChild.value as Map)['entryTime'] ?? '',
                exitTime: (dayChild.value as Map)['exitTime'] ?? '',
              ));
            }
            newGroupSchedulesMap[groupId] = schedulesForGroup;
          }
        }
        if (mounted) setState(() => _groupSchedulesMap = newGroupSchedulesMap);
      }, onError: (error) {
        if (mounted) _showErrorSnackBar('Error al cargar horarios de grupo: ${error.toString()}');
      });
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayAttendanceFromHive() async {
    if (_campus == null || _currentSchoolCycle.isEmpty) return;

    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;

    final List<Map<String, dynamic>> hiveAttendance = attendanceRecordsBox.values
        .where((record) =>
            record.date == _todayDate &&
            record.campusId == _campus &&
            record.schoolCycle == _currentSchoolCycle)
        .map((record) => record.toFirebaseMap()..['studentId'] = record.studentId)
        .toList();

    if (mounted) {
      setState(() {
        _todayAttendance = hiveAttendance;
      });
    }
    if (hiveAttendance.isNotEmpty) {
      if (mounted) _showSuccessSnackBar('Asistencia del día cargada desde caché local.');
    }
  }

  void _combineFirebaseAndHiveAttendance(List<Map<String, dynamic>> firebaseAttendance) async {
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
      }
    }

    if (mounted) {
      setState(() {
        _todayAttendance = combinedAttendance.values.toList();
      });
    }
  }

  Future<void> _loadStudentsAndSchedules({required bool online}) async {
    if (online) {
      // Firebase data sync handled by streams/initData
    } else {
      final studentsBox = _hiveService.studentsBox;
      final groupsBox = _hiveService.groupsBox;
      final groupSchedulesBox = _hiveService.groupSchedulesBox;

      if (studentsBox.isNotEmpty && groupsBox.isNotEmpty && groupSchedulesBox.isNotEmpty) {
        final newStudentsMap = <String, Student>{};
        for (var student in studentsBox.values) {
          newStudentsMap[student.studentId] = student;
        }

        final newGroupSchedulesMap = <String, List<GroupSchedule>>{};
        for (var entry in groupSchedulesBox.toMap().entries) {
          // CORRECCIÓN: Se eliminó el 'if (entry.value is List)' porque es redundante
          newGroupSchedulesMap[entry.key] = List<GroupSchedule>.from(entry.value);
        }
        if (mounted) {
          setState(() {
            _studentsMap = newStudentsMap;
            _groupSchedulesMap = newGroupSchedulesMap;
          });
        }
        if (mounted) _showSuccessSnackBar('Datos maestros cargados desde caché local.');
      } else {
        if (mounted) _showErrorSnackBar('No hay conexión y no hay datos maestros en caché local.');
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _attendanceSubscription?.cancel();
    _studentsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _manualStudentIdController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcodeCapture) {
    if (!_isProcessing || _campus == null || _attendanceRef == null || _studentsRef == null) return;
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
    if (studentId == _lastProcessedStudentId) return;

    setState(() {
      _lastProcessedStudentId = studentId;
      _isProcessing = false;
    });

    if (_nonAttendanceDays.any((day) => DateFormat('yyyy-MM-dd').format(day.date) == _todayDate)) {
      if (mounted) _showErrorSnackBar('Hoy es un día no lectivo, no se registra asistencia.');
      _resumeProcessingAfterDelay();
      return;
    }

    final Student? student = _studentsMap[studentId];
    if (student == null) {
      if (mounted) _showErrorSnackBar('Matrícula "$studentId" no encontrada.');
      _resumeProcessingAfterDelay();
      return;
    }

    Map<String, dynamic> record = _todayAttendance.firstWhere(
      (rec) => rec['studentId'] == studentId && rec['date'] == _todayDate,
      orElse: () => <String, dynamic>{},
    );

    String automaticScanType;
    if (record.containsKey('entryTime')) {
      if (record.containsKey('exitTime')) {
        if (mounted) {
          _showErrorSnackBar(
              '¡Atención! El alumno ${student.fullName} ya tiene registrada su ENTRADA y SALIDA de hoy.');
        }
        _resumeProcessingAfterDelay();
        return;
      }
      automaticScanType = 'exit';
    } else {
      automaticScanType = 'entry';
    }

    if (!mounted) return;
    final result = await _showAttendanceConfirmationDialog(student, automaticScanType);

    if (result != null) {
      await _registerAttendance(student, result['scanType'], record);
    } else {
      if (mounted) _showErrorSnackBar('Registro cancelado.');
    }
    
    _resumeProcessingAfterDelay();
  }

  Future<Map<String, dynamic>?> _showAttendanceConfirmationDialog(Student student, String initialScanType) async {
    String currentScanType = initialScanType;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: const Text('Confirmar Asistencia'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Grupo: ${student.group}'),
                  const SizedBox(height: 24),
                  const Text('Tipo de Registro:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [currentScanType == 'entry', currentScanType == 'exit'],
                    onPressed: (index) {
                      stfSetState(() {
                        currentScanType = index == 0 ? 'entry' : 'exit';
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Entrada')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Salida')),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop({'scanType': currentScanType}),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registerAttendance(Student student, String scanType, Map<String, dynamic> record) async {
    if (_campus == null || _attendanceRef == null) return;
    final String todayDayOfWeek = DateFormat('EEEE', 'es_MX').format(DateTime.now()).toLowerCase();

    final List<GroupSchedule>? schedules = _groupSchedulesMap[student.group];
    final GroupSchedule? currentDaySchedule = schedules?.firstWhere(
      (s) => s.dayOfWeek.toLowerCase() == todayDayOfWeek,
      orElse: () => GroupSchedule(id: '', groupId: '', schoolCycle: '', dayOfWeek: '', entryTime: '', exitTime: ''),
    );

    if (currentDaySchedule == null || currentDaySchedule.entryTime.isEmpty || currentDaySchedule.exitTime.isEmpty) {
      if (mounted) _showErrorSnackBar('No hay horario definido para el grupo ${student.group} hoy ($todayDayOfWeek).');
      return;
    }

    final DateTime now = DateTime.now();
    final String currentTime = DateFormat('HH:mm').format(now);
    final DateTime scheduledEntry = _parseTime(currentDaySchedule.entryTime);
    final DateTime scheduledExit = _parseTime(currentDaySchedule.exitTime);

    try {
      record['studentFullName'] = student.fullName;
      record['group'] = student.group;
      record['campusId'] = _campus;
      record['schoolCycle'] = _currentSchoolCycle;
      record['date'] = _todayDate;
      record['studentId'] = student.studentId;
      
      if (scanType == 'entry') {
        if (record.containsKey('entryTime')) {
          if (mounted) _showErrorSnackBar('Entrada ya registrada para ${student.fullName}.');
          return;
        }
        record['entryTime'] = currentTime;
        record.remove('reasonEarlyExit');

        if (now.isAfter(scheduledEntry.add(const Duration(minutes: 15)))) {
          if (!mounted) return;
          final String? reason = await _showReasonDialog('Motivo de Retardo', _tardyReasons);
          if (reason == null) {
            if (mounted) _showErrorSnackBar('Registro cancelado.');
            return;
          }
          record['status'] = 'tarde';
          record['reasonTardy'] = reason;
        } else {
          record['status'] = 'presente';
          record.remove('reasonTardy');
        }
        if (mounted) _showSuccessSnackBar('Entrada registrada (${record['status']}).');
      } else { // scanType == 'exit'
        if (record.containsKey('exitTime')) {
          if (mounted) _showErrorSnackBar('Salida ya registrada para ${student.fullName}.');
          return;
        }
        if (!record.containsKey('entryTime')) {
          if (mounted) _showErrorSnackBar('Error: Falta registro de entrada.');
          return;
        }
        record['exitTime'] = currentTime;

        if (now.isBefore(scheduledExit)) {
           if (!mounted) return;
           final String? reason = await _showReasonDialog('Motivo de Salida Anticipada', _earlyExitReasons);
           if (reason == null) {
             if (mounted) _showErrorSnackBar('Registro cancelado.');
             return;
           }
           record['reasonEarlyExit'] = reason;
        } else {
           record.remove('reasonEarlyExit');
        }
        if (mounted) _showSuccessSnackBar('Salida registrada.');
      }

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
        if (mounted) _showSuccessSnackBar('Guardado localmente (Offline).');
        _loadOfflineAttendanceCount();
      } else {
        final attendanceRecordRef = _attendanceRef!.child(student.studentId);
        await attendanceRecordRef.set(record);
        if (mounted) _showSuccessSnackBar('Registrado en Firebase.');
        
        final offlineRecordKey = '${student.studentId}_$_todayDate';
        if (_hiveService.attendanceRecordsBox.containsKey(offlineRecordKey)) {
          await _hiveService.attendanceRecordsBox.delete(offlineRecordKey);
          _loadOfflineAttendanceCount();
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error: ${e.toString()}');
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
        _loadOfflineAttendanceCount();
      }
    }
  }

  Future<void> _syncOfflineAttendance() async {
    final ConnectivityResult currentConnectivity = await _connectivityService.checkConnectivity();
    if (currentConnectivity == ConnectivityResult.none) {
      if (mounted) _showErrorSnackBar('Sin conexión para sincronizar.');
      return;
    }

    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;
    final List<AttendanceRecord> unsyncedRecords =
        attendanceRecordsBox.values.where((record) => !record.isSynced).toList();

    if (unsyncedRecords.isEmpty) return;

    if (mounted) _showSuccessSnackBar('Sincronizando ${unsyncedRecords.length} registros...');

    for (final record in unsyncedRecords) {
      try {
        final attendanceRef = FirebaseDatabase.instance.ref(
            'planteles/${record.campusId}/attendance/${record.schoolCycle}/${record.date}');
        await attendanceRef.child(record.studentId).set(record.toFirebaseMap());
        await attendanceRecordsBox.delete(record.uniqueKey);
      } catch (e) {
        if (mounted) _showErrorSnackBar('Error sincronizando ${record.studentFullName}');
      }
    }
    _loadOfflineAttendanceCount();
  }

  Future<void> _loadOfflineAttendanceCount() async {
    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;
    final count = attendanceRecordsBox.values.where((record) => !record.isSynced).length;
    if (mounted) {
      setState(() {
        _offlineRecordsCount = count;
      });
    }
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  void _resumeProcessingAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _lastProcessedStudentId = null;
          _isProcessing = true;
        });
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SpinningLogo(size: 24.0, duration: Duration(seconds: 1)),
            const SizedBox(width: 8.0),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SpinningLogo(size: 24.0, duration: Duration(seconds: 1)),
            const SizedBox(width: 8.0),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<String?> _showReasonDialog(String title, List<String> predefinedReasons) async {
    String? selectedReason;
    final customReasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            void handleReasonSelected(String? value) {
              if (value == null) return;
              stfSetState(() => selectedReason = value);
            }

            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...predefinedReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: handleReasonSelected,
                      );
                    }),
                    if (selectedReason == 'Otro (especificar)')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: TextField(
                          controller: customReasonController,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Motivo específico'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedReason == null) {
                    } else if (selectedReason == 'Otro (especificar)' && customReasonController.text.trim().isEmpty) {
                    } else {
                      final result = selectedReason == 'Otro (especificar)'
                          ? customReasonController.text.trim()
                          : selectedReason;
                      Navigator.of(dialogContext).pop(result);
                    }
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showMassAttendanceDialog() {
    String? attendanceType; 
    String? scope; 
    String? selectedGroupId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            
            Widget stepContent;

            if (attendanceType == null) {
              stepContent = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('¿Qué tipo de registro masivo deseas hacer?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () => stfSetState(() => attendanceType = 'entry'), child: const Text('Entrada Masiva')),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: () => stfSetState(() => attendanceType = 'exit'), child: const Text('Salida Masiva')),
                ],
              );
            } else if (scope == null) {
              stepContent = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Registrar ${attendanceType == 'entry' ? 'Entrada' : 'Salida'} para:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () => stfSetState(() => scope = 'all'), child: const Text('Toda la Escuela')),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: () => stfSetState(() => scope = 'group'), child: const Text('Un Grupo Específico')),
                ],
              );
            } else if (scope == 'group' && selectedGroupId == null) {
              final groups = _groupSchedulesMap.keys.toList();
              // Ordenar grupos alfabéticamente
              groups.sort();
              return AlertDialog(
                 title: const Text('Seleccionar Grupo'),
                 content: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Selecciona un grupo'),
                    value: selectedGroupId,
                    onChanged: (String? newValue) {
                      stfSetState(() => selectedGroupId = newValue);
                    },
                    items: groups.map<DropdownMenuItem<String>>((String groupId) {
                      return DropdownMenuItem<String>(
                        value: groupId,
                        child: Text(groupId),
                      );
                    }).toList(),
                  ),
                  actions: [
                      TextButton(onPressed: () { if (context.mounted) Navigator.of(context).pop(); }, child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: selectedGroupId == null ? null : () {
                          if (!context.mounted) return;
                           Navigator.of(context).pop();
                           _performMassAttendance(attendanceType!, scope: scope!, groupId: selectedGroupId);
                        },
                        child: const Text('Registrar'),
                      ),
                  ]
              );
            } else { 
                Future.microtask(() {
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  _performMassAttendance(attendanceType!, scope: scope!);
                });
                return const Center(child: CircularProgressIndicator());
            }

            return AlertDialog(
              title: const Text('Registro Masivo'),
              content: stepContent,
              actions: [TextButton(onPressed: () { if (context.mounted) Navigator.of(context).pop(); }, child: const Text('Cancelar'))],
            );
          },
        );
      },
    );
  }

  Future<void> _performMassAttendance(String attendanceType, {required String scope, String? groupId}) async {
    if (_attendanceRef == null || _campus == null || _currentSchoolCycle.isEmpty) return;
    
    final currentTime = DateFormat('HH:mm').format(DateTime.now());
    final List<Student> studentsToRegister = [];

    if (scope == 'group' && groupId != null) {
      _studentsMap.forEach((studentId, student) {
        if (student.group == groupId) {
          studentsToRegister.add(student);
        }
      });
    } else { 
      studentsToRegister.addAll(_studentsMap.values);
    }

    if (studentsToRegister.isEmpty) {
      if (mounted) _showErrorSnackBar('No se encontraron alumnos para registrar.');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Registro Masivo'),
        content: Text('¿Estás seguro de que quieres registrar ${attendanceType == 'entry' ? 'la entrada' : 'la salida'} para ${studentsToRegister.length} alumnos?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) _showErrorSnackBar('Registro masivo cancelado.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updates = {};
      
      final String basePath = 'planteles/$_campus/attendance/$_currentSchoolCycle/$_todayDate';

      for (final student in studentsToRegister) {
        final path = '$basePath/${student.studentId}';
        if (attendanceType == 'entry') {
          updates['$path/entryTime'] = currentTime;
          updates['$path/status'] = 'presente_masivo';
          updates['$path/studentFullName'] = student.fullName;
          updates['$path/group'] = student.group;
          updates['$path/campusId'] = _campus;
          updates['$path/schoolCycle'] = _currentSchoolCycle;
          updates['$path/date'] = _todayDate;
        } else { // 'exit'
          updates['$path/exitTime'] = currentTime;
        }
      }
      
      await FirebaseDatabase.instance.ref().update(updates);
      if (mounted) _showSuccessSnackBar('¡Registro masivo completado para ${studentsToRegister.length} alumnos!');

    } catch (e) {
      if (mounted) _showErrorSnackBar('Error durante el registro masivo: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMassAttendanceDialog,
        label: Row(
          children: [
            const Text('Registro Masivo'),
            if (_offlineRecordsCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Chip(
                  label: Text('$_offlineRecordsCount pendientes', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.red,
                ),
              ),
          ],
        ),
        icon: const Icon(Icons.groups),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: _isManualInputMode ? 0 : 3,
                  child: _isManualInputMode
                      ? Container()
                      : MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualStudentIdController,
                              decoration: InputDecoration(
                                labelText: 'Ingresar Matrícula Manualmente',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: () => _processManualStudentId(_manualStudentIdController.text),
                                ),
                              ),
                              onSubmitted: _processManualStudentId,
                            ),
                          ),
                          IconButton(
                            icon: Icon(_isManualInputMode ? Icons.qr_code_scanner : Icons.keyboard),
                            onPressed: () {
                              setState(() {
                                _isManualInputMode = !_isManualInputMode;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_lastProcessedStudentId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Última Matrícula Procesada: $_lastProcessedStudentId', 
                          style: const TextStyle(color: Colors.grey)),
                        )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Asistencia del Día: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _todayAttendance.isEmpty
                      ? const Center(child: Text('No hay registros de asistencia para hoy.'))
                      : ListView.builder(
                          itemCount: _todayAttendance.length,
                          itemBuilder: (context, index) {
                            final record = _todayAttendance[index];
                            final studentFullName = record['studentFullName'] ?? 'N/A';
                            final group = record['group'] ?? 'N/A';
                            final entryTime = record['entryTime'] ?? 'N/A';
                            final exitTime = record['exitTime'] ?? '-';
                            final status = record['status'] ?? 'N/A';
                            final reasonTardy = record['reasonTardy'];
                            final reasonEarlyExit = record['reasonEarlyExit'];

                            String subtitle = 'Entrada: $entryTime | Salida: $exitTime';
                            if (reasonTardy != null) {
                              subtitle += '\nMotivo Retardo: $reasonTardy';
                            }
                            if (reasonEarlyExit != null) {
                              subtitle += '\nMotivo Salida: $reasonEarlyExit';
                            }

                            return ListTile(
                              title: Text('$studentFullName ($group)'),
                              subtitle: Text(subtitle),
                              isThreeLine: reasonTardy != null || reasonEarlyExit != null,
                              trailing: Chip(
                                label: Text(status),
                                backgroundColor: status == 'presente'
                                    ? Colors.green.shade100
                                    : status == 'tarde'
                                        ? Colors.orange.shade100
                                        : status == 'presente_masivo'
                                            ? Colors.lightGreen.shade100
                                            : Colors.red.shade100,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}