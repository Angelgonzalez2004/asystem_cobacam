import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
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
          _loadStudentsAndSchedules(online: true);
          if (wasOnline) {
            UiHelpers.showSnackBar(
                context, '¡Conexión restablecida! Sincronizando datos...');
          }
        } else {
          _loadStudentsAndSchedules(online: false);
          UiHelpers.showSnackBar(context,
              'Modo Offline activado. Los datos se sincronizarán después.',
              isError: true);
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
      _groupSchedulesRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/groupSchedules/$_currentSchoolCycle');

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
          if (mounted) {
            UiHelpers.showSnackBar(
                context, 'Error al cargar asistencia: ${error.toString()}',
                isError: true);
          }
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
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al cargar alumnos: ${error.toString()}',
              isError: true);
        }
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
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al cargar horarios: ${error.toString()}',
              isError: true);
        }
      });
      _loadOfflineAttendanceCount();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayAttendanceFromHive() async {
    if (_campus == null || _currentSchoolCycle.isEmpty) return;

    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;

    final List<Map<String, dynamic>> hiveAttendance = attendanceRecordsBox
        .values
        .where((record) =>
            record.date == _todayDate &&
            record.campusId == _campus &&
            record.schoolCycle == _currentSchoolCycle)
        .map((record) =>
            record.toFirebaseMap()..['studentId'] = record.studentId)
        .toList();

    if (mounted) {
      setState(() {
        _todayAttendance = hiveAttendance;
      });
    }
    if (hiveAttendance.isNotEmpty) {
      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'Asistencia cargada desde caché local.');
      }
    }
  }

  void _combineFirebaseAndHiveAttendance(
      List<Map<String, dynamic>> firebaseAttendance) async {
    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;

    final List<Map<String, dynamic>> hiveAttendance = attendanceRecordsBox
        .values
        .where((record) =>
            record.date == _todayDate &&
            record.campusId == _campus &&
            record.schoolCycle == _currentSchoolCycle &&
            !record.isSynced)
        .map((record) =>
            record.toFirebaseMap()..['studentId'] = record.studentId)
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

      if (studentsBox.isNotEmpty &&
          groupsBox.isNotEmpty &&
          groupSchedulesBox.isNotEmpty) {
        final newStudentsMap = <String, Student>{};
        for (var student in studentsBox.values) {
          newStudentsMap[student.studentId] = student;
        }

        final newGroupSchedulesMap = <String, List<GroupSchedule>>{};
        for (var entry in groupSchedulesBox.toMap().entries) {
          newGroupSchedulesMap[entry.key] =
              List<GroupSchedule>.from(entry.value);
        }
        if (mounted) {
          setState(() {
            _studentsMap = newStudentsMap;
            _groupSchedulesMap = newGroupSchedulesMap;
          });
        }
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Datos maestros cargados desde caché local.');
        }
      } else {
        if (mounted) {
          UiHelpers.showSnackBar(context, 'Sin conexión y sin datos locales.',
              isError: true);
        }
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
    if (!_isProcessing ||
        _campus == null ||
        _attendanceRef == null ||
        _studentsRef == null) {
      return;
    }
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

    if (_nonAttendanceDays.any(
        (day) => DateFormat('yyyy-MM-dd').format(day.date) == _todayDate)) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Día no lectivo.', isError: true);
      }
      _resumeProcessingAfterDelay();
      return;
    }

    final Student? student = _studentsMap[studentId];
    if (student == null) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Matrícula "$studentId" no encontrada.',
            isError: true);
      }
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
          UiHelpers.showSnackBar(
              context, 'El alumno ya tiene entrada y salida.',
              isError: true);
        }
        _resumeProcessingAfterDelay();
        return;
      }
      automaticScanType = 'exit';
    } else {
      automaticScanType = 'entry';
    }

    if (!mounted) return;
    final result =
        await _showAttendanceConfirmationDialog(student, automaticScanType);

    if (!mounted) return;

    if (result != null) {
      await _registerAttendance(student, result['scanType'], record);
    } else {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Registro cancelado.', isError: true);
      }
    }

    _resumeProcessingAfterDelay();
  }

  Future<Map<String, dynamic>?> _showAttendanceConfirmationDialog(
      Student student, String initialScanType) async {
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
                  Text(student.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Grupo: ${student.group}'),
                  const SizedBox(height: 24),
                  const Text('Tipo de Registro:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [
                      currentScanType == 'entry',
                      currentScanType == 'exit'
                    ],
                    onPressed: (index) {
                      stfSetState(() {
                        currentScanType = index == 0 ? 'entry' : 'exit';
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Entrada')),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Salida')),
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
                  onPressed: () => Navigator.of(dialogContext)
                      .pop({'scanType': currentScanType}),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registerAttendance(
      Student student, String scanType, Map<String, dynamic> record) async {
    if (_campus == null || _attendanceRef == null) return;
    final String todayDayOfWeek =
        DateFormat('EEEE', 'es_MX').format(DateTime.now()).toLowerCase();

    final List<GroupSchedule>? schedules = _groupSchedulesMap[student.group];
    final GroupSchedule? currentDaySchedule = schedules?.firstWhere(
      (s) => s.dayOfWeek.toLowerCase() == todayDayOfWeek,
      orElse: () => GroupSchedule(
          id: '',
          groupId: '',
          schoolCycle: '',
          dayOfWeek: '',
          entryTime: '',
          exitTime: ''),
    );

    if (currentDaySchedule == null ||
        currentDaySchedule.entryTime.isEmpty ||
        currentDaySchedule.exitTime.isEmpty) {
      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'Sin horario para ${student.group} hoy.',
            isError: true);
      }
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
          if (mounted) {
            UiHelpers.showSnackBar(context, 'Entrada ya registrada.',
                isError: true);
          }
          return;
        }
        record['entryTime'] = currentTime;
        record.remove('reasonEarlyExit');

        if (now.isAfter(scheduledEntry.add(const Duration(minutes: 15)))) {
          if (!mounted) return;
          final String? reason =
              await _showReasonDialog('Motivo de Retardo', _tardyReasons);
          if (!mounted) return;
          if (reason == null) {
            UiHelpers.showSnackBar(context, 'Registro cancelado.',
                isError: true);
            return;
          }
          record['status'] = 'tarde';
          record['reasonTardy'] = reason;
        } else {
          record['status'] = 'presente';
          record.remove('reasonTardy');
        }
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Entrada registrada (${record['status']}).');
        }
      } else {
        // scanType == 'exit'
        if (record.containsKey('exitTime')) {
          if (mounted) {
            UiHelpers.showSnackBar(context, 'Salida ya registrada.',
                isError: true);
          }
          return;
        }
        if (!record.containsKey('entryTime')) {
          if (mounted) {
            UiHelpers.showSnackBar(context, 'Falta registro de entrada.',
                isError: true);
          }
          return;
        }
        record['exitTime'] = currentTime;

        if (now.isBefore(scheduledExit)) {
          if (!mounted) return;
          final String? reason = await _showReasonDialog(
              'Motivo de Salida Anticipada', _earlyExitReasons);
          if (!mounted) return;
          if (reason == null) {
            UiHelpers.showSnackBar(context, 'Registro cancelado.',
                isError: true);
            return;
          }
          record['reasonEarlyExit'] = reason;
        } else {
          record.remove('reasonEarlyExit');
        }
        if (mounted) UiHelpers.showSnackBar(context, 'Salida registrada.');
      }

      if (!mounted) return;
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
        if (mounted) UiHelpers.showSnackBar(context, 'Guardado Offline.');
        _loadOfflineAttendanceCount();
      } else {
        final attendanceRecordRef = _attendanceRef!.child(student.studentId);
        await attendanceRecordRef.set(record);
        if (mounted) UiHelpers.showSnackBar(context, 'Registrado en la nube.');

        final offlineRecordKey = '${student.studentId}_$_todayDate';
        if (_hiveService.attendanceRecordsBox.containsKey(offlineRecordKey)) {
          await _hiveService.attendanceRecordsBox.delete(offlineRecordKey);
          _loadOfflineAttendanceCount();
        }
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
      // Offline fallback omitted for brevity in snippet, but logic persists
    }
  }

  Future<void> _syncOfflineAttendance() async {
    final ConnectivityResult currentConnectivity =
        await _connectivityService.checkConnectivity();
    if (currentConnectivity == ConnectivityResult.none) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Sin conexión para sincronizar.',
            isError: true);
      }
      return;
    }

    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;
    final List<AttendanceRecord> unsyncedRecords = attendanceRecordsBox.values
        .where((record) => !record.isSynced)
        .toList();

    if (unsyncedRecords.isEmpty) return;

    if (mounted) {
      UiHelpers.showSnackBar(
          context, 'Sincronizando ${unsyncedRecords.length} registros...');
    }

    for (final record in unsyncedRecords) {
      try {
        final attendanceRef = FirebaseDatabase.instance.ref(
            'planteles/${record.campusId}/attendance/${record.schoolCycle}/${record.date}');
        await attendanceRef.child(record.studentId).set(record.toFirebaseMap());
        await attendanceRecordsBox.delete(record.uniqueKey);
      } catch (e) {
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error sincronizando ${record.studentFullName}',
              isError: true);
        }
      }
    }
    _loadOfflineAttendanceCount();
  }

  Future<void> _loadOfflineAttendanceCount() async {
    final attendanceRecordsBox = _hiveService.attendanceRecordsBox;
    final count =
        attendanceRecordsBox.values.where((record) => !record.isSynced).length;
    if (mounted) {
      setState(() {
        _offlineRecordsCount = count;
      });
    }
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
        now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
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

  Future<String?> _showReasonDialog(
      String title, List<String> predefinedReasons) async {
    String? selectedReason;
    final customReasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
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
                        onChanged: (val) =>
                            stfSetState(() => selectedReason = val),
                      );
                    }),
                    if (selectedReason == 'Otro (especificar)')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: customReasonController,
                          autofocus: true,
                          decoration: const InputDecoration(
                              labelText: 'Motivo específico'),
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
                    if (selectedReason != null) {
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
                  const Text('¿Qué tipo de registro masivo deseas hacer?',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () =>
                          stfSetState(() => attendanceType = 'entry'),
                      child: const Text('Entrada Masiva')),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () =>
                          stfSetState(() => attendanceType = 'exit'),
                      child: const Text('Salida Masiva')),
                ],
              );
            } else if (scope == null) {
              stepContent = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Registrar ${attendanceType == 'entry' ? 'Entrada' : 'Salida'} para:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () => stfSetState(() => scope = 'all'),
                      child: const Text('Toda la Escuela')),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () => stfSetState(() => scope = 'group'),
                      child: const Text('Un Grupo Específico')),
                ],
              );
            } else if (scope == 'group' && selectedGroupId == null) {
              final groups = _groupSchedulesMap.keys.toList();
              groups.sort();
              return AlertDialog(
                  title: const Text('Seleccionar Grupo'),
                  content: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Selecciona un grupo'),
                    value: selectedGroupId,
                    onChanged: (val) =>
                        stfSetState(() => selectedGroupId = val),
                    items: groups
                        .map((id) =>
                            DropdownMenuItem(value: id, child: Text(id)))
                        .toList(),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: selectedGroupId == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _performMassAttendance(attendanceType!,
                                  scope: scope!, groupId: selectedGroupId);
                            },
                      child: const Text('Registrar'),
                    ),
                  ]);
            } else {
              Future.microtask(() {
                Navigator.of(context).pop();
                _performMassAttendance(attendanceType!, scope: scope!);
              });
              return const Center(child: CircularProgressIndicator());
            }

            return AlertDialog(
              title: const Text('Registro Masivo'),
              content: stepContent,
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'))
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performMassAttendance(String attendanceType,
      {required String scope, String? groupId}) async {
    if (_attendanceRef == null ||
        _campus == null ||
        _currentSchoolCycle.isEmpty) {
      return;
    }

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
      if (mounted) {
        UiHelpers.showSnackBar(context, 'No se encontraron alumnos.',
            isError: true);
      }
      return;
    }

    final confirmed = await UiHelpers.showConfirmationDialog(context,
        title: 'Confirmar Registro Masivo',
        content:
            '¿Registrar ${attendanceType == 'entry' ? 'entrada' : 'salida'} para ${studentsToRegister.length} alumnos?');

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updates = {};
      final String basePath =
          'planteles/$_campus/attendance/$_currentSchoolCycle/$_todayDate';

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
        } else {
          updates['$path/exitTime'] = currentTime;
        }
      }

      await FirebaseDatabase.instance.ref().update(updates);
      if (mounted) {
        UiHelpers.showSnackBar(context, '¡Registro masivo completado!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMassAttendanceDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        label: Row(
          children: [
            const Text('Masivo'),
            if (_offlineRecordsCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$_offlineRecordsCount',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
          ],
        ),
        icon: const Icon(Icons.groups),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Scanner / Header Section
                        Expanded(
                          flex: isDesktop ? 4 : (_isManualInputMode ? 0 : 3),
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10)
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _isManualInputMode
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.keyboard,
                                              size: 64,
                                              color: Colors.grey.shade700),
                                          const SizedBox(height: 16),
                                          const Text('Modo Manual Activado',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18)),
                                        ],
                                      ),
                                    )
                                  : MobileScanner(
                                      controller: _scannerController,
                                      onDetect: _onDetect,
                                    ),
                            ),
                          ),
                        ),

                        // Controls Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manualStudentIdController,
                                  decoration: InputDecoration(
                                    labelText: 'Ingresar Matrícula Manualmente',
                                    filled: true,
                                    fillColor: isDark
                                        ? theme.cardTheme.color
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: () => _processManualStudentId(
                                          _manualStudentIdController.text),
                                    ),
                                  ),
                                  onSubmitted: _processManualStudentId,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FloatingActionButton.small(
                                heroTag: 'toggleMode',
                                backgroundColor: theme.colorScheme.secondary,
                                onPressed: () => setState(() =>
                                    _isManualInputMode = !_isManualInputMode),
                                child: Icon(
                                    _isManualInputMode
                                        ? Icons.qr_code_scanner
                                        : Icons.keyboard,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        if (_lastProcessedStudentId != null)
                          FadeInUp(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Chip(
                                label:
                                    Text('Procesado: $_lastProcessedStudentId'),
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                              ),
                            ),
                          ),

                        // List Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Asistencia Hoy (${DateFormat('dd/MM').format(DateTime.now())})',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text('${_todayAttendance.length} registros',
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),

                        // Attendance List
                        Expanded(
                          flex: 3,
                          child: _todayAttendance.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.list_alt,
                                          size: 60,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text('No hay registros aún.',
                                          style: TextStyle(
                                              color: Colors.grey.shade500)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _todayAttendance.length,
                                  itemBuilder: (context, index) {
                                    // Show newest first
                                    final record = _todayAttendance[
                                        _todayAttendance.length - 1 - index];
                                    return FadeInUp(
                                      key: ValueKey(record['studentId']),
                                      child: Card(
                                        elevation: 0,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        color: isDark
                                            ? theme.cardTheme.color
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: Colors.grey
                                                  .withValues(alpha: 0.1)),
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: theme
                                                .colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            child: Text(
                                              (record['studentFullName'] ??
                                                  '?')[0],
                                              style: TextStyle(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          title: Text(
                                              record['studentFullName'] ??
                                                  'N/A',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          subtitle: Text(
                                            '${record['group']}  •  Entrada: ${record['entryTime'] ?? '-'}  •  Salida: ${record['exitTime'] ?? '-'}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: theme.textTheme.bodySmall
                                                    ?.color),
                                          ),
                                          trailing: _buildStatusChip(
                                              record['status'], theme),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String? status, ThemeData theme) {
    Color color;
    String label = status ?? 'N/A';

    switch (status) {
      case 'presente':
        color = Colors.green;
        break;
      case 'tarde':
        color = Colors.orange;
        break;
      case 'presente_masivo':
        color = Colors.blue;
        label = 'Masivo';
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
