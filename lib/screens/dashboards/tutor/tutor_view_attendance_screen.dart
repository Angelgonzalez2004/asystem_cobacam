import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TutorViewAttendanceScreen extends StatefulWidget {
  final Student student;
  final String? campusId;

  const TutorViewAttendanceScreen({
    super.key,
    required this.student,
    this.campusId,
  });

  @override
  State<TutorViewAttendanceScreen> createState() => _TutorViewAttendanceScreenState();
}

class _TutorViewAttendanceScreenState extends State<TutorViewAttendanceScreen> {
  bool _isLoading = true;
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filteredRecords = [];
  String? _campus;
  
  List<SchoolCycle> _availableCycles = [];
  SchoolCycle? _selectedCycle;
  DateTime _selectedMonth = DateTime.now();
  
  String _rangeMessage = '';
  Color _rangeMessageColor = const Color(0xFF64748B);

  int _asistenciasCount = 0;
  int _retardosCount = 0;
  int _faltasCount = 0;

  @override
  void initState() {
    super.initState();
    _campus = widget.campusId;
    _initData();
  }

  Future<void> _initData() async {
    final hive = Provider.of<HiveService>(context, listen: false);
    final conn = Provider.of<ConnectivityService>(context, listen: false);
    final appSettings = AppSettingsService(hive, conn);

    if (_campus != null) {
      setState(() => _isLoading = true);
      // Corregido: getAllSchoolCycles NO recibe parámetros
      final cycles = await appSettings.getAllSchoolCycles();
      
      if (mounted) {
        setState(() {
          _availableCycles = cycles;
          try {
            _selectedCycle = cycles.firstWhere((c) => c.id == widget.student.schoolCycle);
          } catch (_) {
            if (cycles.isNotEmpty) _selectedCycle = cycles.first;
          }
          
          if (_selectedCycle != null) {
            _selectedMonth = _selectedCycle!.startDate;
          }
        });
        await _loadAttendance();
      }
    }
  }

