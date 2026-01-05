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

      _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');

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
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: ${e.toString()}', isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeStudents = _allStudents.where((s) => s.isActive).toList();
    final inactiveStudents = _allStudents.where((s) => !s.isActive).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Alumnos'),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Activos (${activeStudents.length})'),
            Tab(text: 'Bajas (${inactiveStudents.length})'),
          ],
        ),
      ),
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
                        _buildFilterHeader(theme, isDark),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildStudentList(activeStudents, true),
                              _buildStudentList(inactiveStudents, false),
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
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFilterSchoolCycle,
                    decoration: const InputDecoration(
                      labelText: 'Ciclo Escolar',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                    onChanged: (val) => val != null ? _onFilterCycleChanged(val) : null,
                    items: _availableSchoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.secondary),
                  onPressed: () {
                    if (_campus == null) return;
                    Navigator.push(context, MaterialPageRoute(builder: (context) => StudentExcelImportScreen(campusId: _campus!, currentSchoolCycle: _currentSchoolCycle)));
                  },
                  tooltip: 'Importar Excel',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(List<Student> students, bool isActiveList) {
    if (students.isEmpty) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActiveList ? Icons.people_outline : Icons.person_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(isActiveList ? 'No hay alumnos activos.' : 'No hay alumnos en baja.', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return FadeInUp(
          delay: Duration(milliseconds: 30 * index),
          child: _buildStudentCard(student, isActiveList),
        );
      },
    );
  }

  Widget _buildStudentCard(Student student, bool isActiveList) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFemale = student.gender.toLowerCase() == 'femenino';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActiveList ? Colors.grey.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
      ),
      color: isDark ? theme.cardTheme.color : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isFemale ? Colors.pink.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
              child: Icon(isFemale ? Icons.woman_rounded : Icons.man_rounded, color: isFemale ? Colors.pink : Colors.blue, size: 32),
            ),
            if (!isActiveList)
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
              ),
          ],
        ),
        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildInfoChip(student.group, Colors.indigo, theme),
                const SizedBox(width: 8),
                Text('ID: ${student.studentId}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (!isActiveList && student.deactivationReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Motivo: ${student.deactivationReason}', style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActiveList)
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openEditForm(student)),
            IconButton(
              icon: Icon(isActiveList ? Icons.person_remove_outlined : Icons.person_add_alt_1_outlined, color: isActiveList ? theme.colorScheme.error : theme.colorScheme.secondary),
              onPressed: () => isActiveList ? _confirmAndDeleteStudent(student) : _reactivateStudent(student),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
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
    _studentsSubscription?.cancel();
    setState(() {
      _selectedFilterSchoolCycle = newCycleId;
      _isLoading = true;
      _allStudents = [];
    });
    _studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedFilterSchoolCycle');
    _initData();
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