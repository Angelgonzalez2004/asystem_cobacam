import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class AttendanceQueryScreen extends StatefulWidget {
  const AttendanceQueryScreen({super.key});

  @override
  State<AttendanceQueryScreen> createState() => _AttendanceQueryScreenState();
}

class _AttendanceQueryScreenState extends State<AttendanceQueryScreen> {
  final TextEditingController _studentIdController = TextEditingController();

  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  String? _campusId;
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedQuerySchoolCycle;

  Student? _queriedStudent;
  List<Map<String, dynamic>> _studentAttendanceRecords = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _totalAbsences = 0;
  List<NonAttendanceDay> _nonAttendanceDays = [];

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });
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
      final allCycles = await _appSettingsService.getAllSchoolCycles();
      final nonAttendanceDays =
          await _appSettingsService.getAllNonAttendanceDays(campus);

      if (!mounted) return;
      setState(() {
        _campusId = campus;
        _availableSchoolCycles = allCycles;
        _selectedQuerySchoolCycle = dynamicSchoolCycle;
        _nonAttendanceDays = nonAttendanceDays;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _queryAttendance() async {
    if (_campusId == null || _selectedQuerySchoolCycle == null) {
      UiHelpers.showSnackBar(context, 'Error de configuración del plantel.',
          isError: true);
      return;
    }
    final String studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      UiHelpers.showSnackBar(context, 'Ingresa la matrícula del alumno.',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _queriedStudent = null;
      _studentAttendanceRecords = [];
      _totalAbsences = 0;
    });

    try {
      final studentSnapshot = await FirebaseDatabase.instance
          .ref(
              'planteles/$_campusId/students/$_selectedQuerySchoolCycle/$studentId')
          .get();

      if (!studentSnapshot.exists || studentSnapshot.value == null) {
        if (!mounted) return;
        UiHelpers.showSnackBar(context, 'Matrícula no encontrada.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final student = Student.fromSnapshot(studentSnapshot);

      final attendanceCycleRef = FirebaseDatabase.instance
          .ref('planteles/$_campusId/attendance/$_selectedQuerySchoolCycle');

      final allAttendanceSnapshots = await attendanceCycleRef.get();
      List<Map<String, dynamic>> fetchedRecords = [];
      int absences = 0;

      if (allAttendanceSnapshots.exists &&
          allAttendanceSnapshots.value is Map) {
        final cycleAttendance =
            Map<String, dynamic>.from(allAttendanceSnapshots.value as Map);

        cycleAttendance.forEach((dateKey, dateData) {
          if (dateData != null && dateData.containsKey(studentId)) {
            final studentRecord = dateData[studentId];
            if (studentRecord != null) {
              final record = Map<String, dynamic>.from(studentRecord as Map);
              record['date'] = dateKey;
              fetchedRecords.add(record);

              if (record['status'] == 'ausente') {
                final DateTime attendanceDate =
                    DateFormat('yyyy-MM-dd').parse(dateKey);
                final bool isNonAttendanceDay = _nonAttendanceDays.any((day) =>
                    day.date.year == attendanceDate.year &&
                    day.date.month == attendanceDate.month &&
                    day.date.day == attendanceDate.day);

                if (!isNonAttendanceDay) {
                  absences++;
                }
              }
            }
          }
        });
      }

      // Sort records by date descending
      fetchedRecords.sort((a, b) => b['date'].compareTo(a['date']));

      if (!mounted) return;
      setState(() {
        _queriedStudent = student;
        _studentAttendanceRecords = fetchedRecords;
        _totalAbsences = absences;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al consultar: ${e.toString()}',
            isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Consulta de Asistencia'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Search Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDark
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade200),
                      ),
                      color: isDark ? theme.cardTheme.color : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _studentIdController,
                                    decoration: InputDecoration(
                                      labelText: 'Matrícula',
                                      prefixIcon:
                                          const Icon(Icons.badge_outlined),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                    ),
                                    onSubmitted: (_) => _queryAttendance(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedQuerySchoolCycle,
                                    decoration: InputDecoration(
                                      labelText: 'Ciclo',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                    ),
                                    items: _availableSchoolCycles.map((cycle) {
                                      return DropdownMenuItem(
                                          value: cycle.id,
                                          child: Text(cycle.id));
                                    }).toList(),
                                    onChanged: (val) => setState(
                                        () => _selectedQuerySchoolCycle = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _queryAttendance,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.search),
                              label: const Text('Consultar Historial'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Results Area
                    Expanded(
                      child: _hasSearched && !_isLoading
                          ? _buildResults(theme, isDark)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_queriedStudent == null) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('No se encontró el alumno.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Student Info Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isDark
                  ? BorderSide.none
                  : BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      _queriedStudent!.fullName[0],
                      style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_queriedStudent!.fullName,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            'Grupo: ${_queriedStudent!.group}  •  Matrícula: ${_queriedStudent!.studentId}'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _totalAbsences >= 3
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_totalAbsences Inasistencias',
                            style: TextStyle(
                              color: _totalAbsences >= 3
                                  ? Colors.red.shade800
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Historial de Asistencia',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Attendance List
          Expanded(
            child: _studentAttendanceRecords.isEmpty
                ? Center(
                    child: Text('Sin registros para este ciclo.',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    itemCount: _studentAttendanceRecords.length,
                    itemBuilder: (context, index) {
                      final record = _studentAttendanceRecords[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isDark
                              ? BorderSide.none
                              : BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: theme.colorScheme.secondary),
                          title: Text(DateFormat('EEEE d MMMM, yyyy', 'es_MX')
                              .format(DateTime.parse(record['date']))),
                          subtitle: Text(
                              'Entrada: ${record['entryTime'] ?? '--:--'}  •  Salida: ${record['exitTime'] ?? '--:--'}'),
                          trailing: _buildStatusChip(record['status']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    switch (status) {
      case 'presente':
        color = Colors.green;
        break;
      case 'tarde':
        color = Colors.orange;
        break;
      case 'ausente':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text((status ?? 'N/A').toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
