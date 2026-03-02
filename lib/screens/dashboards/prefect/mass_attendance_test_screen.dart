import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:provider/provider.dart';

class MassAttendanceTestScreen extends StatefulWidget {
  final String? campus;
  const MassAttendanceTestScreen({super.key, this.campus});

  @override
  State<MassAttendanceTestScreen> createState() => _MassAttendanceTestScreenState();
}

class _MassAttendanceTestScreenState extends State<MassAttendanceTestScreen> {
  late final AppSettingsService _appSettingsService;
  late final HiveService _hiveService;
  
  bool _isLoading = true;
  List<SchoolCycle> _allCycles = [];
  SchoolCycle? _selectedCycle;
  DateTime _selectedDate = DateTime.now();
  List<Student> _allStudents = [];
  List<Group> _groups = [];
  Map<String, GroupSchedule> _groupSchedulesMap = {};
  List<NonAttendanceDay> _nonAttendanceDays = [];
  
  // Form State
  String _selectedType = 'entry'; 
  String _selectedScope = 'all'; 
  String? _selectedGroupId;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedStatus = 'presente';
  bool _overrideExisting = false;
  bool _useScheduledTime = false;

  Map<String, bool> _selectedStudentsMap = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, connectivity);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _allCycles = await _appSettingsService.getAllSchoolCycles();
      final currentId = await _appSettingsService.getCurrentSchoolCycleId();
      
      try {
        _selectedCycle = _allCycles.firstWhere((c) => c.id == currentId);
      } catch (_) {
        if (_allCycles.isNotEmpty) _selectedCycle = _allCycles.first;
      }

      if (_selectedCycle != null) {
        await _fetchCycleData(_selectedCycle!.id);
      }
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error inicial: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCycleData(String cycleId) async {
    if (widget.campus == null) return;
    
    final studentsRef = FirebaseDatabase.instance
        .ref('planteles/${widget.campus}/students/$cycleId');
    final studentsSnapshot = await studentsRef.get();
    
    List<Student> fetchedStudents = [];
    if (studentsSnapshot.exists) {
      for (final child in studentsSnapshot.children) {
        fetchedStudents.add(Student.fromSnapshot(child));
      }
    }
    fetchedStudents.sort((a, b) => a.fullName.compareTo(b.fullName));

    final groupsRef = FirebaseDatabase.instance.ref('planteles/${widget.campus}/groups');
    final groupsSnapshot = await groupsRef.orderByChild('schoolCycleId').equalTo(cycleId).get();
    
    List<Group> fetchedGroups = [];
    if (groupsSnapshot.exists) {
      for (final child in groupsSnapshot.children) {
        fetchedGroups.add(Group.fromSnapshot(child));
      }
    }

    final schedulesRef = FirebaseDatabase.instance.ref('planteles/${widget.campus}/schedules/$cycleId');
    final schedulesSnapshot = await schedulesRef.get();
    
    Map<String, GroupSchedule> fetchedSchedules = {};
    if (schedulesSnapshot.exists) {
      for (final child in schedulesSnapshot.children) {
        fetchedSchedules[child.key!] = GroupSchedule.fromSnapshot(child);
      }
    }

    _nonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(widget.campus!);

    setState(() {
      _allStudents = fetchedStudents;
      _groups = fetchedGroups;
      _groupSchedulesMap = fetchedSchedules;
      _selectedGroupId = null;
      _resetSelection();
    });
  }

  void _resetSelection() {
    _selectedStudentsMap = {for (var s in _allStudents) s.studentId : true};
  }

  List<Student> _getFilteredStudents() {
    return _allStudents.where((s) {
      bool matchesGroup = _selectedScope == 'all' || s.group == _selectedGroupId;
      bool matchesSearch = s.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                          s.studentId.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList();
  }

  String? _getStudentScheduledTime(Student student, String type, DateTime date) {
    String? groupId;
    try {
      groupId = _groups.firstWhere((g) => g.name == student.group).key;
    } catch (_) {
      return null;
    }

    final schedule = _groupSchedulesMap[groupId];
    if (schedule == null) return null;

    final dayNames = {
      DateTime.monday: 'lunes',
      DateTime.tuesday: 'martes',
      DateTime.wednesday: 'miércoles',
      DateTime.thursday: 'jueves',
      DateTime.friday: 'viernes',
    };
    
    final String? dayName = dayNames[date.weekday];
    if (dayName == null) return null;

    final List<ClassSession>? daySessions = schedule.dailySchedules[dayName];
    if (daySessions == null || daySessions.isEmpty) return null;

    if (type == 'entry') {
      final first = daySessions.reduce((a, b) => a.startTime.compareTo(b.startTime) < 0 ? a : b);
      return first.startTime;
    } else {
      final last = daySessions.reduce((a, b) => a.endTime.compareTo(b.endTime) > 0 ? a : b);
      return last.endTime;
    }
  }

  bool _isDayValidForAttendance(DateTime date, Function(String) onError) {
    final dayOfWeek = date.weekday;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      onError('La fecha seleccionada es fin de semana.');
      return false;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (_nonAttendanceDays.any((day) {
      final dayStr = DateFormat('yyyy-MM-dd').format(day.date);
      return dayStr == dateStr;
    })) {
      onError('La fecha seleccionada es DÍA NO LECTIVO.');
      return false;
    }
    return true;
  }

  Future<void> _executeMassAttendance() async {
    if (_selectedCycle == null) return;
    if (!_isDayValidForAttendance(_selectedDate, (msg) => UiHelpers.showSnackBar(context, msg, isError: true))) {
      return;
    }

    final List<Student> studentsToProcess = _allStudents.where((s) {
      if (!s.isActive) return false;
      if (_selectedScope == 'group' && s.group != _selectedGroupId) return false;
      return _selectedStudentsMap[s.studentId] == true;
    }).toList();

    if (studentsToProcess.isEmpty) {
      UiHelpers.showSnackBar(context, 'No hay alumnos seleccionados.', isError: true);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Registro Masivo'),
        content: Text(
          '¿Registrar ${_selectedType == 'entry' ? 'ENTRADA' : 'SALIDA'} para '
          '${studentsToProcess.length} alumnos?\n\n'
          'CICLO: ${_selectedCycle!.id}\n'
          'FECHA: $dateStr\n'
          'HORA: ${_useScheduledTime ? "SEGÚN HORARIO" : _selectedTime.format(context)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('EJECUTAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final attendanceRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campus}/attendance/${_selectedCycle!.id}/$dateStr');
      
      final existingSnapshot = await attendanceRef.get();
      Map<String, dynamic> existingRecords = {};
      if (existingSnapshot.exists) {
        existingRecords = Map<String, dynamic>.from(existingSnapshot.value as Map);
      }

      final Map<String, dynamic> updates = {};
      final String manualTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      int count = 0;

      for (var student in studentsToProcess) {
        final studentId = student.studentId;
        Map<String, dynamic> record = {};
        if (existingRecords.containsKey(studentId)) {
          record = Map<String, dynamic>.from(existingRecords[studentId]);
        }

        String timeToUse = manualTime;
        if (_useScheduledTime) {
          final scheduledTime = _getStudentScheduledTime(student, _selectedType, _selectedDate);
          if (scheduledTime != null) {
            timeToUse = scheduledTime;
          } else {
            continue;
          }
        }

        bool shouldUpdate = false;
        if (_selectedType == 'entry') {
          if (!record.containsKey('entryTime') || _overrideExisting) {
            record['entryTime'] = timeToUse;
            record['status'] = _selectedStatus;
            shouldUpdate = true;
          }
        } else {
          if (!record.containsKey('exitTime') || _overrideExisting) {
            record['exitTime'] = timeToUse;
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          record['studentFullName'] = student.fullName;
          record['group'] = student.group;
          record['campusId'] = widget.campus;
          record['schoolCycle'] = _selectedCycle!.id;
          record['date'] = dateStr;
          record['studentId'] = studentId;
          updates[studentId] = record;
          count++;
        }
      }

      if (updates.isNotEmpty) {
        await attendanceRef.update(updates);
        UiHelpers.showSnackBar(context, '¡Listo! $count alumnos registrados.');
      } else {
        UiHelpers.showSnackBar(context, 'No hubo cambios.', isError: true);
      }
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllAttendance() async {
    if (_selectedCycle == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ LIMPIEZA TOTAL'),
        content: Text('¿Borrar todas las asistencias del ciclo ${_selectedCycle!.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final attendanceRef = FirebaseDatabase.instance.ref(
          'planteles/${widget.campus}/attendance/${_selectedCycle!.id}');
      await attendanceRef.remove();
      UiHelpers.showSnackBar(context, 'Limpieza completada.');
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredStudents = _getFilteredStudents();
    
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(theme),
                const SizedBox(height: 24),
                
                Text('1. Configuración del Rango', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                
                const Text('Ciclo Escolar:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<SchoolCycle>(
                  value: _selectedCycle,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.history_edu), isDense: true),
                  items: _allCycles.map((c) => DropdownMenuItem(value: c, child: Text("Ciclo ${c.id}"))).toList(),
                  onChanged: (cycle) {
                    if (cycle != null) {
                      setState(() {
                        _selectedCycle = cycle;
                        _fetchCycleData(cycle.id);
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 20),
                _buildDateSelector(theme),
                const Divider(height: 40),
                
                Text('2. Datos de Asistencia', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildTypeSelector(),
                _buildScopeSelector(),
                const SizedBox(height: 20),
                _buildTimeConfig(theme),
                const Divider(height: 40),
                
                Text('3. Selección de Alumnos', style: theme.textTheme.titleLarge),
                const Text('Filtra por nombre o matrícula y marca a los asistentes.', 
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),

                _buildStudentSelectionArea(theme, filteredStudents),

                const SizedBox(height: 24),
                _buildExtraOptions(),
                const SizedBox(height: 32),
                
                _buildExecuteButton(theme, filteredStudents),
                const SizedBox(height: 48),
                _buildDangerZone(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeaderBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.bug_report, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'HERRAMIENTA DE PRUEBAS: Digitalización Masiva de Listas Físicas.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fecha del Registro:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: _selectedCycle?.startDate ?? DateTime(2024),
              lastDate: _selectedCycle?.endDate ?? DateTime.now(),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, d ' 'MMMM' ' yyyy', 'es_MX').format(_selectedDate).toUpperCase(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Entrada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: 'entry',
            groupValue: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Salida', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: 'exit',
            groupValue: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filtrar Alumnos por:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedScope,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_alt_outlined), isDense: true),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Todo el Plantel')),
            DropdownMenuItem(value: 'group', child: Text('Grupo Específico')),
          ],
          onChanged: (v) => setState(() {
            _selectedScope = v!;
            if (v == 'all') _selectedGroupId = null;
          }),
        ),
        if (_selectedScope == 'group') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedGroupId,
            hint: const Text('Seleccionar el Grupo'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.groups_outlined), isDense: true),
            items: _groups.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))).toList(),
            onChanged: (v) => setState(() => _selectedGroupId = v),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeConfig(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configuración de Hora:', style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Usar hora automática (Horario)', style: TextStyle(fontSize: 14)),
          value: _useScheduledTime,
          activeColor: theme.colorScheme.primary,
          onChanged: (v) => setState(() => _useScheduledTime = v),
        ),
        if (!_useScheduledTime) 
          InkWell(
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: _selectedTime);
              if (time != null) setState(() => _selectedTime = time);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time),
                  const SizedBox(width: 8),
                  Text(_selectedTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Text('Cambiar Hora Manual', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudentSelectionArea(ThemeData theme, List<Student> students) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Nombre o Matrícula...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var s in students) {
                        _selectedStudentsMap[s.studentId] = true;
                      }
                    });
                  },
                  child: const Text('Marcar Todos'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var s in students) {
                        _selectedStudentsMap[s.studentId] = false;
                      }
                    });
                  },
                  child: const Text('Desmarcar Todos'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 350,
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = students[index];
                return CheckboxListTile(
                  title: Text(student.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text('Matrícula: ${student.studentId} | Grupo: ${student.group}', style: const TextStyle(fontSize: 10)),
                  value: _selectedStudentsMap[student.studentId] ?? false,
                  onChanged: (val) => setState(() => _selectedStudentsMap[student.studentId] = val!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraOptions() {
    return Column(
      children: [
        if (_selectedType == 'entry') 
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(labelText: 'Estado de Entrada', isDense: true),
            items: const [
              DropdownMenuItem(value: 'presente', child: Text('Presente')),
              DropdownMenuItem(value: 'tarde', child: Text('Retardo')),
              DropdownMenuItem(value: 'ausente', child: Text('Ausente')),
            ],
            onChanged: (v) => setState(() => _selectedStatus = v!),
          ),
        CheckboxListTile(
          title: const Text('Sobrescribir registros previos', style: TextStyle(fontSize: 13)),
          value: _overrideExisting,
          onChanged: (v) => setState(() => _overrideExisting = v!),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildExecuteButton(ThemeData theme, List<Student> students) {
    int count = students.where((s) => _selectedStudentsMap[s.studentId] == true).length;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _executeMassAttendance,
        icon: const Icon(Icons.bolt_sharp),
        label: Text('REGISTRAR $count ALUMNOS EN CICLO ${_selectedCycle?.id ?? ""}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 2, color: Colors.redAccent),
        const Text('ZONA DE PELIGRO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _clearAllAttendance,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('BORRAR ASISTENCIAS DEL CICLO', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
