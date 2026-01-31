// Imports
import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/schedule_display_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart'; // For capturing widgets
import 'package:asystem_cobacam/utils/schedule_exporter.dart' as exporter; // Alias to avoid name conflicts
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

import 'package:asystem_cobacam/data/educational_centers.dart' as edu_centers; // For campus name lookup


class GroupScheduleViewerScreen extends StatefulWidget {
  const GroupScheduleViewerScreen({super.key});

  @override
  State<GroupScheduleViewerScreen> createState() =>
      _GroupScheduleViewerScreenState();
}

class _GroupScheduleViewerScreenState extends State<GroupScheduleViewerScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  DatabaseReference? _groupsRef;
  DatabaseReference? _groupSchedulesRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _groupSchedulesSubscription;

  List<Group> _allGroups = [];
  List<Group> _filteredGroups = [];
  Map<String, GroupSchedule> _groupSchedules = {};

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;

  bool _isLoading = true;
  String? _campus;
  String? _campusName; // Added for ScheduleDisplayWidget

  final TextEditingController _searchController = TextEditingController();

  // Export related state and controllers
  final exporter.FileExporter _fileExporter = exporter.FileExporter();
  final ScreenshotController _screenshotController = ScreenshotController(); // For single schedule view capture
  final ScreenshotController _multiViewScreenshotController = ScreenshotController(); // For multi-schedule view capture

  Group? _selectedGroup; // For single schedule display
  final Map<String, bool> _selectedGroupsForExport = {}; // For batch export selection
  bool _selectAllGroups = false; // For batch export selection
  bool _isMultiScheduleView = false; // Toggle between single and multi-schedule view
  List<exporter.ScheduleExportData> _multiDisplaySchedules = []; // Schedules to display in multi-view
  bool _isExporting = false; // To show loading state during export


  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
    _searchController.addListener(_filterGroups);
    _initData();
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _groupSchedulesSubscription?.cancel();
    _searchController.removeListener(_filterGroups);
    _searchController.dispose();
    super.dispose();
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
      _campus = userData['campus'];

      if (_campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }

      // Use educationalCenters data to get the campus name
      final campusInfo = edu_centers.getEducationalCenterInfoByPartialName(_campus!);
      _campusName = campusInfo['name']; // Use the name from the lookup

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId =
          await _appSettingsService.getCurrentSchoolCycleId();

      if (!mounted) return;
      setState(() {
        _availableSchoolCycles = cycles;
        _selectedSchoolCycle = currentCycleId;
      });

      if (_selectedSchoolCycle != null) {
        await _loadDataForCycle(_selectedSchoolCycle!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDataForCycle(String cycleId) async {
    if (_campus == null) return;

    setState(() {
      _isLoading = true;
      _allGroups = [];
      _filteredGroups = [];
      _groupSchedules = {};
    });

    _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    _groupSchedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');

    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!
        .orderByChild('schoolCycleId')
        .equalTo(cycleId)
        .onValue
        .listen((event) {
      final newGroups = <Group>[];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          newGroups.add(Group.fromSnapshot(child));
        }
      }
      if (mounted) {
        setState(() {
          _allGroups = newGroups;
          _selectedGroupsForExport.addEntries(newGroups.map((group) => MapEntry(group.key, false))); // Initialize selection
          _filterGroups();
        });
        _loadSchedules();
      }
    }, onError: (e) {
       if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar grupos: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
       }
    });
  }

  void _loadSchedules() {
    _groupSchedulesSubscription?.cancel();
    _groupSchedulesSubscription = _groupSchedulesRef!.onValue.listen((event) {
      final newSchedules = <String, GroupSchedule>{};
      if (event.snapshot.exists) {
        for (final groupSnapshot in event.snapshot.children) {
          newSchedules[groupSnapshot.key!] =
              GroupSchedule.fromSnapshot(groupSnapshot);
        }
      }
      if (mounted) {
        setState(() {
          _groupSchedules = newSchedules;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar horarios: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    });
  }

  void _filterGroups() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGroups = _allGroups
          .where((group) => group.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
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
      body: LayoutBuilder(builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                _buildHeader(theme, isDark),
                if (_isMultiScheduleView)
                  Expanded(child: _buildMultiScheduleView())
                else
                  Expanded(child: _buildSingleScheduleView()),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.cardTheme.color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: _buildCycleSelector()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSelector() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedSchoolCycle,
        isExpanded: true,
        hint: const Text("Seleccionar Ciclo Escolar"),
        items: _availableSchoolCycles
            .map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))))
            .toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedSchoolCycle = val;
              _loadDataForCycle(val);
            });
            UiHelpers.showSnackBar(context, 'Cargando datos para el ciclo $val');
          }
        },
      ),
    );
  }

  Widget _buildSingleScheduleView() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildGroupSelectionCard(), // Now only contains multi-selection and export buttons
              Expanded(
                child: _buildEmptyState('Utiliza las casillas de selección para elegir grupos a visualizar o exportar.'),
              ),
            ],
          );
  }

  Widget _buildMultiScheduleView() {
    if (_multiDisplaySchedules.isEmpty) {
      return _buildEmptyState('No hay horarios seleccionados para mostrar.');
    }
    return Column(
      children: [
        Expanded(
          child: Screenshot(
            controller: _multiViewScreenshotController,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                ],
              ),
            ),
          ),
        ),
        _buildBatchExportButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGroupSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            // Multi-export section
            if (_allGroups.isNotEmpty && !_isLoading) ...[
              Text(
                'Seleccionar Grupos para Visualizar/Exportar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Seleccionar todos los grupos'),
                value: _selectAllGroups,
                onChanged: (bool? value) {
                  setState(() {
                    _selectAllGroups = value ?? false;
                    for (var group in _allGroups) {
                      _selectedGroupsForExport[group.key] = _selectAllGroups;
                    }
                    _updateSelectedGroupFromCheckboxes(); // Update _selectedGroup based on new selection
                  });
                },
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = _filteredGroups[index];
                      return CheckboxListTile(
                        title: Text(group.name),
                        value: _selectedGroupsForExport[group.key] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            _selectedGroupsForExport[group.key] = value ?? false;
                            if (!(_selectedGroupsForExport[group.key] ?? false)) {
                              _selectAllGroups = false;
                            } else if (_selectedGroupsForExport.values.every((element) => element)) {
                              _selectAllGroups = true;
                            }
                            _updateSelectedGroupFromCheckboxes(); // Update _selectedGroup based on new selection
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Moved "Opciones de exportación y visualización" here to be closer to buttons
              Text(
                'Opciones:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _selectedGroupsForExport.values.any((e) => e)
                        ? () async {
                            setState(() => _isExporting = true);
                            final List<Group> groupsToView = _allGroups.where((group) => _selectedGroupsForExport[group.key] ?? false).toList();
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
                              _isExporting = false;
                              _selectedGroup = null; // Clear _selectedGroup as we are now in multi-view
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('Ver Seleccionados'),
                  ),
                  _buildBatchExportButtons(), // Batch export buttons
                ],
              ),
              const SizedBox(height: 10),
              // Single export buttons now appear here if exactly one group is selected
              if (_selectedGroup != null) _buildSingleExportButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleExportButtons() {
    return _isExporting
        ? const Center(child: CircularProgressIndicator())
        : Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: (_selectedGroup != null && _groupSchedules[_selectedGroup!.key] != null)
                    ? _exportSingleScheduleAsImage
                    : null,
                icon: const Icon(Icons.image),
                label: const Text('Exportar como Imagen'),
              ),
              ElevatedButton.icon(
                onPressed: (_selectedGroup != null && _groupSchedules[_selectedGroup!.key] != null)
                    ? _exportSingleScheduleAsPdf
                    : null,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar como PDF'),
              ),
            ],
          );
  }

  Widget _buildBatchExportButtons() {
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
          onPressed: anyDisplayed ? _exportMultiScheduleAsImageZip : null,
          icon: const Icon(Icons.image),
          label: const Text('Exportar todo JPG (ZIP)'),
        ),
        ElevatedButton.icon(
          onPressed: anyDisplayed ? _exportMultiScheduleAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar todo PDF'),
        ),
      ],
    );
  }

  Future<Uint8List?> _captureWidgetImage(ScreenshotController controller, Widget widgetToCapture) async {
    return await controller.captureFromWidget(
      widgetToCapture,
      delay: const Duration(milliseconds: 100),
      pixelRatio: 2.0,
      targetSize: const Size(1500, 1200), // Increased size for better capture and landscape orientation
    );
  }

  Future<exporter.ScheduleExportData?> _getScheduleExportDataForGroup(Group group) async {
    if (_campus == null || _selectedSchoolCycle == null || _campusName == null) return null;

    final schedule = _groupSchedules[group.key];
    return exporter.ScheduleExportData(
      id: group.key,
      name: group.name,
      title: 'Horario: ${group.name}',
      subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
      scheduleData: schedule?.dailySchedules ?? {},
      viewType: 'group',
      mainTitle: 'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
      campusName: _campusName!,
      logoPath: 'assets/images/logo1.png',
    );
  }

  Future<void> _exportSingleScheduleAsImage() async {
    if (_selectedGroup == null || _groupSchedules[_selectedGroup!.key] == null) return;
    setState(() => _isExporting = true);

    final exportData = await _getScheduleExportDataForGroup(_selectedGroup!);
    if (exportData == null) return;

    final imageBytes = await _captureWidgetImage(_screenshotController, ScheduleDisplayWidget(
      title: exportData.title,
      subtitle: exportData.subtitle,
      scheduleData: exportData.scheduleData,
      viewType: exportData.viewType,
      mainTitle: exportData.mainTitle,
      campusName: exportData.campusName,
      logoPath: exportData.logoPath,
      isExporting: true,
    ));

    if (imageBytes != null) {
      final fileName = 'Horario_${_selectedGroup!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportImage(imageBytes, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'Horario guardado en la galería.' : 'Error al exportar imagen.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen.', isError: true);
    }
    setState(() => _isExporting = false);
  }

  Future<void> _exportSingleScheduleAsPdf() async {
    if (_selectedGroup == null || _groupSchedules[_selectedGroup!.key] == null) return;
    setState(() => _isExporting = true);

    final exportData = await _getScheduleExportDataForGroup(_selectedGroup!);
    if (exportData == null) return;

    final imageBytes = await _captureWidgetImage(_screenshotController, ScheduleDisplayWidget(
      title: exportData.title,
      subtitle: exportData.subtitle,
      scheduleData: exportData.scheduleData,
      viewType: exportData.viewType,
      mainTitle: exportData.mainTitle,
      campusName: exportData.campusName,
      logoPath: exportData.logoPath,
      isExporting: true,
    ));

    if (imageBytes != null) {
      final fileName = 'Horario_${_selectedGroup!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportPdfSingle(imageBytes, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'PDF generado con éxito.' : 'Error al exportar PDF.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen para PDF.', isError: true);
    }
    setState(() => _isExporting = false);
  }

  Future<void> _exportMultiScheduleAsImageZip() async {
    setState(() => _isExporting = true);
    final Map<String, Uint8List> images = {};
    for (var exportData in _multiDisplaySchedules) {
      final imageBytes = await _captureWidgetImage(_multiViewScreenshotController, ScheduleDisplayWidget(
        title: exportData.title,
        subtitle: exportData.subtitle,
        scheduleData: exportData.scheduleData,
        viewType: exportData.viewType,
        mainTitle: exportData.mainTitle,
        campusName: exportData.campusName,
        logoPath: exportData.logoPath,
        isExporting: true,
      ));
      if (imageBytes != null) {
        images['${exportData.name}_Horario.png'] = imageBytes;
      }
    }

    if (images.isNotEmpty) {
      final fileName = 'Horarios_Grupos_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportImagesToZip(images, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'Horarios exportados en ZIP.' : 'Error al exportar ZIP.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'No hay horarios para exportar.', isError: true);
    }
    setState(() => _isExporting = false);
  }

  Future<void> _exportMultiScheduleAsPdf() async {
    setState(() => _isExporting = true);
    final List<Uint8List> pdfPages = [];
    for (var exportData in _multiDisplaySchedules) {
      final imageBytes = await _captureWidgetImage(_multiViewScreenshotController, ScheduleDisplayWidget(
        title: exportData.title,
        subtitle: exportData.subtitle,
        scheduleData: exportData.scheduleData,
        viewType: exportData.viewType,
        mainTitle: exportData.mainTitle,
        campusName: exportData.campusName,
        logoPath: exportData.logoPath,
        isExporting: true,
      ));
      if (imageBytes != null) {
        pdfPages.add(imageBytes);
      }
      await Future.delayed(const Duration(milliseconds: 50)); // Small delay to prevent UI freezing
    }

    if (pdfPages.isNotEmpty) {
      final fileName = 'Horarios_Grupos_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportPdfMulti(pdfPages, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'PDF generado con éxito.' : 'Error al exportar PDF.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'No hay horarios para exportar.', isError: true);
    }
    setState(() => _isExporting = false);
  }

  void _updateSelectedGroupFromCheckboxes() {
    final selectedGroupKeys = _selectedGroupsForExport.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedGroupKeys.length == 1) {
      setState(() {
        _selectedGroup = _allGroups.firstWhereOrNull(
          (group) => group.key == selectedGroupKeys.first,
        );
      });
    } else {
      setState(() {
        _selectedGroup = null;
      });
    }
  }

  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}