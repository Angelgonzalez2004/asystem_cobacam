import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/attendance_excel_exporter.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AttendanceQueryScreen extends StatefulWidget {
  const AttendanceQueryScreen({super.key});

  @override
  State<AttendanceQueryScreen> createState() => _AttendanceQueryScreenState();
}

class _AttendanceQueryScreenState extends State<AttendanceQueryScreen> {
  late final AppSettingsService _appSettingsService;
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;

  String? _campus;
  List<SchoolCycle> _schoolCycles = [];
  String? _selectedCycle;
  String? _selectedGroup;
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  // Cache masivo para rendimiento
  bool _isLoadingInitial = true;
  bool _isLoadingAttendance = false;
  
  // Mapa maestro de alumnos: <StudentId, StudentObj>
  Map<String, Student> _allStudentsMap = {};
  
  // Mapa de asistencia del día: <StudentId, RecordObj>
  Map<String, AttendanceRecord> _dailyAttendanceMap = {};
  
  // Lista de grupos disponibles (Strings)
  List<String> _availableGroups = [];

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInitial = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        _campus = userData['campus'];
      }

      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      _selectedCycle = await _appSettingsService.getCurrentSchoolCycleId();

      if (_campus != null && _selectedCycle != null) {
        // 1. Cargar TODOS los alumnos del ciclo (una sola vez)
        await _loadAllStudents();
        // 2. Cargar grupos basados en los alumnos
        _extractGroupsFromStudents();
        // 3. Cargar asistencia de la fecha seleccionada
        await _fetchDailyAttendance();
      }
    } catch (e) {
      debugPrint('Error inicializando: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadAllStudents() async {
    try {
      final ref = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedCycle');
      // Optimizacion: Usar once() en lugar de onValue para evitar reconstrucciones masivas constantes en esta pantalla
      final snap = await ref.get();
      
      final Map<String, Student> tempMap = {};
      if (snap.exists) {
        for (var child in snap.children) {
          final student = Student.fromSnapshot(child);
          if (student.isActive) { // Solo alumnos activos
            tempMap[student.studentId] = student;
          }
        }
      }
      _allStudentsMap = tempMap;
    } catch (e) {
      debugPrint('Error cargando alumnos: $e');
    }
  }

  void _extractGroupsFromStudents() {
    final Set<String> groups = {};
    for (var s in _allStudentsMap.values) {
      groups.add(s.group);
    }
    final sorted = groups.toList()..sort();
    if (mounted) setState(() => _availableGroups = sorted);
  }

  Future<void> _fetchDailyAttendance() async {
    if (_campus == null || _selectedCycle == null) return;
    if (mounted) setState(() => _isLoadingAttendance = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final ref = FirebaseDatabase.instance.ref('planteles/$_campus/attendance/$_selectedCycle/$dateStr');
      final snap = await ref.get();

      final Map<String, AttendanceRecord> tempAttendance = {};
      if (snap.exists) {
        for (var child in snap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          final record = AttendanceRecord.fromFirebaseMap(
            child.key!,
            dateStr,
            data,
            campusId: _campus!,
            schoolCycle: _selectedCycle!
          );
          tempAttendance[record.studentId] = record;
        }
      }
      
      if (mounted) setState(() => _dailyAttendanceMap = tempAttendance);
    } catch (e) {
      debugPrint('Error cargando asistencia: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  List<Student> _getFilteredStudents() {
    final query = _searchQuery.toLowerCase().trim();
    
    return _allStudentsMap.values.where((s) {
      // Filtro de Grupo
      if (_selectedGroup != null && s.group != _selectedGroup) return false;
      
      // Filtro de Buscador
      if (query.isNotEmpty) {
        final matchesName = s.fullName.toLowerCase().contains(query);
        final matchesId = s.studentId.contains(query);
        if (!matchesName && !matchesId) return false;
      }
      
      return true;
    }).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  }

  Future<void> _exportData() async {
    final list = _getFilteredStudents();
    if (list.isEmpty) {
      UiHelpers.showSnackBar(context, 'No hay datos para exportar.');
      return;
    }

    UiHelpers.showSnackBar(context, 'Generando Excel...');
    try {
      final path = await AttendanceExcelExporter.exportToExcel(
        students: list,
        attendanceMap: _dailyAttendanceMap,
        date: _selectedDate,
        cycle: _selectedCycle ?? 'S/C',
        groupFilter: _selectedGroup,
      );
      
      if (mounted) {
        if (path != null) {
          UiHelpers.showSnackBar(context, 'Reporte guardado en: $path', isError: false);
        } else {
          // Si es null pero no hubo excepción, puede ser que el usuario canceló o es web (ya descargó)
           UiHelpers.showSnackBar(context, 'Exportación completada.', isError: false);
        }
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error exportando: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredList = _getFilteredStudents();

    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
        children: [
                // --- PANEL DE FILTROS ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardColor : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Fila 1: Ciclo y Fecha
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCycle,
                              decoration: _inputDecoration('Ciclo', Icons.calendar_view_day_rounded),
                              items: _schoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() {
                                    _selectedCycle = val;
                                    _selectedGroup = null;
                                    _isLoadingInitial = true;
                                  });
                                  await _loadAllStudents();
                                  _extractGroupsFromStudents();
                                  await _fetchDailyAttendance();
                                  setState(() => _isLoadingInitial = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                  _fetchDailyAttendance();
                                }
                              },
                              child: Container(
                                height: 56, // Altura estándar de input
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Fecha', style: TextStyle(fontSize: 10, color: theme.hintColor)),
                                        Text(DateFormat('dd/MMM/yyyy', 'es_MX').format(_selectedDate), 
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Icon(Icons.event_rounded, color: theme.colorScheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Fila 2: Grupo y Buscador
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedGroup,
                              decoration: _inputDecoration('Grupo', Icons.groups_rounded),
                              hint: const Text('Todos'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos')),
                                ..._availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                              ],
                              onChanged: (val) => setState(() => _selectedGroup = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              decoration: _inputDecoration('Buscar Alumno', Icons.search_rounded),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Fila 3: Botón Exportar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: filteredList.isEmpty ? null : _exportData,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Exportar Reporte Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LISTA DE RESULTADOS ---
                Expanded(
                  child: _isLoadingAttendance
                      ? const Center(child: CircularProgressIndicator())
                      : filteredList.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final student = filteredList[index];
                                final record = _dailyAttendanceMap[student.studentId];
                                return _buildStudentCard(student, record, theme);
                              },
                            ),
                ),
                
                // --- FOOTER ESTADÍSTICO ---
                if (filteredList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: theme.colorScheme.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Total: ${filteredList.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Presentes: ${_countStatus(filteredList, 'presente')}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('Faltas: ${_countStatus(filteredList, 'falta')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            );
  }

  int _countStatus(List<Student> students, String type) {
    int count = 0;
    for (var s in students) {
      final record = _dailyAttendanceMap[s.studentId];
      if (type == 'falta') {
        if (record == null) count++;
      } else if (type == 'presente') {
        if (record != null && (record.status == 'presente' || record.status == 'presente_masivo' || record.status == 'tarde')) count++;
      }
    }
    return count;
  }

  Widget _buildStudentCard(Student student, AttendanceRecord? record, ThemeData theme) {
    final bool isAbsent = record == null;
    
    // Determinar estado visual
    Color statusColor = Colors.grey;
    String statusText = 'SIN REGISTRO';
    IconData statusIcon = Icons.help_outline;

    if (isAbsent) {
      statusColor = Colors.red;
      statusText = 'FALTA';
      statusIcon = Icons.cancel_outlined;
    } else {
      if (record.status == 'tarde') {
        statusColor = Colors.orange;
        statusText = 'RETARDO';
        statusIcon = Icons.access_time_filled;
      } else if (record.status == 'presente' || record.status == 'presente_masivo') {
        statusColor = Colors.green;
        statusText = 'PRESENTE';
        statusIcon = Icons.check_circle;
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile( // CAMBIO A EXPANSION TILE
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        childrenPadding: EdgeInsets.zero,
        title: Column(
          children: [
            // Header Tarjeta (Igual que antes)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      student.fullName.isNotEmpty ? student.fullName[0] : '?',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${student.studentId} • ${student.group} • ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                          style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Body Tarjeta (Horarios)
            if (!isAbsent)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _buildTimeBox('ENTRADA', record.entryTime, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimeBox('SALIDA', record.exitTime, Colors.orange)),
                  ],
                ),
              ),

             // Motivos (Si existen)
            if (record != null && (record.reasonTardy != null || record.reasonEarlyExit != null))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.reasonTardy != null)
                      _buildReasonRow('Motivo Retardo:', record.reasonTardy!, Colors.orange),
                    if (record.reasonEarlyExit != null)
                      _buildReasonRow('Motivo Salida:', record.reasonEarlyExit!, Colors.red),
                  ],
                ),
              ),
          ],
        ),
        
        // --- DETALLES EXPANDIBLES ---
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Información Completa del Alumno', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.person_outline, 'Tutor', student.guardianFullName),
                _buildInfoRow(Icons.phone, 'Tel. Tutor', student.guardianPhone),
                _buildInfoRow(Icons.phone_android, 'Tel. Alumno', student.studentPhone ?? 'No registrado'),
                _buildInfoRow(Icons.home_outlined, 'Residencia', student.placeOfResidence),
                _buildInfoRow(Icons.medical_services_outlined, 'Salud/Alergias', 
                    '${student.allergies ?? ''} ${student.healthConditions ?? ''}'.trim().isEmpty 
                    ? 'Ninguna' 
                    : '${student.allergies ?? ''} ${student.healthConditions ?? ''}'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, String? time, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: time != null ? color.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 14, color: time != null ? color : Colors.grey.shade300),
              const SizedBox(width: 6),
              Text(
                time ?? '--:--',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: time != null ? Colors.black87 : Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonRow(String label, String reason, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(child: Text(reason, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, size: 64, color: theme.dividerColor),
          const SizedBox(height: 16),
          Text(
            'No se encontraron alumnos con los filtros actuales.',
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
