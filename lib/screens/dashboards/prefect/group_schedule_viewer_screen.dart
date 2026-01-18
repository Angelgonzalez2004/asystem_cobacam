import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
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

class GroupScheduleViewerScreen extends StatefulWidget {
  const GroupScheduleViewerScreen({super.key});

  @override
  State<GroupScheduleViewerScreen> createState() =>
      _GroupScheduleViewerScreenState();
}

class _GroupScheduleViewerScreenState extends State<GroupScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;
  final _exporter = ScheduleExporter();
  final _screenshotController = ScreenshotController();

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  List<Group> _groups = [];
  Group? _selectedGroup;
  GroupSchedule? _schedule;

  bool _isLoading = false;
  bool _isExporting = false;
  String? _campus;

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
      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _selectedSchoolCycle = currentCycleId;
        });
        if (_selectedSchoolCycle != null) {
          await _loadGroupsForCycle(_selectedSchoolCycle!);
        }
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupsForCycle(String cycleId) async {
    if (_campus == null) return;
    setState(() {
      _isLoading = true;
      _groups = [];
      _selectedGroup = null;
      _schedule = null;
    });

    final groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    final event = await groupsRef.orderByChild('schoolCycleId').equalTo(cycleId).once();
    final newGroups = <Group>[];
    if (event.snapshot.exists) {
      for (final child in event.snapshot.children) {
        newGroups.add(Group.fromSnapshot(child));
      }
    }
    if (mounted) {
      setState(() {
        _groups = newGroups;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadScheduleForGroup(Group group) async {
    if (_campus == null || _selectedSchoolCycle == null) return;
    setState(() => _isLoading = true);

    final scheduleRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle/${group.key}');
    final event = await scheduleRef.once();
    if (mounted) {
      setState(() {
        if (event.snapshot.exists) {
          _schedule = GroupSchedule.fromSnapshot(event.snapshot);
        } else {
          // Create an empty schedule if none exists
          _schedule = GroupSchedule(id: group.key, groupId: group.key, schoolCycle: _selectedSchoolCycle!, dailySchedules: {});
        }
        _isLoading = false;
      });
    }
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
    final fileName = 'Horario_${_selectedGroup?.name}_${_selectedSchoolCycle?.replaceAll("/", "-")}';
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
              if (!_isLoading && _schedule != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Screenshot(
                          controller: _screenshotController,
                          child: ScheduleDisplayWidget(
                            title: 'Horario: ${_selectedGroup!.name}',
                            subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
                            scheduleData: _schedule!.dailySchedules,
                            viewType: 'group',
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
                if (val != null) {
                  setState(() => _selectedSchoolCycle = val);
                  _loadGroupsForCycle(val);
                }
              },
              decoration: const InputDecoration(labelText: 'Ciclo Escolar', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownSearch<Group>(
              items: _groups,
              selectedItem: _selectedGroup,
              itemAsString: (Group g) => g.name,
              onChanged: (Group? data) {
                if (data != null) {
                  setState(() => _selectedGroup = data);
                  _loadScheduleForGroup(data);
                }
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Seleccionar Grupo',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: "Buscar grupo...",
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
