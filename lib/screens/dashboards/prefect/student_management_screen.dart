import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_form_screen.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/screens/dashboards/prefect/student_excel_import_screen.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
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
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _initData();
  }

  Future<void> _initData() async {
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

      if (!mounted) return;
      setState(() {
        _campus = campus;
        _currentSchoolCycle = dynamicSchoolCycle;
        _availableSchoolCycles = allCycles;
        _selectedFilterSchoolCycle = dynamicSchoolCycle;
      });

      _loadStudentsForCycle(_selectedFilterSchoolCycle!);

    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadStudentsForCycle(String cycleId) {
    _studentsSubscription?.cancel();
    _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$cycleId');

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
      if (mounted) UiHelpers.showSnackBar(context, 'Error al cargar alumnos.', isError: true);
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
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
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        onChanged: (val) => val != null ? _onFilterCycleChanged(val) : null,
                        items: _availableSchoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      onPressed: () {
                        if (_campus == null) return;
                        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentExcelImportScreen(campusId: _campus!, currentSchoolCycle: _currentSchoolCycle)));
                      },
                      tooltip: 'Importar Excel',
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
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  // NUEVA IMPLEMENTACIÓN: Lista agrupada por Grupos
  Widget _buildGroupedStudentList(List<Student> students, bool isActiveList, ThemeData theme, bool isDark) {
    if (students.isEmpty) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActiveList ? Icons.people_outline : Icons.person_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(isActiveList ? 'No hay alumnos que coincidan.' : 'No hay alumnos en baja.', style: const TextStyle(color: Colors.grey)),
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
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            color: isDark ? theme.cardTheme.color : Colors.white,
            child: Theme(
              // Quitar bordes de ExpansionTile
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(groupName.substring(0, min(2, groupName.length)), 
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  'Grupo $groupName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  '${groupList.length} Alumnos',
                  style: TextStyle(color: theme.textTheme.bodySmall?.color),
                ),
                children: groupList.map((student) => _buildStudentTile(student, isActiveList, theme)).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildStudentTile(Student student, bool isActiveList, ThemeData theme) {
    final isFemale = student.gender.toLowerCase() == 'femenino';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        isFemale ? Icons.woman_rounded : Icons.man_rounded, 
        color: isFemale ? Colors.pink : Colors.blue, 
        size: 24
      ),
      title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${student.studentId}', style: const TextStyle(fontSize: 12)),
          if (!isActiveList && student.deactivationReason != null)
            Text('Baja: ${student.deactivationReason}', style: const TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _openEditForm(student),
            tooltip: 'Editar',
          ),
          if (isActiveList)
            IconButton(
              icon: Icon(Icons.person_remove_outlined, color: theme.colorScheme.error, size: 20),
              onPressed: () => _confirmAndDeleteStudent(student),
              tooltip: 'Dar de Baja',
            )
          else
            IconButton(
              icon: Icon(Icons.person_add_alt_1_outlined, color: theme.colorScheme.secondary, size: 20),
              onPressed: () => _reactivateStudent(student),
              tooltip: 'Reactivar',
            ),
        ],
      ),
    );
  }

  void _openEditForm(Student student) async {
    if (_campus == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (context) => StudentFormScreen(student: student, campusId: _campus!, currentSchoolCycle: _currentSchoolCycle)));
  }

  Future<void> _reactivateStudent(Student student) async {
    final confirmed = await UiHelpers.showConfirmationDialog(context, title: 'Reactivar Alumno', content: '¿Deseas dar de alta nuevamente a ${student.fullName}?');
    if (confirmed && _studentsRef != null) {
      await _studentsRef!.child(student.studentId).update({'isActive': true, 'deactivationReason': null});
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
                  decoration: const InputDecoration(labelText: 'Motivo (reprobación, personal, etc.)', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => formKey.currentState!.validate() ? Navigator.pop(dialogContext, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Dar de Baja'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _studentsRef!.child(student.studentId).update({'isActive': false, 'deactivationReason': reasonController.text});
      if (mounted) UiHelpers.showSnackBar(context, 'Baja registrada.');
    }
  }

  void _showAddStudentDialog() async {
    if (_campus == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (context) => StudentFormScreen(campusId: _campus!, currentSchoolCycle: _currentSchoolCycle)));
  }
}