import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';

import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/schedule_exporter.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

class TeacherScheduleViewerScreen extends StatefulWidget {
  const TeacherScheduleViewerScreen({super.key});

  @override
  State<TeacherScheduleViewerScreen> createState() =>
      _TeacherScheduleViewerScreenState();
}

class _TeacherScheduleViewerScreenState extends State<TeacherScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;
  final _exporter = ScheduleExporter();
  final _screenshotController = ScreenshotController();

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  List<Teacher> _teachers = [];
  Teacher? _selectedTeacher;
  Map<String, List<ClassSession>>? _consolidatedSchedule;

  bool _isLoading = false;
  bool _isExporting = false;
  String? _campus;
  final Map<String, String> _groupNames = {}; // Cache for group names

  @override
  void initState() {
    super.initState();
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');
      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');

      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      _campus = userData['campus'];
      if (_campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      await _loadTeachers();

      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _selectedSchoolCycle = currentCycleId;
        });
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeachers() async {
    final teachersRef = FirebaseDatabase.instance.ref('teachers');
    final event = await teachersRef.once();
    final newTeachers = <Teacher>[];
    if (event.snapshot.exists) {
      for (final child in event.snapshot.children) {
        newTeachers.add(Teacher.fromSnapshot(child));
      }
    }
    if (mounted) setState(() => _teachers = newTeachers);
  }

  Future<void> _loadScheduleForTeacher(Teacher teacher) async {
    if (_campus == null || _selectedSchoolCycle == null) return;
    setState(() {
      _isLoading = true;
      _consolidatedSchedule = null;
    });

    final consolidated = <String, List<ClassSession>>{};
    final schedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle');
    final schedulesSnapshot = await schedulesRef.once();

    if (schedulesSnapshot.snapshot.exists) {
      final allSchedules = Map<String, dynamic>.from(schedulesSnapshot.snapshot.value as Map);
      
      for (var groupId in allSchedules.keys) {
        final groupSchedule = GroupSchedule.fromSnapshot(schedulesSnapshot.snapshot.child(groupId));
        final groupName = await _getGroupName(groupId);
        
        groupSchedule.dailySchedules.forEach((day, sessions) {
          for (var session in sessions) {
            if (session.teacherId == teacher.id) {
              consolidated.putIfAbsent(day, () => []);
              session.groupName = groupName; // Add group name for display
              consolidated[day]!.add(session);
            }
          }
        });
      }
    }

    // Sort sessions within each day
    consolidated.forEach((day, sessions) {
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    if (mounted) {
      setState(() {
        _consolidatedSchedule = consolidated;
        _isLoading = false;
      });
    }
  }

  Future<String> _getGroupName(String groupId) async {
    if (_groupNames.containsKey(groupId)) {
      return _groupNames[groupId]!;
    }
    final groupRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups/$groupId');
    final event = await groupRef.child('name').once();
    final name = event.snapshot.exists ? event.snapshot.value.toString() : 'N/A';
    _groupNames[groupId] = name;
    return name;
  }

  Future<void> _exportAsImage() async {
    setState(() => _isExporting = true);
    final success = await _exporter.exportToImage(_screenshotController);
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'Horario guardado en la galería.' : 'Error al exportar imagen.');
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAsPdf() async {
    setState(() => _isExporting = true);
    final fileName = 'Horario_${_selectedTeacher?.name.replaceAll(" ", "_")}_${_selectedSchoolCycle?.replaceAll("/", "-")}';
    final success = await _exporter.exportToPdf(_screenshotController, fileName);
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'PDF generado con éxito.' : 'Error al exportar PDF.');
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildControlsCard(),
              if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
              if (!_isLoading && _consolidatedSchedule != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Screenshot(
                          controller: _screenshotController,
                          child: ScheduleDisplayWidget(
                            title: 'Horario: ${_selectedTeacher!.name}',
                            subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
                            scheduleData: _consolidatedSchedule!,
                            viewType: 'teacher',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildExportButtons(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSchoolCycle,
              items: _availableSchoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSchoolCycle = val;
                  _consolidatedSchedule = null;
                  _selectedTeacher = null;
                });
              },
              decoration: const InputDecoration(labelText: 'Ciclo Escolar', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownSearch<Teacher>(
              items: _teachers,
              selectedItem: _selectedTeacher,
              itemAsString: (Teacher t) => t.name,
              onChanged: (Teacher? data) {
                if (data != null) {
                  setState(() => _selectedTeacher = data);
                  _loadScheduleForTeacher(data);
                }
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Seleccionar Maestro',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: "Buscar maestro...",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    if (_isExporting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _exportAsImage,
          icon: const Icon(Icons.image),
          label: const Text('Exportar a Imagen'),
        ),
        ElevatedButton.icon(
          onPressed: _exportAsPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar a PDF'),
        ),
      ],
    );
  }
}
