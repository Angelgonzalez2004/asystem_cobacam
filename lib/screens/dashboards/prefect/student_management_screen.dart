import 'dart:async';
import 'dart:io'; // Necesario para File, Directory y Platform
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Para kIsWeb
import 'package:flutter/services.dart'; // Para ByteData, DefaultAssetBundle

// Paquetes externos
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart'; // IMPORTANTE: Para guardar archivos

// Tus imports internos
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_form_screen.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_excel_import_screen.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';

enum BatchAction {
  authorize,
  deauthorize,
}

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;
  late TabController _tabController;

  // Search Controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DatabaseReference? _studentsRef;
  StreamSubscription<DatabaseEvent>? _studentsSubscription;
  List<Student> _allStudents = [];
  bool _isLoading = true;
  String? _campus;
  String _currentSchoolCycle = '';
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _selectedFilterSchoolCycle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
    _initData();
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
      final allCycles = await _appSettingsService.getAllSchoolCycles();

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _availableSchoolCycles = allCycles;
        _selectedFilterSchoolCycle = dynamicSchoolCycle;
      });

      _loadStudentsForCycle(_selectedFilterSchoolCycle!);
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadStudentsForCycle(String cycleId) {
    _studentsSubscription?.cancel();
    _studentsRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/students/$cycleId');

    _studentsSubscription = _studentsRef!.onValue.listen((event) {
      final newStudents = <Student>[];
      if (event.snapshot.exists) {
        for (final child in event.snapshot.children) {
          newStudents.add(Student.fromSnapshot(child));
        }
      }
      if (mounted) {
        setState(() {
          _allStudents = newStudents;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar alumnos.',
            isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter Logic
    final filteredList = _allStudents.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.fullName.toLowerCase().contains(_searchQuery) ||
          s.studentId.toLowerCase().contains(_searchQuery);
    }).toList();

    final activeStudents = filteredList.where((s) => s.isActive).toList();
    final inactiveStudents = filteredList.where((s) => !s.isActive).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
                                        child: _isLoading
                                            ? const Center(child: CircularProgressIndicator())
                                            : Stack(
                                                children: [
                                                  Column(
                                                    children: [
                                                      // Tabs Container
                                                      Container(
                                                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                                        decoration: BoxDecoration(
                                                          color: isDark ? theme.cardTheme.color : Colors.white,
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                                                        ),
                                                        child: TabBar(
                                                          controller: _tabController,
                                                          indicatorColor: theme.colorScheme.primary,
                                                          labelColor: theme.colorScheme.primary,
                                                          unselectedLabelColor: Colors.grey,
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          indicatorSize: TabBarIndicatorSize.label,
                                                          tabs: [
                                                            Tab(text: 'Activos (${activeStudents.length})'),
                                                            Tab(text: 'Bajas (${inactiveStudents.length})'),
                                                          ],
                                                        ),
                                                      ),

                                                      _buildFilterHeader(theme, isDark),

                                                      Expanded(
                                                        child: TabBarView(
                                                          controller: _tabController,
                                                          children: [
                                                            _buildGroupedStudentList(activeStudents, true, theme, isDark),
                                                            _buildGroupedStudentList(inactiveStudents, false, theme, isDark),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Positioned(
                                                    right: 16.0,
                                                    bottom: 16.0,
                                                    child: FloatingActionButton(
                                                      onPressed: _showAddStudentDialog,
                                                      backgroundColor: theme.colorScheme.primary,
                                                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
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

  Widget _buildFilterHeader(ThemeData theme, bool isDark) {
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFilterSchoolCycle,
                        decoration: const InputDecoration(
                          labelText: 'Ciclo Escolar',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          prefixIcon:
                              Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        onChanged: (val) =>
                            val != null ? _onFilterCycleChanged(val) : null,
                        items: _availableSchoolCycles
                            .map((c) => DropdownMenuItem(
                                value: c.id, child: Text(c.id)))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: _downloadTemplate,
                      tooltip: 'Descargar Plantilla Excel',
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      onPressed: () {
                        if (_campus == null) return;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => StudentExcelImportScreen(
                                    campusId: _campus!,
                                    currentSchoolCycle: _currentSchoolCycle)));
                      },
                      tooltip: 'Importar Excel',
                    ),
                    const SizedBox(width: 12), // Add a SizedBox for spacing
                    IconButton.filledTonal(
                      icon: const Icon(Icons.group_add_outlined),
                      tooltip: 'Autorización por Lotes',
                      onPressed: _showBatchAuthorizationDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar Alumno',
                    hintText: 'Nombre o Matrícula',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear())
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedStudentList(
      List<Student> students, bool isActiveList, ThemeData theme, bool isDark) {
    if (students.isEmpty) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  isActiveList
                      ? Icons.people_outline
                      : Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                  isActiveList
                      ? 'No hay alumnos que coincidan.'
                      : 'No hay alumnos en baja.',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 1. Agrupar alumnos por nombre de grupo
    final Map<String, List<Student>> groupedStudents = {};
    for (var student in students) {
      if (!groupedStudents.containsKey(student.group)) {
        groupedStudents[student.group] = [];
      }
      groupedStudents[student.group]!.add(student);
    }

    // 2. Ordenar claves de grupos alfabéticamente
    final sortedGroupKeys = groupedStudents.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedGroupKeys.length,
      itemBuilder: (context, index) {
        final groupName = sortedGroupKeys[index];
        final groupList = groupedStudents[groupName]!;

        // Ordenar alumnos por nombre dentro del grupo
        groupList.sort((a, b) => a.fullName.compareTo(b.fullName));

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            color: isDark ? theme.cardTheme.color : Colors.white,
            child: Theme(
              // Quitar bordes de ExpansionTile
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(groupName.substring(0, min(2, groupName.length)),
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  'Grupo $groupName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  '${groupList.length} Alumnos',
                  style: TextStyle(color: theme.textTheme.bodySmall?.color),
                ),
                children: groupList
                    .map((student) =>
                        _buildStudentTile(student, isActiveList, theme))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildStudentTile(
      Student student, bool isActiveList, ThemeData theme) {
    final isFemale = student.gender.toLowerCase() == 'femenino';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(isFemale ? Icons.woman_rounded : Icons.man_rounded,
          color: isFemale ? Colors.pink : Colors.blue, size: 24),
      title: Text(student.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${student.studentId}',
              style: const TextStyle(fontSize: 12)),
          if (!isActiveList && student.deactivationReason != null)
            Text('Baja: ${student.deactivationReason}',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NEW: Toggle for canEditProfile
          Tooltip(
            message: 'Permitir edición de perfil al alumno',
            child: Switch(
              value: student.canEditProfile,
              onChanged: (bool newValue) {
                _toggleCanEditProfile(student, newValue);
              },
              activeColor: theme.colorScheme.primary,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _openEditForm(student),
            tooltip: 'Editar',
          ),
          if (isActiveList)
            IconButton(
              icon: Icon(Icons.person_remove_outlined,
                  color: theme.colorScheme.error, size: 20),
              onPressed: () => _confirmAndDeleteStudent(student),
              tooltip: 'Dar de Baja',
            )
          else
            IconButton(
              icon: Icon(Icons.person_add_alt_1_outlined,
                  color: theme.colorScheme.secondary, size: 20),
              onPressed: () => _reactivateStudent(student),
              tooltip: 'Reactivar',
            ),
        ],
      ),
    );
  }

    // NEW METHOD: _toggleCanEditProfile
    Future<void> _toggleCanEditProfile(Student student, bool newValue) async {
      final studentRef = FirebaseDatabase.instance
          .ref('planteles/$_campus/students/$_currentSchoolCycle')
          .child(student.id); // Use student.id (Firebase key) here

      try {
        await studentRef.update({'canEditProfile': newValue});

        // If enabling profile editing, reset the student's hasEditedProfileOnce flag in the 'users' collection
        // Only update if userId is available (i.e., student has a linked Firebase account)
        if (newValue && student.userId.isNotEmpty) {
          final userRef = FirebaseDatabase.instance.ref('users').child(student.userId);
          await userRef.update({'hasEditedProfileOnce': false});
        }

        if (mounted) {
          UiHelpers.showSnackBar(
              context,
              newValue
                  ? 'Edición de perfil habilitada para ${student.fullName}.'
                  : 'Edición de perfil deshabilitada para ${student.fullName}.');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al actualizar el permiso de edición: $e',
              isError: true);
        }
      }
    }

  

    

  

    void _openEditForm(Student student) async {

      if (_campus == null) return;

      await Navigator.push(

          context,

          MaterialPageRoute(

              builder: (context) => StudentFormScreen(

                  student: student,

                  campusId: _campus!,

                  currentSchoolCycle: _currentSchoolCycle)));

    }

  Future<void> _reactivateStudent(Student student) async {
    final confirmed = await UiHelpers.showConfirmationDialog(context,
        title: 'Reactivar Alumno',
        content: '¿Deseas dar de alta nuevamente a ${student.fullName}?');
    if (confirmed && _studentsRef != null) {
      await _studentsRef!
          .child(student.studentId)
          .update({'isActive': true, 'deactivationReason': null});
      if (mounted) UiHelpers.showSnackBar(context, 'Alumno reactivado.');
    }
  }

  void _onFilterCycleChanged(String newCycleId) {
    if (_campus == null) return;
    setState(() {
      _selectedFilterSchoolCycle = newCycleId;
      _isLoading = true;
      _allStudents = [];
    });
    _loadStudentsForCycle(newCycleId);
  }

  Future<void> _confirmAndDeleteStudent(Student student) async {
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Baja'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Dar de baja a ${student.fullName}?'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                      labelText: 'Motivo (reprobación, personal, etc.)',
                      border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => formKey.currentState!.validate()
                  ? Navigator.pop(dialogContext, true)
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Dar de Baja'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && _studentsRef != null) {
      await _studentsRef!
          .child(student.studentId)
          .update({'isActive': false, 'deactivationReason': reasonController.text});
      if (mounted) UiHelpers.showSnackBar(context, 'Baja registrada.');
    }
  }

  // NEW METHOD: Bulk Authorization Dialog
  Future<void> _showBatchAuthorizationDialog() async {
    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(context, 'Campus o Ciclo Escolar no definidos.',
          isError: true);
      return;
    }

    BatchAction? selectedAction;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Autorización de Edición por Lotes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Aplicar a todos los alumnos activos del ciclo actual: $_currentSchoolCycle'),
                  const SizedBox(height: 16),
                  RadioListTile<BatchAction>(
                    title: const Text('Autorizar Edición de Perfil'),
                    value: BatchAction.authorize,
                    groupValue: selectedAction,
                    onChanged: (BatchAction? value) {
                      setStateInDialog(() {
                        selectedAction = value;
                      });
                    },
                  ),
                  RadioListTile<BatchAction>(
                    title: const Text('Desautorizar Edición de Perfil'),
                    value: BatchAction.deauthorize,
                    groupValue: selectedAction,
                    onChanged: (BatchAction? value) {
                      setStateInDialog(() {
                        selectedAction = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: selectedAction == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedAction != null) {
      await _updateBulkStudentPermissions(
          selectedAction == BatchAction.authorize);
    }
  }

  // NEW METHOD: Update Bulk Student Permissions
    Future<void> _updateBulkStudentPermissions(
        bool authorizeProfileEdit) async {
      if (_campus == null || _currentSchoolCycle.isEmpty) return;
  
      UiHelpers.showSnackBar(context, 'Aplicando cambios a todos los alumnos...');
  
      try {
        final studentsToUpdate =
            _allStudents.where((s) => s.isActive).toList(); // Only active students
  
        for (var student in studentsToUpdate) {
          final studentRef = FirebaseDatabase.instance
              .ref('planteles/$_campus/students/$_currentSchoolCycle')
              .child(student.id);
          await studentRef.update({
            'canEditProfile': authorizeProfileEdit,
          });
  
          // Also update the hasEditedProfileOnce flag in the 'users' collection
          // if authorizing profile edit, and if the student has a linked Firebase account (userId is not empty)
          if (authorizeProfileEdit && student.userId.isNotEmpty) {
            final userRef = FirebaseDatabase.instance.ref('users').child(student.userId);
            await userRef.update({'hasEditedProfileOnce': false});
          }
          if (authorizeProfileEdit && student.userId.isEmpty) {
            debugPrint('Advertencia: No se pudo resetear el permiso de edición única para el alumno ${student.fullName} (ID: ${student.id}). No tiene un UID de Firebase asociado.');
          }
        }
  
        if (mounted) {
          UiHelpers.showSnackBar(context,
              'Permisos de edición actualizados para todos los alumnos del ciclo actual.');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showSnackBar(
              context, 'Error al aplicar permisos por lotes: $e',
              isError: true);
        }
      }
    }

  void _showAddStudentDialog() async {
    if (_campus == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => StudentFormScreen(
                campusId: _campus!, currentSchoolCycle: _currentSchoolCycle)));
  }

  // NEW METHOD: _downloadTemplate CORREGIDO
  Future<void> _downloadTemplate() async {
    final confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Descargar Plantilla',
      content:
          '¿Estás seguro de que quieres descargar la plantilla de Excel para registros de alumnos? Recuerda que debes modificar este archivo con los datos reales de los alumnos y asegurarte de que correspondan al ciclo escolar seleccionado. También es importante ajustar los grupos en las hojas de Excel, ya que estos pueden variar en cada ciclo escolar.',
      confirmText: 'Descargar',
    );

    if (confirmed != true) return;

    if (_campus == null || _currentSchoolCycle.isEmpty) {
      UiHelpers.showSnackBar(context,
          'Campus o Ciclo Escolar no definidos. No se puede generar la plantilla.',
          isError: true);
      return;
    }

    UiHelpers.showSnackBar(context, 'Preparando descarga de plantilla...');

    try {
      // Path to the asset file
      const String assetPath =
          'assets/excel_templates/plantilla_alumnos_2026A_Atasta_.xlsx';
      final String fileName =
          'plantilla_alumnos_${_currentSchoolCycle.replaceAll("/", "-")}_${_campus ?? 'generico'}.xlsx';

      // Load the asset as bytes
      final ByteData data =
          await DefaultAssetBundle.of(context).load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      if (kIsWeb) {
        // Lógica para WEB
        await WebDownloader.downloadFile(bytes, fileName,
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      } else {
        // Lógica para MÓVIL (Android/iOS)
        Directory? directory;
        
        if (Platform.isAndroid) {
          // En Android usamos ExternalStorageDirectory para que sea visible
          directory = await getExternalStorageDirectory();
        } else {
          // En iOS usamos ApplicationDocumentsDirectory
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          final String savePath = '${directory.path}/$fileName';
          final File file = File(savePath);
          await file.writeAsBytes(bytes);

          if (mounted) {
            UiHelpers.showSnackBar(context,
                'Plantilla guardada en: ${file.path}. Revisa tu carpeta Android/data/files o Archivos.',
                duration: const Duration(seconds: 5));
          }
        } else {
          throw Exception("No se pudo acceder al directorio de almacenamiento.");
        }
      }

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Descarga completada.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al descargar la plantilla: $e',
            isError: true);
      }
    }
  }
}