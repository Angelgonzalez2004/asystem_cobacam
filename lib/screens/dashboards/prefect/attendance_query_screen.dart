import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart'; // ADDED: Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // ADDED: Import ConnectivityService
import 'package:provider/provider.dart'; // ADDED: Import Provider

class AttendanceQueryScreen extends StatefulWidget {
  const AttendanceQueryScreen({super.key});

  @override
  State<AttendanceQueryScreen> createState() => _AttendanceQueryScreenState();
}

class _AttendanceQueryScreenState extends State<AttendanceQueryScreen> {
  final TextEditingController _studentIdController = TextEditingController();
  
  late final HiveService _hiveService; // ADDED: Declaration
  late final ConnectivityService _connectivityService; // ADDED: Declaration
  late final AppSettingsService _appSettingsService; // MODIFIED: to late final

  String? _campusId;
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedQuerySchoolCycle; // Cycle to query attendance for

  Student? _queriedStudent;
  List<Map<String, dynamic>> _studentAttendanceRecords = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _totalAbsences = 0;
  List<NonAttendanceDay> _nonAttendanceDays = [];

  @override
  void initState() {
    super.initState();
    // ADDED: Initialize services
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      final dynamicSchoolCycle = await _appSettingsService.getCurrentSchoolCycleId();
      final allCycles = await _appSettingsService.getAllSchoolCycles();
      final nonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(campus);

      if (!mounted) return;
      setState(() { 
        _campusId = campus;
        _availableSchoolCycles = allCycles;
        _selectedQuerySchoolCycle = dynamicSchoolCycle; // Default to current global cycle
        _nonAttendanceDays = nonAttendanceDays;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
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
      _showErrorSnackBar('No se pudo determinar el plantel o el ciclo escolar para la consulta.');
      return;
    }
    final String studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa la matrícula del alumno.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _queriedStudent = null;
      _studentAttendanceRecords = [];
      _totalAbsences = 0;
    });

    try {
      // 1. Fetch student details
      final studentSnapshot = await FirebaseDatabase.instance
          .ref('planteles/$_campusId/students/$_selectedQuerySchoolCycle/$studentId')
          .get();

      if (!studentSnapshot.exists || studentSnapshot.value == null) {
        _showErrorSnackBar('Matrícula "$studentId" no encontrada para el ciclo $_selectedQuerySchoolCycle.');
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final student = Student.fromSnapshot(studentSnapshot);

      // 2. Fetch attendance records for the entire selected cycle
      final attendanceCycleRef = FirebaseDatabase.instance
          .ref('planteles/$_campusId/attendance/$_selectedQuerySchoolCycle');
      
      final allAttendanceSnapshots = await attendanceCycleRef.get();
      List<Map<String, dynamic>> fetchedRecords = [];
      int absences = 0;

      if (allAttendanceSnapshots.exists && allAttendanceSnapshots.value is Map) {
        final cycleAttendance = Map<String, dynamic>.from(allAttendanceSnapshots.value as Map);
        
        cycleAttendance.forEach((dateKey, dateData) {
          if (dateData != null && dateData.containsKey(studentId)) {
            final studentRecord = dateData[studentId];
            if (studentRecord != null) {
              final record = Map<String, dynamic>.from(studentRecord as Map);
              record['date'] = dateKey; // Add date to the record for display
              fetchedRecords.add(record);

              // Check for absences
              if (record['status'] == 'ausente') {
                final DateTime attendanceDate = DateFormat('yyyy-MM-dd').parse(dateKey);
                // Only count as absence if it's not a non-attendance day
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

      if (!mounted) return;
      setState(() {
        _queriedStudent = student;
        _studentAttendanceRecords = fetchedRecords;
        _totalAbsences = absences;
        _isLoading = false;
      });

    } catch (e) {
      _showErrorSnackBar('Error al consultar asistencia: ${e.toString()}');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _studentIdController,
                              decoration: const InputDecoration(
                                labelText: 'Matrícula del Alumno',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedQuerySchoolCycle,
                            icon: const Icon(Icons.calendar_today),
                            onChanged: (String? newValue) {
                              if (newValue != null && _campusId != null) {
                                setState(() {
                                  _selectedQuerySchoolCycle = newValue;
                                });
                              }
                            },
                            items: _availableSchoolCycles.map<DropdownMenuItem<String>>((cycle) {
                              return DropdownMenuItem<String>(
                                value: cycle.id,
                                child: Text(cycle.id),
                              );
                            }).toList(),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _queryAttendance,
                            icon: const Icon(Icons.search),
                            label: const Text('Consultar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_hasSearched && _queriedStudent == null)
                        Text('No se encontró información para la matrícula o ciclo escolar seleccionados.', style: TextStyle(color: theme.colorScheme.error)),
                      if (_queriedStudent != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alumno: ${_queriedStudent!.fullName}', style: theme.textTheme.titleLarge),
                                Text('Matrícula: ${_queriedStudent!.studentId}'),
                                Text('Grupo: ${_queriedStudent!.group}'),
                                Text('Ciclo Escolar: ${_queriedStudent!.schoolCycle}'),
                                Text('Tutor: ${_queriedStudent!.guardianFullName}'),
                                Text('Teléfono Tutor: ${_queriedStudent!.guardianPhone}'),
                                if (_queriedStudent!.studentPhone != null && _queriedStudent!.studentPhone!.isNotEmpty)
                                  Text('Teléfono Alumno: ${_queriedStudent!.studentPhone!}'),
                                Text('Género: ${_queriedStudent!.gender}'),
                                Text('Residencia: ${_queriedStudent!.placeOfResidence}'),
                                Text('Email: ${_queriedStudent!.institutionalEmail}'),
                                const SizedBox(height: 10),
                                Text('Total de Inasistencias: $_totalAbsences', style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _totalAbsences >= 3 ? Colors.red.shade700 : Colors.green.shade700,
                                )),
                                if (_totalAbsences >= 3)
                                  Text('¡Alerta: El alumno tiene 3 o más inasistencias!', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      if (_queriedStudent != null && _studentAttendanceRecords.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: _studentAttendanceRecords.length,
                            itemBuilder: (context, index) {
                              final record = _studentAttendanceRecords[index];
                              final date = record['date'] ?? 'N/A';
                              final entryTime = record['entryTime'] ?? 'N/A';
                              final exitTime = record['exitTime'] ?? '-';
                              final status = record['status'] ?? 'N/A';

                              return ListTile(
                                title: Text('Fecha: $date'),
                                subtitle: Text('Entrada: $entryTime | Salida: $exitTime'),
                                trailing: Chip(
                                  label: Text(status),
                                  backgroundColor: status == 'presente' ? Colors.green.shade100 :
                                                   status == 'tarde' ? Colors.orange.shade100 : Colors.red.shade100,
                                ),
                              );
                            },
                          ),
                        )
                      else if (_queriedStudent != null && _studentAttendanceRecords.isEmpty)
                        const Text('No hay registros de asistencia para este alumno en el ciclo seleccionado.'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
