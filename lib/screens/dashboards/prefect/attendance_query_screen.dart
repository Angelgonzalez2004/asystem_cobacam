import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
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
  List<NonAttendanceDay> _nonAttendanceDays = [];
  String? _selectedCycle;
  String? _selectedGroup;
  
  DateTimeRange _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  String _searchQuery = '';

  bool _isLoadingInitial = true;
  bool _isLoadingAttendance = false;
  
  Map<String, Student> _allStudentsMap = {};
  Map<String, List<AttendanceRecord>> _periodAttendanceMap = {};
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
      
      if (_campus != null) {
         _nonAttendanceDays = await _appSettingsService.getAllNonAttendanceDays(_campus!);
      }

      if (_campus != null && _selectedCycle != null) {
        await _loadAllStudents();
        _extractGroupsFromStudents();
        await _fetchAttendanceRange();
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
      final snap = await ref.get();
      
      final Map<String, Student> tempMap = {};
      if (snap.exists) {
        for (var child in snap.children) {
          final student = Student.fromSnapshot(child);
          if (student.isActive) {
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

  Future<void> _fetchAttendanceRange() async {
    if (_campus == null || _selectedCycle == null) return;
    if (mounted) setState(() => _isLoadingAttendance = true);

    try {
      final Map<String, List<AttendanceRecord>> tempMap = {};
      final days = _selectedDateRange.end.difference(_selectedDateRange.start).inDays + 1;
      
      if (days > 31) {
         if (mounted) UiHelpers.showSnackBar(context, 'El rango máximo es de 31 días.', isError: true);
         setState(() => _isLoadingAttendance = false);
         return;
      }

      for (var i = 0; i < days; i++) {
        final date = _selectedDateRange.start.add(Duration(days: i));
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
      
      if (mounted) setState(() => _periodAttendanceMap = tempMap);
    } catch (e) {
      debugPrint('Error cargando rango: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  List<Student> _getFilteredStudents() {
    final query = _searchQuery.toLowerCase().trim();
    
    return _allStudentsMap.values.where((s) {
      if (_selectedGroup != null && s.group != _selectedGroup) return false;
      if (query.isNotEmpty) {
        final matchesName = s.fullName.toLowerCase().contains(query);
        final matchesId = s.studentId.contains(query);
        if (!matchesName && !matchesId) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  }

  Map<String, dynamic> _calculateRisk(Student student) {
    int faults = 0;
    int presences = 0;
    List<Map<String, dynamic>> dailyStatus = [];

    final daysCount = _selectedDateRange.end.difference(_selectedDateRange.start).inDays + 1;
    
    for (var i = 0; i < daysCount; i++) {
      final date = _selectedDateRange.start.add(Duration(days: i));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
      
      final isNonAttendance = _nonAttendanceDays.any((d) => 
          d.date.year == date.year && d.date.month == date.month && d.date.day == date.day);
      if (isNonAttendance) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final records = _periodAttendanceMap[student.studentId];
      final record = records?.firstWhere((r) => r.date == dateStr, orElse: () => AttendanceRecord(studentId: '', studentFullName: '', group: '', date: '', campusId: '', schoolCycle: '', status: 'null'));
      
      if (record != null && record.status != 'null') {
         presences++;
         dailyStatus.add({'date': date, 'status': 'presente', 'record': record});
      } else {
         faults++;
         dailyStatus.add({'date': date, 'status': 'falta', 'record': null});
      }
    }

    return {
      'faults': faults,
      'presences': presences,
      'isRisk': faults >= 2,
      'details': dailyStatus
    };
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardColor : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
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
                                  await _fetchAttendanceRange();
                                  setState(() => _isLoadingInitial = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                  initialDateRange: _selectedDateRange,
                                );
                                if (picked != null) {
                                  setState(() => _selectedDateRange = picked);
                                  _fetchAttendanceRange();
                                }
                              },
                              child: Container(
                                height: 56, 
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Periodo', style: TextStyle(fontSize: 10, color: theme.hintColor)),
                                          Text(
                                            '${DateFormat('dd/MM').format(_selectedDateRange.start)} - ${DateFormat('dd/MM').format(_selectedDateRange.end)}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.date_range, color: theme.colorScheme.primary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: filteredList.isEmpty ? null : _exportData,
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Exportar Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                                final records = _periodAttendanceMap[student.studentId];
                                return _buildStudentCard(student, records, theme);
                              },
                            ),
                ),
              ],
            );
  }

  Widget _buildStudentCard(Student student, List<AttendanceRecord>? records, ThemeData theme) {
    final stats = _calculateRisk(student);
    final int faults = stats['faults'];
    final bool isRisk = stats['isRisk'];
    final List<Map<String, dynamic>> details = stats['details'];

    Color statusColor = isRisk ? Colors.red : Colors.green;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: statusColor.withOpacity(0.3), width: isRisk ? 2 : 1)
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        childrenPadding: EdgeInsets.zero,
        title: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(student.fullName[0], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${student.studentId} • ${student.group} • $faults Faltas', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (isRisk) const Icon(Icons.warning_rounded, color: Colors.red)
                else const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
        ),
        children: [
          if (isRisk)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.red,
              child: const Text('⚠️ RIESGO DE BAJA (2+ Faltas)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            itemBuilder: (context, i) {
              final d = details[i];
              final bool isFalta = d['status'] == 'falta';
              return ListTile(
                dense: true,
                title: Text(DateFormat('EEEE dd/MM', 'es_MX').format(d['date']).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                trailing: Text(isFalta ? 'FALTA' : 'PRESENTE', style: TextStyle(color: isFalta ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'Tutor', student.guardianFullName),
                _buildInfoRow(Icons.phone, 'Tel', student.guardianPhone),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return const Center(child: Text('Sin resultados.'));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _exportData() async {
    final list = _getFilteredStudents();
    try {
      await AttendanceExcelExporter.exportToExcel(
        students: list,
        attendanceMap: _periodAttendanceMap,
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
        cycle: _selectedCycle ?? 'S/C',
        groupFilter: _selectedGroup,
        nonAttendanceDays: _nonAttendanceDays,
      );
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error exportando: $e', isError: true);
    }
  }
}
