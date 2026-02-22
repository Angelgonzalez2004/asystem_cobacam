import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewStudentProfileScreen extends StatefulWidget {
  final Student student;
  const ViewStudentProfileScreen({super.key, required this.student});

  @override
  State<ViewStudentProfileScreen> createState() => _ViewStudentProfileScreenState();
}

class _ViewStudentProfileScreenState extends State<ViewStudentProfileScreen> {
  late final AppSettingsService _appSettingsService;
  
  bool _isLoadingCycles = true;
  bool _isLoadingStudent = false;
  String? _errorMessage;
  
  List<SchoolCycle> _schoolCycles = [];
  String? _selectedCycle;
  Student? _currentStudentData;
  String? _userCampusId;

  @override
  void initState() {
    super.initState();
    _appSettingsService = AppSettingsService(
      Provider.of<HiveService>(context, listen: false),
      Provider.of<ConnectivityService>(context, listen: false),
    );
    _currentStudentData = widget.student;
    _selectedCycle = widget.student.schoolCycle;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Como somos tutores viendo esto, el campus debería venir del objeto student original o del contexto.
      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      
      // Intentar deducir el campus (esto es importante para la ruta de Firebase)
      // Si no tenemos el campus, lo buscamos en la base de datos para el alumno
      _userCampusId = await _findStudentCampus(widget.student.studentId);

      if (_schoolCycles.isEmpty) {
        throw Exception("No se encontraron ciclos escolares registrados.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoadingCycles = false);
    }
  }

  Future<String?> _findStudentCampus(String matricula) async {
    // Buscar en todos los planteles si es necesario, pero usualmente ya sabemos el campus 
    // porque el tutor está logueado en un campus. 
    // Por ahora, usaremos una búsqueda rápida o asumiremos que el sistema ya filtró por campus.
    // Una forma segura es buscar en la rama 'users' el perfil del alumno si tiene userId
    if (widget.student.userId.isNotEmpty) {
      final userSnap = await FirebaseDatabase.instance.ref('users/${widget.student.userId}').get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        return userData['campus'];
      }
    }
    
    // Si no, buscamos manualmente en la estructura de planteles (esto puede ser lento pero es fallback)
    final plantelesSnap = await FirebaseDatabase.instance.ref('planteles').get();
    if (plantelesSnap.exists) {
      for (final plantelSnap in plantelesSnap.children) {
        final studentsSnap = plantelSnap.child('students');
        for (final cycleSnap in studentsSnap.children) {
          if (cycleSnap.hasChild(matricula)) {
            return plantelSnap.key;
          }
        }
      }
    }
    return null;
  }

  Future<void> _fetchStudentData(String selectedCycle) async {
    if (_userCampusId == null) {
      // Re-intentar encontrar campus si es nulo
      _userCampusId = await _findStudentCampus(widget.student.studentId);
      if (_userCampusId == null) {
        setState(() => _errorMessage = "No se pudo determinar el plantel del alumno.");
        return;
      }
    }

    setState(() {
      _isLoadingStudent = true;
      _errorMessage = null;
      _selectedCycle = selectedCycle;
    });

    try {
      final dbPath = 'planteles/$_userCampusId/students/$selectedCycle/${widget.student.studentId}';
      final studentSnap = await FirebaseDatabase.instance.ref(dbPath).get();

      if (studentSnap.exists) {
        final data = Map<String, dynamic>.from(studentSnap.value as Map);
        data['id'] = studentSnap.key;
        setState(() => _currentStudentData = Student.fromMap(data));
      } else {
        setState(() {
          _currentStudentData = null;
          _errorMessage = "No se encontraron registros para la matrícula ${widget.student.studentId} en el ciclo escolar $selectedCycle.";
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Error al buscar datos: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoadingStudent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoadingCycles) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos del Alumno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // Selector de Ciclo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              value: _schoolCycles.any((c) => c.id == _selectedCycle) ? _selectedCycle : null,
              items: _schoolCycles.map((cycle) => DropdownMenuItem(value: cycle.id, child: Text(cycle.id))).toList(),
              onChanged: (value) {
                if (value != null) _fetchStudentData(value);
              },
              decoration: InputDecoration(
                labelText: 'Seleccionar Ciclo Escolar',
                prefixIcon: const Icon(Icons.calendar_today_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoadingStudent 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _currentStudentData == null
                ? _buildFeedbackMessage(_errorMessage!, isError: true)
                : _currentStudentData == null
                  ? _buildFeedbackMessage("Selecciona un ciclo para ver los datos.")
                  : _buildProfileContent(theme, _currentStudentData!),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(ThemeData theme, Student student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: student.profileImageUrl != null
                      ? NetworkImage(student.profileImageUrl!)
                      : null,
                  child: student.profileImageUrl == null
                      ? Icon(Icons.person, size: 50, color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  student.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Matrícula: ${student.studentId}',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Información Académica'),
          _buildInfoTile(icon: Icons.school_outlined, title: 'Ciclo Escolar', subtitle: student.schoolCycle),
          _buildInfoTile(icon: Icons.group_outlined, title: 'Grupo', subtitle: student.group),
          const Divider(height: 32),
          _buildSectionHeader(theme, 'Información Personal'),
          _buildInfoTile(icon: Icons.cake_outlined, title: 'Edad', subtitle: '${student.age} años'),
          _buildInfoTile(icon: Icons.person_outline, title: 'Género', subtitle: student.gender),
          _buildInfoTile(icon: Icons.email_outlined, title: 'Correo Institucional', subtitle: student.institutionalEmail),
          _buildInfoTile(icon: Icons.phone_outlined, title: 'Teléfono del Alumno', subtitle: student.studentPhone ?? 'No registrado'),
          _buildInfoTile(icon: Icons.location_on_outlined, title: 'Lugar de Residencia', subtitle: student.placeOfResidence),
          const Divider(height: 32),
          _buildSectionHeader(theme, 'Información de Contacto y Salud'),
          _buildInfoTile(icon: Icons.family_restroom_outlined, title: 'Nombre del Tutor', subtitle: student.guardianFullName),
          _buildInfoTile(icon: Icons.phone_in_talk_outlined, title: 'Teléfono del Tutor', subtitle: student.guardianPhone),
          _buildInfoTile(icon: Icons.medical_services_outlined, title: 'NSS (Seguro Social)', subtitle: student.nss ?? 'No registrado'),
          _buildInfoTile(icon: Icons.warning_amber_rounded, title: 'Alergias', subtitle: student.allergies ?? 'Ninguna registrada', iconColor: Colors.amber),
          _buildInfoTile(icon: Icons.monitor_heart_outlined, title: 'Padecimientos', subtitle: student.healthConditions ?? 'Ninguno registrado'),
        ],
      ),
    );
  }

  Widget _buildFeedbackMessage(String message, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 64,
              color: isError ? Colors.red.shade300 : Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isError ? Colors.red.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle, Color? iconColor}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
