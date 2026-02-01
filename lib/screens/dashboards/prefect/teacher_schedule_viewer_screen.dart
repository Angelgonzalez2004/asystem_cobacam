import 'dart:async';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
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
import 'package:screenshot/screenshot.dart';
import 'package:asystem_cobacam/utils/schedule_exporter.dart' as exporter;
import 'package:collection/collection.dart';

import 'package:asystem_cobacam/data/educational_centers.dart' as edu_centers;

class TeacherScheduleViewerScreen extends StatefulWidget {
  const TeacherScheduleViewerScreen({super.key});

  @override
  State<TeacherScheduleViewerScreen> createState() =>
      _TeacherScheduleViewerScreenState();
}

class _TeacherScheduleViewerScreenState
    extends State<TeacherScheduleViewerScreen> {
  late final AppSettingsService _appSettingsService;

  List<Teacher> _allTeachers = [];
  List<Teacher> _filteredTeachers = [];
  Map<String, GroupSchedule> _groupSchedules = {};
  Map<String, Group> _groupsMap = {};

  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedSchoolCycle;

  bool _isLoading = true;
  String? _campus;
  String? _campusName;

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _dataSubscription;

  final List<String> _weekdays = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes'
  ];

  // Export related state and controllers
  final exporter.FileExporter _fileExporter = exporter.FileExporter();
  final ScreenshotController _screenshotController = ScreenshotController();
  final ScreenshotController _multiViewScreenshotController = ScreenshotController();

  Teacher? _selectedTeacher;
  final Map<String, bool> _selectedTeachersForExport = {};
  bool _selectAllTeachers = false;
  bool _isMultiScheduleView = false;
  List<exporter.ScheduleExportData> _multiDisplaySchedules = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _searchController.addListener(_filterTeachers);
    _initData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _searchController.removeListener(_filterTeachers);
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

      final campusInfo = edu_centers.getEducationalCenterInfoByPartialName(_campus!);
      _campusName = campusInfo['name'];

      final cycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId =
          await _appSettingsService.getCurrentSchoolCycleId();

      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _selectedSchoolCycle = currentCycleId;
        });
        if (_selectedSchoolCycle != null) {
          _loadDataForCycle(_selectedSchoolCycle!);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadDataForCycle(String cycleId) {
    _dataSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _allTeachers = [];
      _filteredTeachers = [];
      _groupSchedules = {};
      _groupsMap = {};
    });

    final teachersRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/school_cycles/$cycleId/teachers');
    final schedulesRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/schedules/$cycleId');
    final groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');

    // Combine streams to know when all data is loaded
    final dataStream = StreamZip([
      teachersRef.onValue,
      schedulesRef.onValue,
      groupsRef.orderByChild('schoolCycleId').equalTo(cycleId).onValue,
    ]);

    _dataSubscription = dataStream.listen((data) {
      // Data from teachersRef
      final teacherSnapshot = data[0].snapshot;
      final newTeachers = <Teacher>[];
      if (teacherSnapshot.exists) {
        for (final child in teacherSnapshot.children) {
          newTeachers.add(Teacher.fromSnapshot(child));
        }
      }

      // Data from schedulesRef
      final scheduleSnapshot = data[1].snapshot;
      final newSchedules = <String, GroupSchedule>{};
      if (scheduleSnapshot.exists) {
        for (final groupSnapshot in scheduleSnapshot.children) {
          newSchedules[groupSnapshot.key!] =
              GroupSchedule.fromSnapshot(groupSnapshot);
        }
      }

      // Data from groupsRef
      final groupSnapshot = data[2].snapshot;
      final newGroups = <String, Group>{};
       if (groupSnapshot.exists) {
        for (final child in groupSnapshot.children) {
          final group = Group.fromSnapshot(child);
          newGroups[group.key] = group;
          // print('DEBUG: Loaded group - ID: ${group.key}, Name: ${group.name}'); // Commented for production
        }
      }

      if (mounted) {
        setState(() {
          _allTeachers = newTeachers;
          _selectedTeachersForExport.addEntries(newTeachers.map((teacher) => MapEntry(teacher.id, false)));
          _groupSchedules = newSchedules;
          _groupsMap = newGroups;
          // print('DEBUG: _groupsMap contains ${_groupsMap.length} entries.'); // Commented for production
          _filterTeachers();
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if(mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar datos: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    });
  }

  void _filterTeachers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = _allTeachers
          .where((teacher) => teacher.name.toLowerCase().contains(query))
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
            setState(() => _selectedSchoolCycle = val);
            _loadDataForCycle(val);
            UiHelpers.showSnackBar(context, 'Cargando datos para el ciclo $val');
          }
        },
      ),
    );
  }



  Map<String, List<ClassSession>> _getScheduleForTeacher(String teacherId) {
    final teacherSchedule = <String, List<ClassSession>>{};

    for (var day in _weekdays) {
      final sessionsForDay = <ClassSession>[];
      for (var groupSchedule in _groupSchedules.values) {
        final dailySessions = groupSchedule.dailySchedules[day] ?? [];
        for (var session in dailySessions) {
          if (session.teacherId == teacherId) {
            final groupName = _groupsMap[groupSchedule.groupId]?.name ?? 'N/A';
            // print('DEBUG in _getScheduleForTeacher: Looking for groupId: ${groupSchedule.groupId}, found groupName: $groupName'); // Commented for production
            sessionsForDay.add(
              ClassSession(
                startTime: session.startTime,
                endTime: session.endTime,
                subjectId: session.subjectId,
                teacherId: session.teacherId,
                subjectName: session.subjectName,
                teacherName: session.teacherName,
                groupName: groupName, // Explicitly set groupName here
              ),
            );
          }
        }
      }
      if (sessionsForDay.isNotEmpty) {
        sessionsForDay.sort((a, b) => a.startTime.compareTo(b.startTime));
        teacherSchedule[day] = sessionsForDay;
      }
    }
    return teacherSchedule;
  }

  Widget _buildSingleScheduleView() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildTeacherSelectionCard(), // Now only contains multi-selection and export buttons
              Expanded(
                child: _buildEmptyState('Utiliza las casillas de selección para elegir maestros a visualizar o exportar.'),
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
        _buildMultiExportButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTeacherSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Multi-export section
            if (_allTeachers.isNotEmpty && !_isLoading) ...[
              Text(
                'Seleccionar Maestros para Visualizar/Exportar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Seleccionar todos los maestros'),
                value: _selectAllTeachers,
                onChanged: (bool? value) {
                  setState(() {
                    _selectAllTeachers = value ?? false;
                    for (var teacher in _allTeachers) {
                      _selectedTeachersForExport[teacher.id] = _selectAllTeachers;
                    }
                    _updateSelectedTeacherFromCheckboxes(); // Update _selectedTeacher based on new selection
                  });
                },
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredTeachers.length,
                    itemBuilder: (context, index) {
                      final teacher = _filteredTeachers[index];
                      return CheckboxListTile(
                        title: Text(teacher.name),
                        value: _selectedTeachersForExport[teacher.id] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            _selectedTeachersForExport[teacher.id] = value ?? false;
                            if (!(_selectedTeachersForExport[teacher.id] ?? false)) {
                              _selectAllTeachers = false;
                            } else if (_selectedTeachersForExport.values.every((element) => element)) {
                              _selectAllTeachers = true;
                            }
                            _updateSelectedTeacherFromCheckboxes(); // Update _selectedTeacher based on new selection
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
                    onPressed: _selectedTeachersForExport.values.any((e) => e)
                        ? () async {
                            setState(() => _isExporting = true);
                            final List<Teacher> teachersToView = _allTeachers.where((teacher) => _selectedTeachersForExport[teacher.id] ?? false).toList();
                            final List<exporter.ScheduleExportData> schedules = [];
                            for (var teacher in teachersToView) {
                              final data = await _getScheduleExportDataForTeacherExport(teacher);
                              if (data != null) {
                                schedules.add(data);
                              }
                            }
                            setState(() {
                              _multiDisplaySchedules = schedules;
                              _isMultiScheduleView = true;
                              _isExporting = false;
                              _selectedTeacher = null; // Clear _selectedTeacher as we are now in multi-view
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('Ver Seleccionados'),
                  ),
                  _buildMultiExportButtons(), // Batch export buttons
                ],
              ),
              const SizedBox(height: 10),
              // Single export buttons now appear here if exactly one teacher is selected
              if (_selectedTeacher != null) _buildSingleExportButtons(),
            ],
          ],
        ),
      ),
    );
  }

  void _updateSelectedTeacherFromCheckboxes() {
    final selectedTeacherIds = _selectedTeachersForExport.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedTeacherIds.length == 1) {
      setState(() {
        _selectedTeacher = _allTeachers.firstWhereOrNull(
          (teacher) => teacher.id == selectedTeacherIds.first,
        );
      });
    } else {
      setState(() {
        _selectedTeacher = null;
      });
    }
  }

  Widget _buildSingleExportButtons() {
    if (_isExporting) {
      return const Center(child: CircularProgressIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _selectedTeacher != null ? _exportSingleScheduleAsImage : null,
          icon: const Icon(Icons.image),
          label: const Text('Exportar Img (actual)'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedTeacher != null ? _exportSingleScheduleAsPdf : null,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF (actual)'),
        ),
      ],
    );
  }

  Widget _buildMultiExportButtons() {
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
      pixelRatio: 1.0,
      targetSize: const Size(1200, 1500), // Changed to portrait orientation
    );
  }

  Future<exporter.ScheduleExportData?> _getScheduleExportDataForTeacherExport(Teacher teacher) async {
    if (_campus == null || _selectedSchoolCycle == null || _campusName == null) return null;

    final scheduleData = _getScheduleForTeacher(teacher.id);

    return exporter.ScheduleExportData(
      id: teacher.id,
      name: teacher.name,
      title: 'Horario: ${teacher.name}',
      subtitle: 'Ciclo Escolar: $_selectedSchoolCycle',
      scheduleData: scheduleData,
      viewType: 'teacher',
      mainTitle: 'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
      campusName: _campusName!,
      logoPath: 'assets/images/logo1.png',
    );
  }

  Future<void> _exportSingleScheduleAsImage() async {
    if (_selectedTeacher == null) return;
    setState(() => _isExporting = true);

    final exportData = await _getScheduleExportDataForTeacherExport(_selectedTeacher!);
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
      final fileName = 'Horario_${_selectedTeacher!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportImage(imageBytes, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'Horario guardado en la galería.' : 'Error al exportar imagen.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al capturar la imagen.', isError: true);
    }
    setState(() => _isExporting = false);
  }

  Future<void> _exportSingleScheduleAsPdf() async {
    if (_selectedTeacher == null) return;
    setState(() => _isExporting = true);

    final exportData = await _getScheduleExportDataForTeacherExport(_selectedTeacher!);
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
      final fileName = 'Horario_${_selectedTeacher!.name}_${_selectedSchoolCycle!.replaceAll("/", "-")}';
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
      final fileName = 'Horarios_Maestros_${_selectedSchoolCycle!.replaceAll("/", "-")}';
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

    }

    if (pdfPages.isNotEmpty) {
      final fileName = 'Horarios_Maestros_${_selectedSchoolCycle!.replaceAll("/", "-")}';
      final success = await _fileExporter.exportPdfMulti(pdfPages, fileName);
      if (mounted) UiHelpers.showSnackBar(context, success ? 'PDF generado con éxito.' : 'Error al exportar PDF.');
    } else {
      if (mounted) UiHelpers.showSnackBar(context, 'No hay horarios para exportar.', isError: true);
    }
    setState(() => _isExporting = false);
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