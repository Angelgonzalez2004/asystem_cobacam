import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
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

enum FilterMode { day, week, cycle }

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
  List<Group> _dbGroups = [];
  List<NonAttendanceDay> _nonAttendanceDays = [];
  
  String? _selectedCycle;
  String? _selectedGroup; // Null = Todos
  
  FilterMode _filterMode = FilterMode.day;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedWeekRange;

  bool _isLoadingInitial = true;
  bool _isLoadingAttendance = false;
  
  Map<String, Student> _allStudentsMap = {};
  Map<String, List<AttendanceRecord>> _attendanceData = {};

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    
    // Inicializar rango de semana actual (Lunes a Viernes)
    _calculateCurrentWeek();
    
    _loadInitialData();
  }

  void _calculateCurrentWeek() {
    final now = DateTime.now();
    // Ajustar al Lunes
    final diff = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: diff));
    final friday = monday.add(const Duration(days: 4));
    _selectedWeekRange = DateTimeRange(
      start: DateTime(monday.year, monday.month, monday.day), 
      end: DateTime(friday.year, friday.month, friday.day)
    );
  }

  Future<void> _loadInitialData() async {
    // Nota: El loading se maneja en el build con _isLoadingInitial
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        _campus = userData['campus'];
      }

      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      final currentCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      
      // Validar si el ciclo actual existe en la lista
      if (_schoolCycles.any((c) => c.id == currentCycleId)) {
        _selectedCycle = currentCycleId;
      } else if (_schoolCycles.isNotEmpty) {
        _selectedCycle = _schoolCycles.first.id;
      }

      if (_campus != null) {
         _nonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(_campus!);
      }

      if (_campus != null && _selectedCycle != null) {
        await _loadGroupsAndStudents();
        await _fetchAttendanceData();
      }
    } catch (e) {
      debugPrint('Error inicializando: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadGroupsAndStudents() async {
    try {
      if (_selectedCycle == null) return;
      
      // 1. Cargar Grupos del ciclo seleccionado
      final groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
      final groupsSnap = await groupsRef.get();
      
      final List<Group> groups = [];
      if (groupsSnap.exists) {
        for (var child in groupsSnap.children) {
          final g = Group.fromSnapshot(child);
          if (g.schoolCycleId == _selectedCycle) {
             groups.add(g);
          }
        }
      }
      groups.sort((a, b) => a.name.compareTo(b.name));
      
      // 2. Cargar Alumnos
      final studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedCycle');
      final studentsSnap = await studentsRef.get();
      final Map<String, Student> studentsMap = {};
      if (studentsSnap.exists) {
        for (var child in studentsSnap.children) {
          final s = Student.fromSnapshot(child);
          if (s.isActive) studentsMap[s.studentId] = s;
        }
      }

      if (mounted) {
        setState(() {
          _dbGroups = groups;
          _allStudentsMap = studentsMap;
          // Resetear grupo si no existe en la nueva lista
          if (_selectedGroup != null && !_dbGroups.any((g) => g.name == _selectedGroup)) {
            _selectedGroup = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando grupos/alumnos: $e');
    }
  }

  Future<void> _fetchAttendanceData() async {
    if (_campus == null || _selectedCycle == null) return;
    setState(() => _isLoadingAttendance = true);

    try {
      DateTime start, end;

      if (_filterMode == FilterMode.day) {
        start = _selectedDate;
        end = _selectedDate;
      } else if (_filterMode == FilterMode.week) {
        start = _selectedWeekRange!.start;
        end = _selectedWeekRange!.end;
      } else {
        final cycleObj = _schoolCycles.firstWhere((c) => c.id == _selectedCycle);
        start = cycleObj.startDate;
        final now = DateTime.now();
        end = now.isBefore(cycleObj.endDate) ? now : cycleObj.endDate;
      }

      final Map<String, List<AttendanceRecord>> tempMap = {};
      final daysCount = end.difference(start).inDays + 1;

      for (var i = 0; i < daysCount; i++) {
        final date = start.add(Duration(days: i));
        if (_filterMode != FilterMode.cycle && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) continue;
        
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        final ref = FirebaseDatabase.instance.ref('planteles/$_campus/attendance/$_selectedCycle/$dateStr');
        final snap = await ref.get();

        if (snap.exists) {
          for (var child in snap.children) {
            final data = Map<String, dynamic>.from(child.value as Map);
            final record = AttendanceRecord.fromFirebaseMap(
              child.key!, dateStr, data, campusId: _campus!, schoolCycle: _selectedCycle!
            );
            
            if (!tempMap.containsKey(record.studentId)) {
              tempMap[record.studentId] = [];
            }
            tempMap[record.studentId]!.add(record);
          }
        }
      }

      if (mounted) setState(() => _attendanceData = tempMap);

    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  bool _isDaySelectable(DateTime day) {
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) return false;
    return !_nonAttendanceDays.any((d) => 
      d.date.year == day.year && d.date.month == day.month && d.date.day == day.day
    );
  }

  Future<void> _pickDate() async {
    if (_selectedCycle == null) return;
    final cycleObj = _schoolCycles.firstWhere((c) => c.id == _selectedCycle);
    
    final start = cycleObj.startDate;
    final end = cycleObj.endDate;

    DateTime initial = _selectedDate;
    if (initial.isBefore(start)) initial = start;
    if (initial.isAfter(end)) initial = end;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: end,
      selectableDayPredicate: _isDaySelectable,
      locale: const Locale('es', 'MX'),
      helpText: 'SELECCIONA UN DÍA (DENTRO DEL CICLO)',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _filterMode = FilterMode.day;
      });
      _fetchAttendanceData();
    }
  }

  Future<void> _pickWeek() async {
    if (_selectedCycle == null) return;
    final cycleObj = _schoolCycles.firstWhere((c) => c.id == _selectedCycle);
    
    final start = cycleObj.startDate;
    final end = cycleObj.endDate;

    // Usamos un DatePicker normal, pero calculamos la semana completa basada en el día seleccionado
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekRange?.start ?? DateTime.now(),
      firstDate: start,
      lastDate: end,
      selectableDayPredicate: _isDaySelectable, // Corregido: Ahora respeta días no lectivos
      locale: const Locale('es', 'MX'),
      helpText: 'SELECCIONA CUALQUIER DÍA PARA MARCAR LA SEMANA',
    );

    if (picked != null) {
      // Calcular Lunes y Viernes de esa semana
      final diffToMon = picked.weekday - DateTime.monday;
      final monday = picked.subtract(Duration(days: diffToMon));
      final friday = monday.add(const Duration(days: 4));

      // Ajustar límites al ciclo escolar (si la semana empieza antes o termina después del ciclo)
      final validStart = monday.isBefore(start) ? start : monday;
      final validEnd = friday.isAfter(end) ? end : friday;

      setState(() {
        _selectedWeekRange = DateTimeRange(start: validStart, end: validEnd);
        _filterMode = FilterMode.week;
      });
      
      _fetchAttendanceData();
      
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Semana seleccionada: ${DateFormat('dd/MM').format(validStart)} al ${DateFormat('dd/MM').format(validEnd)}');
      }
    }
  }

  // --- LOGIC: STATS CALCULATION ---

  Map<String, dynamic> _calculateStudentStats(Student student) {
    DateTime start, end;
    if (_filterMode == FilterMode.day) {
      start = _selectedDate;
      end = _selectedDate;
    } else if (_filterMode == FilterMode.week) {
      start = _selectedWeekRange!.start;
      end = _selectedWeekRange!.end;
    } else {
      final cycleObj = _schoolCycles.firstWhere((c) => c.id == _selectedCycle);
      start = cycleObj.startDate;
      final now = DateTime.now();
      end = now.isBefore(cycleObj.endDate) ? now : cycleObj.endDate;
    }

    int faults = 0;
    int presences = 0;
    int lates = 0;
    List<Map<String, dynamic>> details = [];

    final daysTotal = end.difference(start).inDays + 1;
    final records = _attendanceData[student.studentId] ?? [];

    for (var i = 0; i < daysTotal; i++) {
      final date = start.add(Duration(days: i));
      if (date.isAfter(DateTime.now())) break;

      if (date.weekday >= 6) continue;
      if (_nonAttendanceDays.any((d) => d.date.year == date.year && d.date.month == date.month && d.date.day == date.day)) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final record = records.firstWhere(
        (r) => r.date == dateStr, 
        orElse: () => AttendanceRecord.empty()
      );

      if (record.id.isNotEmpty && record.status != 'null') {
         presences++;
         if (record.status == 'tarde') lates++;
         details.add({'date': date, 'status': 'presente', 'record': record});
      } else {
         faults++;
         details.add({'date': date, 'status': 'falta', 'record': null});
      }
    }

    String alertLevel = 'none';
    if (faults == 2) alertLevel = 'warning';
    if (faults >= 3) alertLevel = 'urgent';

    return {
      'faults': faults,
      'presences': presences,
      'lates': lates,
      'alertLevel': alertLevel,
      'details': details
    };
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingInitial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(strokeWidth: 6, color: Colors.blue, strokeCap: StrokeCap.round),
            ),
            const SizedBox(height: 32),
            Text('Consultando datos...', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Espere unos segundos por favor.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final filteredStudents = _allStudentsMap.values.where((s) {
      if (_selectedGroup != null && s.group != _selectedGroup) return false;
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = s.fullName.toLowerCase();
        final id = s.studentId.toLowerCase();
        return name.contains(query) || id.contains(query);
      }
      return true;
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? theme.cardColor : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCycle,
                      decoration: _deco('Ciclo', Icons.calendar_view_day),
                      isDense: true,
                      items: _schoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() { _selectedCycle = val; _selectedGroup = null; });
                          
                          showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildLoadingOverlay());
                          
                          _loadGroupsAndStudents().then((_) => _fetchAttendanceData()).then((_) {
                             if (mounted) Navigator.of(context, rootNavigator: true).pop();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedGroup,
                      decoration: _deco('Grupo', Icons.groups),
                      isDense: true,
                      hint: const Text('Todos los Grupos'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos los Grupos', style: TextStyle(fontWeight: FontWeight.bold))),
                        ..._dbGroups.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))),
                      ],
                      onChanged: (val) {
                         setState(() => _selectedGroup = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Día', FilterMode.day, Icons.today, _pickDate),
                    const SizedBox(width: 8),
                    _filterChip('Semana', FilterMode.week, Icons.date_range, _pickWeek),
                    const SizedBox(width: 8),
                    _filterChip('Ciclo Completo', FilterMode.cycle, Icons.loop, () {
                      setState(() => _filterMode = FilterMode.cycle);
                      _fetchAttendanceData();
                    }),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            _getRangeLabel(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: _deco('Buscar Alumno...', Icons.search).copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12)),
                      onChanged: (v) => setState((){}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoadingAttendance ? null : _exportExcel,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Exportar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  )
                ],
              )
            ],
          ),
        ),

        Expanded(
          child: _isLoadingAttendance
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 5, color: Colors.blue, strokeCap: StrokeCap.round)),
                    const SizedBox(height: 24),
                    Text(
                      _filterMode == FilterMode.cycle ? 'Analizando historial completo...' : 'Consultando datos...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                    ),
                    const SizedBox(height: 8),
                    const Text('Esto puede tardar unos segundos.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            : filteredStudents.isEmpty
               ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 64, color: Colors.grey.shade300), const Text('No se encontraron alumnos')]))
               : ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: filteredStudents.length,
                   itemBuilder: (context, index) {
                     return _StudentAttendanceCard(
                       student: filteredStudents[index],
                       stats: _calculateStudentStats(filteredStudents[index]),
                       onTap: () => _showStudentDetail(filteredStudents[index]),
                     );
                   },
                 ),
        )
      ],
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _filterChip(String label, FilterMode mode, IconData icon, VoidCallback onTap) {
    final isSelected = _filterMode == mode;
    return ChoiceChip(
      label: Row(children: [Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 6), Text(label)]),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
    );
  }

  String _getRangeLabel() {
    if (_filterMode == FilterMode.day) {
      return DateFormat('EEEE dd/MM/yyyy', 'es_MX').format(_selectedDate).toUpperCase();
    } else if (_filterMode == FilterMode.week) {
      return 'Semana: ${DateFormat('dd/MM').format(_selectedWeekRange!.start)} - ${DateFormat('dd/MM').format(_selectedWeekRange!.end)}';
    } else {
      return 'Todo el Ciclo Escolar $_selectedCycle';
    }
  }

  void _showStudentDetail(Student s) {
    final stats = _calculateStudentStats(s);
    final details = stats['details'] as List<Map<String, dynamic>>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, child: Text(s.fullName.isNotEmpty ? s.fullName[0] : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${s.studentId} • ${s.group}', style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip: 'Reporte Individual',
                    onPressed: () {
                      _showExportConfirmation([s], isIndividual: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('INFORMACIÓN PERSONAL'),
                    _infoGrid([
                      _infoItem(Icons.cake, 'Edad', '${s.age} años'),
                      _infoItem(Icons.wc, 'Género', s.gender),
                      _infoItem(Icons.health_and_safety, 'NSS', s.nss ?? 'N/A'),
                      _infoItem(Icons.email_outlined, 'Correo', s.institutionalEmail),
                      _infoItem(Icons.home_outlined, 'Domicilio', s.placeOfResidence),
                      _infoItem(Icons.calendar_today, 'Ciclo', s.schoolCycle),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('CONTACTO & TUTOR'),
                    _infoGrid([
                      _infoItem(Icons.family_restroom, 'Tutor', s.guardianFullName),
                      _infoItem(Icons.phone, 'Tel. Tutor', s.guardianPhone),
                      _infoItem(Icons.phone_android, 'Tel. Alumno', s.studentPhone ?? 'N/A'),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('ESTADO ACADÉMICO'),
                    _infoGrid([
                      _infoItem(s.isActive ? Icons.check_circle : Icons.error_outline, 'Estatus', s.isActive ? 'ACTIVO' : 'BAJA'),
                      if (!s.isActive) _infoItem(Icons.info_outline, 'Motivo Baja', s.deactivationReason ?? 'No especificado'),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('MÉDICO'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.withOpacity(0.2))),
                      child: Column(children: [
                        _infoRowFull(Icons.favorite, 'Estado General:', s.generalHealthStatus ?? 'Sano'),
                        const SizedBox(height: 8),
                        _infoRowFull(Icons.warning_amber_rounded, 'Alergias:', s.allergies ?? 'Ninguna'),
                        const SizedBox(height: 8),
                        _infoRowFull(Icons.medical_services_outlined, 'Condiciones:', s.healthConditions ?? 'Ninguna'),
                        if (s.medicalAlert) ...[
                           const SizedBox(height: 8),
                           Row(children: [
                             Icon(Icons.add_alert, color: Colors.red, size: 16),
                             const SizedBox(width: 8),
                             const Text('ALERTA MÉDICA ACTIVA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                           ])
                        ]
                      ]),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('ASISTENCIAS (${_getRangeLabel()})'),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: details.length,
                      itemBuilder: (ctx, i) {
                        final d = details[i];
                        final isAbsent = d['status'] == 'falta';
                        final rec = d['record'] as AttendanceRecord?;
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: isAbsent ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(isAbsent ? Icons.close : Icons.check, color: isAbsent ? Colors.red : Colors.green),
                          ),
                          title: Text(DateFormat('EEEE dd/MM', 'es_MX').format(d['date']).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: rec != null && !isAbsent 
                             ? Text('Entrada: ${rec.entryTime} - Salida: ${rec.exitTime ?? "-"}') 
                             : const Text('Ausencia registrada'),
                          trailing: rec != null && rec.status == 'tarde' 
                             ? const Chip(label: Text('Retardo', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.orange)
                             : null,
                        );
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            )
          ],
        ),
      )
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)));

  Widget _infoGrid(List<Widget> children) => Wrap(spacing: 16, runSpacing: 16, children: children);

  Widget _infoItem(IconData icon, String label, String value) => SizedBox(
    width: 140,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ],
    ),
  );

  Widget _infoRowFull(IconData icon, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: Colors.blueGrey),
    const SizedBox(width: 8),
    SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
  ]);

  Future<void> _exportExcel() async {
    String? tempCycle = _selectedCycle;
    String? tempGroup = _selectedGroup;
    FilterMode tempMode = _filterMode;
    DateTime tempDate = _selectedDate;
    DateTimeRange? tempWeek = _selectedWeekRange;
    Student? targetStudent;
    String exportScope = (tempGroup == null) ? 'all' : 'group';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [Icon(Icons.analytics_outlined, color: Colors.blue, size: 28), SizedBox(width: 12), Text('Generar Reporte Excel')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Configura los parámetros del reporte que deseas descargar.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: tempCycle,
                  decoration: _deco('Ciclo Escolar', Icons.calendar_month),
                  items: _schoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
                  onChanged: (val) => setDialogState(() => tempCycle = val),
                ),
                const SizedBox(height: 12),

                SegmentedButton<FilterMode>(
                  segments: const [
                    ButtonSegment(value: FilterMode.day, label: Text('Día'), icon: Icon(Icons.today)),
                    ButtonSegment(value: FilterMode.week, label: Text('Semana'), icon: Icon(Icons.date_range)),
                    ButtonSegment(value: FilterMode.cycle, label: Text('Ciclo'), icon: Icon(Icons.all_inclusive)),
                  ],
                  selected: {tempMode},
                  onSelectionChanged: (val) => setDialogState(() => tempMode = val.first),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: exportScope,
                  decoration: _deco('Alcance del Reporte', Icons.person_search),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todo el Plantel')),
                    DropdownMenuItem(value: 'group', child: Text('Por Grupo Específico')),
                    DropdownMenuItem(value: 'student', child: Text('Alumno Específico')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      exportScope = val!;
                      if (val == 'all') { tempGroup = null; targetStudent = null; }
                      if (val == 'group') { targetStudent = null; tempGroup = _dbGroups.isNotEmpty ? _dbGroups.first.name : null; }
                      if (val == 'student') { tempGroup = null; targetStudent = null; }
                    });
                  },
                ),
                const SizedBox(height: 12),

                if (exportScope == 'group')
                  DropdownButtonFormField<String>(
                    value: tempGroup,
                    decoration: _deco('Seleccionar Grupo', Icons.groups_3_outlined),
                    items: _dbGroups.map((g) => DropdownMenuItem(value: g.name, child: Text('Grupo ${g.name}'))).toList(),
                    onChanged: (val) => setDialogState(() => tempGroup = val),
                  ),

                if (exportScope == 'student')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        Autocomplete<Student>(
                          displayStringForOption: (s) => s.fullName,
                          optionsBuilder: (text) => _allStudentsMap.values.where((s) => s.fullName.toLowerCase().contains(text.text.toLowerCase()) || s.studentId.contains(text.text)),
                          onSelected: (s) => setDialogState(() => targetStudent = s),
                          fieldViewBuilder: (ctx, ctrl, node, onSub) => TextField(
                            controller: ctrl, focusNode: node,
                            decoration: _deco('Nombre o Matrícula', Icons.search).copyWith(suffixIcon: targetStudent != null ? const Icon(Icons.check_circle, color: Colors.green) : null),
                          ),
                        ),
                        if (targetStudent != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              backgroundColor: Colors.blue.shade50,
                              label: Text(targetStudent!.fullName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onDeleted: () => setDialogState(() => targetStudent = null),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Generar Excel'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (exportScope == 'group' && tempGroup == null) return;
                if (exportScope == 'student' && targetStudent == null) return;
                
                Navigator.pop(context);
                
                List<Student> exportList;
                if (exportScope == 'student') {
                  exportList = [targetStudent!];
                } else if (exportScope == 'group') {
                  exportList = _allStudentsMap.values.where((s) => s.group == tempGroup).toList();
                } else {
                  exportList = _allStudentsMap.values.toList();
                }

                _processExport(
                  exportList, 
                  isIndividual: exportScope == 'student',
                  overrideCycle: tempCycle,
                  overrideMode: tempMode,
                  overrideDate: tempDate,
                  overrideWeek: tempWeek,
                );
              },
            )
          ],
        ),
      ),
    );
  }

  void _showExportConfirmation(List<Student> students, {required bool isIndividual}) {
    // Wrapper simple para reutilizar la lógica de exportación desde otros puntos (ej. botón individual)
    // En este caso, simplemente llamamos al proceso directo porque la confirmación ya es implícita al tocar el botón
    _processExport(students, isIndividual: isIndividual);
  }

  Future<void> _processExport(
    List<Student> students, {
    bool isIndividual = false,
    String? overrideCycle,
    FilterMode? overrideMode,
    DateTime? overrideDate,
    DateTimeRange? overrideWeek,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingOverlay(),
    );

    await Future.delayed(const Duration(milliseconds: 1200)); 
    
    final targetCycle = overrideCycle ?? _selectedCycle;
    final targetMode = overrideMode ?? _filterMode;
    final targetDate = overrideDate ?? _selectedDate;
    final targetWeek = overrideWeek ?? _selectedWeekRange;

    final Map<String, Map<String, dynamic>> computedStats = {};
    for (var s in students) {
      computedStats[s.studentId] = _calculateStudentStatsForExport(
        s, 
        cycle: targetCycle!,
        mode: targetMode,
        date: targetDate,
        week: targetWeek
      );
    }

    try {
      await AttendanceExcelExporter.exportAdvancedReport(
        context: context,
        students: students,
        stats: computedStats,
        campus: _campus ?? 'COBACAM',
        rangeLabel: _getRangeLabelForExport(targetMode, targetDate, targetWeek, targetCycle!),
        cycle: targetCycle,
        isIndividual: isIndividual, 
      );
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error exportando: $e', isError: true);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Map<String, dynamic> _calculateStudentStatsForExport(
    Student student, {
    required String cycle,
    required FilterMode mode,
    required DateTime date,
    required DateTimeRange? week,
  }) {
    DateTime start, end;
    if (mode == FilterMode.day) {
      start = date; end = date;
    } else if (mode == FilterMode.week) {
      start = week!.start; end = week.end;
    } else {
      final cycleObj = _schoolCycles.firstWhere((c) => c.id == cycle);
      start = cycleObj.startDate;
      final now = DateTime.now();
      end = now.isBefore(cycleObj.endDate) ? now : cycleObj.endDate;
    }

    int faults = 0; int presences = 0; int lates = 0;
    final daysTotal = end.difference(start).inDays + 1;
    final records = _attendanceData[student.studentId] ?? [];

    for (var i = 0; i < daysTotal; i++) {
      final d = start.add(Duration(days: i));
      if (d.isAfter(DateTime.now())) break;
      if (d.weekday >= 6) continue;
      if (_nonAttendanceDays.any((nad) => nad.date.year == d.year && nad.date.month == d.month && nad.date.day == d.day)) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final record = records.firstWhere((r) => r.date == dateStr, orElse: () => AttendanceRecord.empty());

      if (record.id.isNotEmpty && record.status != 'null') {
         presences++;
         if (record.status == 'tarde') lates++;
      } else {
         faults++;
      }
    }

    String alertLevel = 'none';
    if (faults == 2) alertLevel = 'warning';
    if (faults >= 3) alertLevel = 'urgent';

    return {'faults': faults, 'presences': presences, 'lates': lates, 'alertLevel': alertLevel};
  }

  String _getRangeLabelForExport(FilterMode mode, DateTime date, DateTimeRange? week, String cycle) {
    if (mode == FilterMode.day) return DateFormat('dd-MM-yyyy').format(date);
    if (mode == FilterMode.week) return 'Semana_${DateFormat('dd-MM').format(week!.start)}_al_${DateFormat('dd-MM').format(week.end)}';
    return 'Ciclo_$cycle';
  }

  Widget _buildLoadingOverlay() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(strokeWidth: 8, color: Colors.blue, strokeCap: StrokeCap.round),
            ),
            const SizedBox(height: 32),
            const Text('Consultando datos...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Espere unos segundos por favor.\nEstamos organizando la información.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              )),
            )
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Student student;
  final Map<String, dynamic> stats;
  final VoidCallback onTap;

  const _StudentAttendanceCard({required this.student, required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final faults = stats['faults'] as int;
    final alert = stats['alertLevel'] as String;
    
    Color color = Colors.green;
    String statusText = 'Regular';
    
    if (alert == 'warning') {
      color = Colors.orange;
      statusText = 'Advertencia (2 Faltas)';
    } else if (alert == 'urgent') {
      color = Colors.red;
      statusText = 'CRÍTICO (3+ Faltas)';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(student.fullName.isNotEmpty ? student.fullName[0] : '?', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Row(
          children: [
            Text('${student.group} • ${student.studentId}', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            )
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$faults Faltas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text('${stats['presences']} Asist.', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