  Future<void> _loadAttendance() async {
    if (_campus == null || _selectedCycle == null) return;
    setState(() => _isLoading = true);
    
    try {
      final attendanceRef = FirebaseDatabase.instance.ref(
        'planteles/$_campus/attendance/${_selectedCycle!.id}'
      );
      
      final snapshot = await attendanceRef.get();
      List<AttendanceRecord> records = [];
      
      if (snapshot.exists) {
        for (final dateSnapshot in snapshot.children) {
          final dateKey = dateSnapshot.key!;
          if (dateSnapshot.hasChild(widget.student.id)) {
            final studentDataSnapshot = dateSnapshot.child(widget.student.id);
            final data = Map<String, dynamic>.from(studentDataSnapshot.value as Map);
            
            records.add(AttendanceRecord.fromFirebaseMap(
              widget.student.id, dateKey, data,
              campusId: _campus!, schoolCycle: _selectedCycle!.id,
            ));
          }
        }
      }
      
      records.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _allRecords = records;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final filtered = _allRecords.where((record) {
      try {
        DateTime date = DateTime.parse(record.date);
        return date.month == _selectedMonth.month && date.year == _selectedMonth.year;
      } catch (_) {
        return false;
      }
    }).toList();

    _validateRange();

    int asistencias = 0, retardos = 0, faltas = 0;
    for (var r in filtered) {
      String status = (r.status ?? '').toLowerCase();
      if (status.contains('tarde') || status.contains('retardo')) {
        retardos++;
      } else if (status.contains('falta') || status.contains('ausente')) {
        faltas++;
      } else {
        asistencias++;
      }
    }

    setState(() {
      _filteredRecords = filtered;
      _asistenciasCount = asistencias;
      _retardosCount = retardos;
      _faltasCount = faltas;
    });
  }

  void _validateRange() {
    if (_selectedCycle == null) return;

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    if (lastDayOfMonth.isBefore(_selectedCycle!.startDate)) {
      _rangeMessage = '⚠️ ANTERIOR AL INICIO DE ESTE CICLO';
      _rangeMessageColor = Colors.orange.shade700;
    } else if (firstDayOfMonth.isAfter(_selectedCycle!.endDate)) {
      _rangeMessage = '🚫 POSTERIOR AL CIERRE DE ESTE CICLO';
      _rangeMessageColor = Colors.red.shade700;
    } else {
      final now = DateTime.now();
      if (firstDayOfMonth.isAfter(now)) {
        _rangeMessage = '⏳ MES FUTURO (SIN REGISTROS)';
        _rangeMessageColor = const Color(0xFF1E3A8A);
      } else {
        _rangeMessage = '📅 PERIODO ACADÉMICO VÁLIDO';
        _rangeMessageColor = Colors.green.shade700;
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)]))),
          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(theme),
                    _buildCycleSelector(theme),
                    _buildStatsDashboard(),
                    _buildMonthSelector(),
                    _buildRangeBanner(),
                    Expanded(child: _filteredRecords.isEmpty ? _buildEmptyState() : _buildAttendanceList()),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SchoolCycle>(
          value: _selectedCycle,
          isExpanded: true,
          icon: Icon(Icons.history_edu_rounded, color: theme.colorScheme.primary),
          hint: const Text('Seleccionar Ciclo Escolar'),
          items: _availableCycles.map((cycle) {
            return DropdownMenuItem(
              value: cycle,
              child: Text('Ciclo: ${cycle.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            );
          }).toList(),
          onChanged: (cycle) {
            if (cycle != null) {
              setState(() {
                _selectedCycle = cycle;
                _selectedMonth = cycle.startDate;
              });
              _loadAttendance();
            }
          },
        ),
      ),
    );
  }

  Widget _buildRangeBanner() {
    return FadeIn(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(color: _rangeMessageColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Text(_rangeMessage, textAlign: TextAlign.center, style: TextStyle(color: _rangeMessageColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2)),
            child: CircleAvatar(
              radius: 28, backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              backgroundImage: widget.student.profileImageUrl != null ? NetworkImage(widget.student.profileImageUrl!) : null,
              child: widget.student.profileImageUrl == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(widget.student.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (widget.student.medicalAlert)
                      Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 14)),
                  ],
                ),
                Text('Plantel: ${widget.campusId ?? "Cobacam"} • Grupo: ${widget.student.group}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildStatCard('Asistencias', _asistenciasCount.toString(), Colors.green),
          _buildStatCard('Retardos', _retardosCount.toString(), Colors.orange),
          _buildStatCard('Faltas', _faltasCount.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))], border: Border.all(color: color.withOpacity(0.1))),
        child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))]),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthName = DateFormat('MMMM yyyy', 'es_MX').format(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('DETALLE MENSUAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2, color: Color(0xFF64748B))),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => _changeMonth(-1)), Text(monthName[0].toUpperCase() + monthName.substring(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => _changeMonth(1))]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today_rounded, size: 64, color: Color(0xFFE2E8F0)), SizedBox(height: 16), Text('Sin registros en este periodo', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))]));
  }

  Widget _buildAttendanceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) => FadeInUp(delay: Duration(milliseconds: 50 * index), child: _buildAttendanceItem(_filteredRecords[index])),
    );
  }

  Widget _buildAttendanceItem(AttendanceRecord record) {
    DateTime date = DateTime.parse(record.date);
    final dayNum = DateFormat('dd').format(date);
    final dayName = DateFormat('EEE', 'es_MX').format(date).toUpperCase();
    Color statusColor;
    String status = (record.status ?? 'presente').toLowerCase();
    if (status.contains('tarde') || status.contains('retardo')) {
      statusColor = Colors.orange;
    } else if (status.contains('falta') || status.contains('ausente')) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(dayName, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)), Text(dayNum, style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.w900))])),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTimeChip(Icons.login_rounded, record.entryTime ?? '--:--', Colors.green),
                    const SizedBox(width: 8),
                    _buildTimeChip(Icons.logout_rounded, record.exitTime ?? '--:--', Colors.purple)
                  ],
                ),
                if (record.reasonTardy != null || record.reasonEarlyExit != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.info_outline, size: 12, color: Color(0xFF64748B)), const SizedBox(width: 4), Expanded(child: Text(record.reasonTardy ?? record.reasonEarlyExit ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)))]))
              ],
            ),
          ),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))]));
  }
}
