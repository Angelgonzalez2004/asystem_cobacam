import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
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

class GroupScheduleViewerScreen extends StatefulWidget {
  const GroupScheduleViewerScreen({super.key});

  @override
  State<GroupScheduleViewerScreen> createState() =>
      _GroupScheduleViewerScreenState();
}

class _GroupScheduleViewerScreenState extends State<GroupScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;
  final _exporter = exporter.FileExporter(); // Modified
  final _screenshotController = ScreenshotController(); // For single schedule view
  final _multiViewScreenshotController = ScreenshotController(); // New: For multi-schedule view

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;
  List<Group> _groups = [];
  Group? _selectedGroup;
  GroupSchedule? _schedule;
  StreamSubscription<DatabaseEvent>? _scheduleSubscription; // Added

  bool _isLoading = false;
  bool _isExporting = false;
  String? _campus;
  String? _campusName; // Added

  final Map<String, bool> _selectedGroupsForExport = {}; // Added for batch export selection
  bool _selectAllGroups = false; // Added for batch export selection

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
    // The size should be sufficient to capture the content without cutoff.
    // This might need adjustment based on typical schedule size.
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
      _selectedGroupsForExport.clear(); // Clear selection when groups change
      _selectAllGroups = false; // Reset select all
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
        // Initialize selection for new groups
        for (var group in newGroups) {
          _selectedGroupsForExport[group.key] = false;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadScheduleForGroup(Group group) async {
    if (_campus == null || _selectedSchoolCycle == null || _selectedGroup == null) return;

    _scheduleSubscription?.cancel(); // Cancel any previous subscription

    setState(() => _isLoading = true);

    final scheduleRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle/${group.key}');

    _scheduleSubscription = scheduleRef.onValue.listen((event) {
      if (!mounted) return;

      setState(() {
        if (event.snapshot.exists) {
          _schedule = GroupSchedule.fromSnapshot(event.snapshot);
        } else {
          // Create an empty schedule if none exists
          _schedule = GroupSchedule(id: group.key, groupId: group.key, schoolCycle: _selectedSchoolCycle!, dailySchedules: {});
        }
        _isLoading = false;
      });
    }, onError: (error) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al cargar horario: ${error.toString()}', isError: true);
      setState(() {
        _isLoading = false;
        _schedule = null;
      });
    });
  }

  Future<void> _exportAsImage() async {
    setState(() => _isExporting = true);
    final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 2.0); // Capture with higher resolution
    if (imageBytes == null) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen.', isError: true);
      setState(() => _isExporting = false);
      return;
    }
    final fileName = 'Horario_${_selectedGroup!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
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
    final fileName = 'Horario_${_selectedGroup!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
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
        // title: const Text('Visor de Horarios de Grupo'), // Removed to avoid double title
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
              else if (_isMultiScheduleView)
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
    return _schedule != null
        ? Expanded(
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
                    'Selecciona un grupo para ver su horario',
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
                  prefixIcon: Icon(Icons.groups),
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                emptyBuilder: (context, search) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No se encontraron grupos"),
                  ),
                ),
                searchFieldProps: const TextFieldProps(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: "Buscar grupo...",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Multi-export section
            if (_groups.isNotEmpty && !_isLoading) ...[
              const Divider(),
              const SizedBox(height: 10),
              Text(
                'Opciones de exportación y visualización',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Seleccionar todos los grupos'),
                value: _selectAllGroups,
                onChanged: (bool? value) {
                  setState(() {
                    _selectAllGroups = value ?? false;
                    for (var group in _groups) {
                      _selectedGroupsForExport[group.key] = _selectAllGroups;
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
                        // Group selection checkboxes
                        // This section will be populated dynamically based on _groups
                      ],
                    ),
                  ),
                ),
              ),
              ..._groups.map((group) {
                return CheckboxListTile(
                  title: Text(group.name),
                  value: _selectedGroupsForExport[group.key] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedGroupsForExport[group.key] = value ?? false;
                      // If any is unchecked, "Select all" should be unchecked
                      if (!(_selectedGroupsForExport[group.key] ?? false)) {
                        _selectAllGroups = false;
                      } else if (_selectedGroupsForExport.values.every((element) => element)) {
                        _selectAllGroups = true;
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _selectedGroupsForExport.values.any((e) => e)
                    ? () async {
                        setState(() => _isExporting = true); // Use _isExporting for feedback
                        final List<Group> groupsToView = _groups.where((group) => _selectedGroupsForExport[group.key] ?? false).toList();
                        final List<exporter.ScheduleExportData> schedules = [];
                        for (var group in groupsToView) {
                          final data = await _getScheduleExportDataForGroup(group);
                          if (data != null) {
                            schedules.add(data);
                          }
                        }
                        setState(() {
                          _multiDisplaySchedules = schedules;
                          _isMultiScheduleView = true;
                          _isExporting = false; // Reset exporting state
                          _selectedGroup = null; // Clear single selection
                          _schedule = null;
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
          onPressed: _selectedGroup != null ? _exportAsImage : null,
          icon: const Icon(Icons.image),
          label: const Text('Exportar Img (actual)'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedGroup != null ? _exportAsPdf : null,
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
    final bool anySelected = _selectedGroupsForExport.values.any((element) => element);
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
          onPressed: anySelected ? _exportSelectedGroupsAsImageZip : null,
          icon: const Icon(Icons.image),
          label: const Text('Seleccionados JPG (ZIP)'),
        ),
        ElevatedButton.icon(
          onPressed: _groups.isNotEmpty ? _exportAllGroupsAsImageZip : null,
          icon: const Icon(Icons.imagesearch_roller),
          label: const Text('Todos JPG (ZIP)'),
        ),
        ElevatedButton.icon(
          onPressed: anySelected ? _exportSelectedGroupsAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Seleccionados PDF'),
        ),
        ElevatedButton.icon(
          onPressed: _groups.isNotEmpty ? _exportAllGroupsAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Todos PDF'),
        ),
      ],
    );
  }

  // Helper to get ScheduleExportData for a given group
  Future<exporter.ScheduleExportData?> _getScheduleExportDataForGroup(Group group) async {
    if (_campus == null || _selectedSchoolCycle == null || _campusName == null) return null;

    final scheduleRef = FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$_selectedSchoolCycle/${group.key}');
    final event = await scheduleRef.once(); // Fetch once for export

    GroupSchedule? groupSchedule;
    if (event.snapshot.exists) {
      groupSchedule = GroupSchedule.fromSnapshot(event.snapshot);
    } else {
      groupSchedule = GroupSchedule(id: group.key, groupId: group.key, schoolCycle: _selectedSchoolCycle!, dailySchedules: {});
    }

    return exporter.ScheduleExportData(
      id: group.key,
      name: group.name,
      title: 'Horario: ${group.name}',
      subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
      scheduleData: groupSchedule.dailySchedules,
      viewType: 'group',
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
    final fileName = 'Vista_Horarios_Grupos_${_selectedSchoolCycle!.replaceAll("/", "-")}';
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
    final fileName = 'Vista_Horarios_Grupos_${_selectedSchoolCycle!.replaceAll("/", "-")}';
    final success = await _exporter.exportPdfSingle(imageBytes, fileName); // Using single PDF export for the captured multi-view image
    if (mounted) {
      UiHelpers.showSnackBar(context, success ? 'PDF de la vista de horarios generado con éxito.' : 'Error al exportar PDF.');
      setState(() => _isExporting = false);
    }
  }


  // Batch Export Implementations
  Future<void> _exportSelectedGroupsAsImageZip() async {
    setState(() => _isExporting = true);
    final List<Group> groupsToExport = _groups.where((group) => _selectedGroupsForExport[group.key] ?? false).toList();
    await _performBatchImageExport(groupsToExport, 'Horarios_Seleccionados_Grupos');
    setState(() => _isExporting = false);
  }

  Future<void> _exportAllGroupsAsImageZip() async {
    setState(() => _isExporting = true);
    await _performBatchImageExport(_groups, 'Todos_Horarios_Grupos');
    setState(() => _isExporting = false);
  }

  Future<void> _exportSelectedGroupsAsPdf() async {
    setState(() => _isExporting = true);
    final List<Group> groupsToExport = _groups.where((group) => _selectedGroupsForExport[group.key] ?? false).toList();
    await _performBatchPdfExport(groupsToExport, 'Horarios_Seleccionados_Grupos');
    setState(() => _isExporting = false);
  }

  Future<void> _exportAllGroupsAsPdf() async {
    setState(() => _isExporting = true);
    await _performBatchPdfExport(_groups, 'Todos_Horarios_Grupos');
    setState(() => _isExporting = false);
  }

  Future<void> _performBatchImageExport(List<Group> groups, String baseFileName) async {
    if (!mounted) return;
    final Map<String, Uint8List> images = {};
    for (var group in groups) {
      final scheduleExportData = await _getScheduleExportDataForGroup(group);
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

  Future<void> _performBatchPdfExport(List<Group> groups, String baseFileName) async {
    if (!mounted) return;
    final List<Uint8List> pdfPages = [];
    for (var group in groups) {
      final scheduleExportData = await _getScheduleExportDataForGroup(group);
      if (scheduleExportData != null) {
        final imageBytes = await _captureScheduleWidget(context, scheduleExportData);
        if (imageBytes != null) {
          pdfPages.add(imageBytes);
        }
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay to prevent UI freezing
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