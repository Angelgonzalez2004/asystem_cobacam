import 'dart:async';
import 'package:asystem_cobacam/models/class_session_model.dart';

import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/schedule_exporter.dart' as exporter; // Modified
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for ByteData
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:asystem_cobacam/data/educational_centers.dart' as edu_centers; // Corrected import with alias

class TeacherScheduleViewerScreen extends StatefulWidget {
  const TeacherScheduleViewerScreen({super.key});

  @override
  State<TeacherScheduleViewerScreen> createState() =>
      _TeacherScheduleViewerScreenState();
}

class _TeacherScheduleViewerScreenState extends State<TeacherScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;
  final _exporter = exporter.FileExporter(); // Modified
  final _screenshotController = ScreenshotController(); // For single schedule view
  final _multiViewScreenshotController = ScreenshotController(); // New: For multi-schedule view

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  List<Teacher> _teachers = [];
  Teacher? _selectedTeacher;
  Map<String, List<ClassSession>>? _consolidatedSchedule;
  StreamSubscription<DatabaseEvent>? _scheduleSubscription;
  StreamSubscription<DatabaseEvent>? _teachersSubscription; // Added

  bool _isLoading = false;
  bool _isExporting = false;
  String? _campus;
  String? _campusName; // Added
  final Map<String, String> _groupNames = {}; // Cache for group names

  final Map<String, bool> _selectedTeachersForExport = {}; // Added for batch export selection
  bool _selectAllTeachers = false; // Added for batch export selection

  bool _isMultiScheduleView = false; // New state for toggling multi-schedule view
  List<exporter.ScheduleExportData> _multiDisplaySchedules = []; // New list to hold schedules for multi-display

  @override
  void initState() {
    super.initState();
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _initData();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _teachersSubscription?.cancel(); // Added
    super.dispose();
  }

  // Helper function to capture a ScheduleDisplayWidget not currently in the widget tree
  Future<Uint8List?> _captureScheduleWidget(BuildContext context, exporter.ScheduleExportData data) async {
    // Create a ScreenshotController specifically for this capture
    final ScreenshotController tempScreenshotController = ScreenshotController();

    // Create the widget to be captured
    final Widget widgetToCapture = Material( // Wrap in Material to inherit theme, text styles etc.
      child: Theme(
        data: Theme.of(context), // Use the current theme
        child: Directionality(
          textDirection: TextDirection.ltr, // Ensure LTR direction for text
          child: ScheduleDisplayWidget(
            title: data.title,
            subtitle: data.subtitle,
            scheduleData: data.scheduleData,
            viewType: data.viewType,
            mainTitle: data.mainTitle,
            campusName: data.campusName,
            logoPath: data.logoPath,
          ),
        ),
      ),
    );

    // Capture the widget
    return await tempScreenshotController.captureFromWidget(
      widgetToCapture,
      delay: const Duration(milliseconds: 100), // A small delay to ensure widget is fully rendered
      pixelRatio: 2.0, // Higher resolution
      targetSize: const Size(800, 1000), // Max width of parent, approximate height
    );
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

      // Use educationalCenters data to get the campus name
      final campusInfo = edu_centers.getEducationalCenterInfoByPartialName(_campus!);
      _campusName = campusInfo['name']; // Use the name from the lookup

      if (_campusName == 'N/A') throw Exception('No se encontró el nombre del plantel para la clave: $_campus');

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      
      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _selectedSchoolCycle = currentCycleId;
        });
        if (_selectedSchoolCycle != null) {
          await _loadTeachers(); // Load teachers after setting school cycle
        }
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeachers() async {
    if (_campus == null || _selectedSchoolCycle == null) return;

    _teachersSubscription?.cancel(); // Cancel any previous subscription

    setState(() {
      _isLoading = true;
      _teachers = [];
      _selectedTeacher = null; // Reset selected teacher if cycle changes
      _selectedTeachersForExport.clear(); // Clear selection when teachers change
      _selectAllTeachers = false; // Reset select all
    });

    final teachersRef = FirebaseDatabase.instance.ref('planteles/$_campus/school_cycles/$_selectedSchoolCycle/teachers');

    _teachersSubscription = teachersRef.onValue.listen((event) {
      if (!mounted) return;

      final newTeachers = <Teacher>[];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          newTeachers.add(Teacher.fromSnapshot(child));
        }
      }

      setState(() {
        _teachers = newTeachers;
        // Initialize selection for new teachers
        for (var teacher in newTeachers) {
          _selectedTeachersForExport[teacher.id] = false;
        }
        // If the previously selected teacher is no longer in the list, clear it
        if (_selectedTeacher != null && !newTeachers.any((t) => t.id == _selectedTeacher!.id)) {
          _selectedTeacher = null;
          _consolidatedSchedule = null; // Clear schedule if teacher is gone
        }
        _isLoading = false;
      });
    }, onError: (error) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al cargar maestros: ${error.toString()}', isError: true);
      setState(() {
        _isLoading = false;
        _teachers = [];
        _selectedTeacher = null;
        _consolidatedSchedule = null;
      });
    });
  }

  Future<void> _loadScheduleForTeacher(Teacher teacher) async {
    if (_campus == null || _selectedSchoolCycle == null || _selectedTeacher == null) return;

    _scheduleSubscription?.cancel(); // Cancel any previous subscription

    setState(() {
      _isLoading = true;
      _consolidatedSchedule = null;
    });

    final schedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle');

    _scheduleSubscription = schedulesRef.onValue.listen((event) async {
      if (!mounted) return;

      final consolidated = <String, List<ClassSession>>{};

      if (event.snapshot.exists) {
        final allSchedules = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        for (var groupId in allSchedules.keys) {
          final groupSchedule = GroupSchedule.fromSnapshot(event.snapshot.child(groupId));
          final groupName = await _getGroupName(groupId); // Await here
          
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

      setState(() {
        _consolidatedSchedule = consolidated;
        _isLoading = false;
      });
    }, onError: (error) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al cargar horario: ${error.toString()}', isError: true);
      setState(() {
        _isLoading = false;
        _consolidatedSchedule = null;
      });
    });
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
    final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 2.0); // Capture with higher resolution
    if (imageBytes == null) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen.', isError: true);
      setState(() => _isExporting = false);
      return;
    }
    final fileName = 'Horario_${_selectedTeacher!.name.replaceAll(" ", "_")}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
    final success = await _exporter.exportImage(imageBytes, fileName); // Modified
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'Horario guardado en la galería.' : 'Error al exportar imagen.');
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAsPdf() async {
    setState(() => _isExporting = true);
    final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 2.0); // Capture with higher resolution
    if (imageBytes == null) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen para PDF.', isError: true);
      setState(() => _isExporting = false);
      return;
    }
    final fileName = 'Horario_${_selectedTeacher!.name.replaceAll(" ", "_")}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
    final success = await _exporter.exportPdfSingle(imageBytes, fileName); // Modified
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'PDF generado con éxito.' : 'Error al exportar PDF.');
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Visor de Horarios de Maestros'), // Removed to avoid double title
        centerTitle: true,
        leading: _isMultiScheduleView // Show back button only in multi-schedule view
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isMultiScheduleView = false;
                    _multiDisplaySchedules.clear();
                  });
                },
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildControlsCard(),
              if (_isLoading || _campusName == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_isMultiScheduleView) // Only show content if campus name is loaded and not loading
                _buildMultiScheduleView()
              else
                _buildSingleScheduleView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleScheduleView() {
    return _selectedTeacher != null && _consolidatedSchedule != null
        ? Expanded(
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
                      mainTitle: 'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
                      campusName: _campusName ?? 'Desconocido',
                      logoPath: 'assets/images/logo1.png',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildExportButtons(), // Single export buttons
                  const SizedBox(height: 20),
                ],
              ),
            ),
          )
        : const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Selecciona un maestro para ver su horario',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildMultiScheduleView() {
    if (_multiDisplaySchedules.isEmpty) {
      return const Expanded(child: Center(child: Text('No hay horarios seleccionados para mostrar.')));
    }
    return Expanded(
      child: Screenshot(
        controller: _multiViewScreenshotController, // Controller for capturing the whole multi-view
        child: SingleChildScrollView(
          child: Column(
            children: [
              ..._multiDisplaySchedules.map((scheduleData) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ScheduleDisplayWidget(
                    title: scheduleData.title,
                    subtitle: scheduleData.subtitle,
                    scheduleData: scheduleData.scheduleData,
                    viewType: scheduleData.viewType,
                    mainTitle: scheduleData.mainTitle,
                    campusName: scheduleData.campusName,
                    logoPath: scheduleData.logoPath,
                  ),
                );
              }),
              const SizedBox(height: 20),
              _buildMultiViewExportButtons(), // Export buttons specifically for multi-view
              const SizedBox(height: 20),
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
              onChanged: (val) async { // Made onChanged async
                setState(() {
                  _selectedSchoolCycle = val;
                  _consolidatedSchedule = null;
                  _selectedTeacher = null;
                });
                if (val != null) {
                  await _loadTeachers(); // Call _loadTeachers when cycle changes
                }
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
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                emptyBuilder: (context, search) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No se encontraron maestros"),
                  ),
                ),
                searchFieldProps: const TextFieldProps(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: "Buscar maestro...",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Multi-export section
            if (_teachers.isNotEmpty && !_isLoading) ...[
              const Divider(),
              const SizedBox(height: 10),
              Text(
                'Opciones de exportación y visualización',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Seleccionar todos los maestros'),
                value: _selectAllTeachers,
                onChanged: (bool? value) {
                  setState(() {
                    _selectAllTeachers = value ?? false;
                    for (var teacher in _teachers) {
                      _selectedTeachersForExport[teacher.id] = _selectAllTeachers;
                    }
                  });
                },
              ),
              const SizedBox(
                height: 150, // Limit height to avoid overflow
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Teacher selection checkboxes
                        // This section will be populated dynamically based on _teachers
                      ],
                    ),
                  ),
                ),
              ),
              ..._teachers.map((teacher) {
                return CheckboxListTile(
                  title: Text(teacher.name),
                  value: _selectedTeachersForExport[teacher.id] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedTeachersForExport[teacher.id] = value ?? false;
                      // If any is unchecked, "Select all" should be unchecked
                      if (!(_selectedTeachersForExport[teacher.id] ?? false)) {
                        _selectAllTeachers = false;
                      } else if (_selectedTeachersForExport.values.every((element) => element)) {
                        _selectAllTeachers = true;
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _selectedTeachersForExport.values.any((e) => e)
                    ? () async {
                        setState(() => _isExporting = true); // Use _isExporting for feedback
                        final List<Teacher> teachersToView = _teachers.where((teacher) => _selectedTeachersForExport[teacher.id] ?? false).toList();
                        final List<exporter.ScheduleExportData> schedules = [];
                        for (var teacher in teachersToView) {
                          final data = await _getScheduleExportDataForTeacher(teacher);
                          if (data != null) {
                            schedules.add(data);
                          }
                        }
                        setState(() {
                          _multiDisplaySchedules = schedules;
                          _isMultiScheduleView = true;
                          _isExporting = false; // Reset exporting state
                          _selectedTeacher = null; // Clear single selection
                          _consolidatedSchedule = null;
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove_red_eye),
                label: const Text('Ver Seleccionados en Pantalla'),
              ),
              const SizedBox(height: 10),
              _buildBatchExportButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    // These are for single view
    if (_isMultiScheduleView) return const SizedBox.shrink(); // Hide if in multi-view
    if (_isExporting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _selectedTeacher != null ? _exportAsImage : null,
          icon: const Icon(Icons.image),
          label: const Text('Exportar Img (actual)'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedTeacher != null ? _exportAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF (actual)'),
        ),
      ],
    );
  }

  Widget _buildMultiViewExportButtons() {
    final bool anyDisplayed = _multiDisplaySchedules.isNotEmpty;
    if (_isExporting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: anyDisplayed ? _exportMultiViewAsImage : null,
          icon: const Icon(Icons.image),
          label: const Text('Exportar Vista Actual JPG'),
        ),
        ElevatedButton.icon(
          onPressed: anyDisplayed ? _exportMultiViewAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar Vista Actual PDF'),
        ),
      ],
    );
  }

  Widget _buildBatchExportButtons() {
    final bool anySelected = _selectedTeachersForExport.values.any((element) => element);
    if (_isMultiScheduleView) return const SizedBox.shrink(); // Hide if in multi-view
    if (_isExporting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: anySelected ? _exportSelectedTeachersAsImageZip : null,
          icon: const Icon(Icons.image),
          label: const Text('Seleccionados JPG (ZIP)'),
        ),
        ElevatedButton.icon(
          onPressed: _teachers.isNotEmpty ? _exportAllTeachersAsImageZip : null,
          icon: const Icon(Icons.imagesearch_roller),
          label: const Text('Todos JPG (ZIP)'),
        ),
        ElevatedButton.icon(
          onPressed: anySelected ? _exportSelectedTeachersAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Seleccionados PDF'),
        ),
        ElevatedButton.icon(
          onPressed: _teachers.isNotEmpty ? _exportAllTeachersAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Todos PDF'),
        ),
      ],
    );
  }

  // Helper to get ScheduleExportData for a given teacher
  Future<exporter.ScheduleExportData?> _getScheduleExportDataForTeacher(Teacher teacher) async {
    if (_campus == null || _selectedSchoolCycle == null || _campusName == null) return null;

    final consolidated = <String, List<ClassSession>>{};
    final schedulesRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle');
    final schedulesSnapshot = await schedulesRef.once(); // Fetch once for export

    if (schedulesSnapshot.snapshot.exists) {
      final allSchedules = Map<String, dynamic>.from(schedulesSnapshot.snapshot.value as Map);
      
      for (var groupId in allSchedules.keys) {
        final groupSchedule = GroupSchedule.fromSnapshot(schedulesSnapshot.snapshot.child(groupId));
        final groupName = await _getGroupName(groupId);
        
        groupSchedule.dailySchedules.forEach((day, sessions) {
          for (var session in sessions) {
            if (session.teacherId == teacher.id) {
              consolidated.putIfAbsent(day, () => []);
              session.groupName = groupName;
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

    return exporter.ScheduleExportData(
      id: teacher.id,
      name: teacher.name,
      title: 'Horario: ${teacher.name}',
      subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
      scheduleData: consolidated,
      viewType: 'teacher',
      mainTitle: 'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
      campusName: _campusName!,
      logoPath: 'assets/images/logo1.png',
    );
  }

  // New Export functions for multi-view capture
  Future<void> _exportMultiViewAsImage() async {
    setState(() => _isExporting = true);
    final Uint8List? imageBytes = await _multiViewScreenshotController.capture(pixelRatio: 2.0);
    if (imageBytes == null) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la vista de múltiples horarios.', isError: true);
      setState(() => _isExporting = false);
      return;
    }
    final fileName = 'Vista_Horarios_Maestros_${_selectedSchoolCycle!.replaceAll("/", "-")}';
    final success = await _exporter.exportImage(imageBytes, fileName);
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'Vista de horarios guardada en la galería.' : 'Error al exportar imagen.');
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportMultiViewAsPdf() async {
    setState(() => _isExporting = true);
    final Uint8List? imageBytes = await _multiViewScreenshotController.capture(pixelRatio: 2.0);
    if (imageBytes == null) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la vista de múltiples horarios para PDF.', isError: true);
      setState(() => _isExporting = false);
      return;
    }
    final fileName = 'Vista_Horarios_Maestros_${_selectedSchoolCycle!.replaceAll("/", "-")}';
    final success = await _exporter.exportPdfSingle(imageBytes, fileName); // Using single PDF export for the captured multi-view image
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'PDF de la vista de horarios generado con éxito.' : 'Error al exportar PDF.');
      setState(() => _isExporting = false);
    }
  }

  // Batch Export Implementations
  Future<void> _exportSelectedTeachersAsImageZip() async {
    setState(() => _isExporting = true);
    final List<Teacher> teachersToExport = _teachers.where((teacher) => _selectedTeachersForExport[teacher.id] ?? false).toList();
    await _performBatchImageExport(teachersToExport, 'Horarios_Seleccionados_Maestros');
    setState(() => _isExporting = false);
  }

  Future<void> _exportAllTeachersAsImageZip() async {
    setState(() => _isExporting = true);
    await _performBatchImageExport(_teachers, 'Todos_Horarios_Maestros');
    setState(() => _isExporting = false);
  }

  Future<void> _exportSelectedTeachersAsPdf() async {
    setState(() => _isExporting = true);
    final List<Teacher> teachersToExport = _teachers.where((teacher) => _selectedTeachersForExport[teacher.id] ?? false).toList();
    await _performBatchPdfExport(teachersToExport, 'Horarios_Seleccionados_Maestros');
    setState(() => _isExporting = false);
  }

  Future<void> _exportAllTeachersAsPdf() async {
    setState(() => _isExporting = true);
    await _performBatchPdfExport(_teachers, 'Todos_Horarios_Maestros');
    setState(() => _isExporting = false);
  }

  Future<void> _performBatchImageExport(List<Teacher> teachers, String baseFileName) async {
    if (!mounted) return;
    final Map<String, Uint8List> images = {};
    for (var teacher in teachers) {
      final scheduleExportData = await _getScheduleExportDataForTeacher(teacher);
      if (scheduleExportData != null) {
        final imageBytes = await _captureScheduleWidget(context, scheduleExportData);
        if (imageBytes != null) {
          images['${scheduleExportData.name}_Horario.png'] = imageBytes;
        }
      }
    }

    if (images.isNotEmpty) {
      final success = await _exporter.exportImagesToZip(images, baseFileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'Horarios exportados en ZIP.' : 'Error al exportar ZIP.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'No hay horarios para exportar.', isError: true);
    }
  }

  Future<void> _performBatchPdfExport(List<Teacher> teachers, String baseFileName) async {
    if (!mounted) return;
    final List<Uint8List> pdfPages = [];
    for (var teacher in teachers) {
      final scheduleExportData = await _getScheduleExportDataForTeacher(teacher);
      if (scheduleExportData != null) {
        final imageBytes = await _captureScheduleWidget(context, scheduleExportData);
        if (imageBytes != null) {
          pdfPages.add(imageBytes);
        }
      }
    }

    if (pdfPages.isNotEmpty) {
      final success = await _exporter.exportPdfMulti(pdfPages, baseFileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'Horarios exportados en PDF.' : 'Error al exportar PDF.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'No hay horarios para exportar.', isError: true);
    }
  }
}