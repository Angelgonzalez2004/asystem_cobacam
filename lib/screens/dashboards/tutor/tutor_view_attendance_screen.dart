import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/group_schedule_service.dart';
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
  bool _showFullCycle = false;
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filteredRecords = [];
  String? _campus;
  
  List<SchoolCycle> _availableCycles = [];
  SchoolCycle? _selectedCycle;
  DateTime _selectedMonth = DateTime.now();
  
  GroupSchedule? _groupSchedule;
  String _securityStatus = 'Analizando seguridad...';
  Color _securityColor = Colors.blue;
  IconData _securityIcon = Icons.security_outlined;

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
    final scheduleService = GroupScheduleService(hive, conn);

    if (_campus != null) {
      setState(() => _isLoading = true);
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

        // Cargar horario de grupo (Búsqueda por nombre de grupo para obtener ID real)
        if (_selectedCycle != null) {
          try {
            final groupsRef = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
            final groupsSnapshot = await groupsRef.get();
            String? realGroupId;
            
            if (groupsSnapshot.exists) {
              for (final groupChild in groupsSnapshot.children) {
                final groupData = Map<String, dynamic>.from(groupChild.value as Map);
                if (groupData['name'] == widget.student.group && 
                    groupData['schoolCycleId'] == _selectedCycle!.id) {
                  realGroupId = groupChild.key;
                  break;
                }
              }
            }

            if (realGroupId != null) {
              final schedule = await scheduleService.getGroupSchedule(
                realGroupId, _campus!, _selectedCycle!.id
              );
              if (mounted) setState(() => _groupSchedule = schedule);
            }
          } catch (e) {
            debugPrint('Error vinculando horario: $e');
          }
        }

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
          _updateSecurityStatus();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSecurityStatus() {
    if (_groupSchedule == null) {
      _securityStatus = 'SIN HORARIO ASIGNADO';
      _securityColor = Colors.grey;
      _securityIcon = Icons.help_outline;
      return;
    }

    final now = DateTime.now();
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final todayName = dayNames[now.weekday - 1];
    
    final todaySchedule = _groupSchedule!.dailySchedules[todayName];
    if (todaySchedule == null || todaySchedule.isEmpty) {
      _securityStatus = 'SIN CLASES PROGRAMADAS HOY';
      _securityColor = Colors.green;
      _securityIcon = Icons.event_available;
      return;
    }

    todaySchedule.sort((a, b) => a.startTime.compareTo(b.startTime));
    final firstSession = todaySchedule.first;
    final lastSession = todaySchedule.last;

    final format = DateFormat('HH:mm');
    final startOfClasses = format.parse(firstSession.startTime);
    final endOfClasses = format.parse(lastSession.endTime);
    final currentTime = format.parse(DateFormat('HH:mm').format(now));

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayRecord = _allRecords.firstWhereOrNull((r) => r.date == todayStr);

    if (currentTime.isBefore(startOfClasses)) {
      _securityStatus = 'ANTES DE HORA DE ENTRADA';
      _securityColor = Colors.blue;
      _securityIcon = Icons.watch_later_outlined;
    } else if (todayRecord == null) {
      if (currentTime.isAfter(startOfClasses.add(const Duration(minutes: 30)))) {
        _securityStatus = '⚠️ EL ALUMNO NO HA INGRESADO AL PLANTEL';
        _securityColor = Colors.red;
        _securityIcon = Icons.report_problem_rounded;
      } else {
        _securityStatus = 'PENDIENTE DE REGISTRO DE ENTRADA';
        _securityColor = Colors.orange;
        _securityIcon = Icons.timer_outlined;
      }
    } else if (todayRecord.exitTime == null || todayRecord.exitTime == '--:--') {
      if (currentTime.isAfter(endOfClasses.add(const Duration(hours: 1)))) {
        _securityStatus = '🚨 SALIDA PENDIENTE: EL HORARIO YA TERMINÓ';
        _securityColor = Colors.deepOrange;
        _securityIcon = Icons.warning_amber_rounded;
      } else {
        _securityStatus = 'ALUMNO DENTRO DEL PLANTEL (EN CLASES)';
        _securityColor = Colors.green;
        _securityIcon = Icons.school;
      }
    } else {
      _securityStatus = 'CICLO DE ASISTENCIA COMPLETADO';
      _securityColor = Colors.green;
      _securityIcon = Icons.check_circle_outline;
    }
  }

  void _applyFilters() {
    List<AttendanceRecord> filtered;
    
    if (_showFullCycle) {
      filtered = List.from(_allRecords);
      _rangeMessage = '📅 MOSTRANDO TODO EL CICLO ${_selectedCycle?.id ?? ""}';
      _rangeMessageColor = const Color(0xFF1E3A8A);
    } else {
      filtered = _allRecords.where((record) {
        try {
          DateTime date = DateTime.parse(record.date);
          return date.month == _selectedMonth.month && date.year == _selectedMonth.year;
        } catch (_) {
          return false;
        }
      }).toList();
      _validateRange();
    }

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
      _showFullCycle = false;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)]))),
          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
                    child: Column(
                      children: [
                        _buildHeader(theme),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                _buildSecurityCard(),
                                _buildCycleSelector(theme),
                                _buildViewTypeSelector(),
                                _buildStatsDashboard(isDesktop),
                                if (!_showFullCycle) _buildMonthSelector(),
                                _buildRangeBanner(),
                                _filteredRecords.isEmpty ? _buildEmptyState() : _buildAttendanceList(),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _securityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _securityColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _securityColor, shape: BoxShape.circle),
            child: Icon(_securityIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESTADO DE SEGURIDAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                Text(_securityStatus, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _securityColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            _buildViewButton('MES ACTUAL', !_showFullCycle, () => setState(() { _showFullCycle = false; _applyFilters(); })),
            _buildViewButton('CICLO COMPLETO', _showFullCycle, () => setState(() { _showFullCycle = true; _applyFilters(); })),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E3A8A) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildCycleSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SchoolCycle>(
          value: _selectedCycle,
          isExpanded: true,
          icon: Icon(Icons.history_edu_rounded, color: theme.colorScheme.primary),
          items: _availableCycles.map((cycle) => DropdownMenuItem(value: cycle, child: Text('Ciclo Escolar: ${cycle.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
          onChanged: (cycle) {
            if (cycle != null) {
              setState(() { _selectedCycle = cycle; _selectedMonth = cycle.startDate; });
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28, backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: widget.student.profileImageUrl != null ? NetworkImage(widget.student.profileImageUrl!) : null,
            child: widget.student.profileImageUrl == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.student.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B), height: 1.2)),
                const SizedBox(height: 4),
                Text('Plantel: ${widget.campusId ?? "Cobacam"} • Grupo: ${widget.student.group}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1)), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold))]),
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
          Row(
            children: [
              IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3A8A)), onPressed: () => _selectDate(context)),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(children: [IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => _changeMonth(-1)), Text(monthName[0].toUpperCase() + monthName.substring(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => _changeMonth(1))]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_selectedCycle == null) return;
    
    // Calcular fecha inicial válida
    DateTime initialDate = _selectedMonth;
    if (initialDate.isBefore(_selectedCycle!.startDate)) {
      initialDate = _selectedCycle!.startDate;
    } else if (initialDate.isAfter(_selectedCycle!.endDate)) {
      initialDate = _selectedCycle!.endDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _selectedCycle!.startDate,
      lastDate: _selectedCycle!.endDate,
      locale: const Locale('es', 'MX'),
    );

    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      setState(() { 
        _showFullCycle = false; 
        _selectedMonth = DateTime(picked.year, picked.month); 
        _applyFilters(); 
      });
      
      bool hasRecord = _allRecords.any((r) => r.date == dateStr);
      if (!hasRecord && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sin registros para el ${DateFormat('dd/MM/yyyy').format(picked)}'), 
            backgroundColor: Colors.orange.shade700
          )
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Column(children: [Icon(Icons.calendar_today_rounded, size: 64, color: Color(0xFFE2E8F0)), SizedBox(height: 16), Text('Sin registros en este periodo', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))])));
  }

  Widget _buildAttendanceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) => _buildAttendanceItem(_filteredRecords[index]),
    );
  }

  Widget _buildAttendanceItem(AttendanceRecord record) {
    DateTime date = DateTime.parse(record.date);
    final dayNum = DateFormat('dd').format(date);
    final dayName = DateFormat('EEE', 'es_MX').format(date).toUpperCase();
    final bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == record.date;
    Color statusColor = (record.status ?? '').toLowerCase().contains('tarde') ? Colors.orange : (record.status ?? '').toLowerCase().contains('falta') ? Colors.red : Colors.green;
    bool missingExit = (record.exitTime == null || record.exitTime == '--:--' || record.exitTime!.isEmpty);

    String recordStatus = (record.status ?? 'presente').toUpperCase();
    bool isMissingExitAlert = (missingExit && !isToday);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isMissingExitAlert ? Colors.red.withOpacity(0.3) : const Color(0xFFF1F5F9), width: isMissingExitAlert ? 2 : 1)),
      child: Row(
        children: [
          Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(dayName, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)), Text(dayNum, style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.w900))])),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [_buildTimeChip(Icons.login_rounded, record.entryTime ?? '--:--', Colors.green), const SizedBox(width: 8), _buildTimeChip(Icons.logout_rounded, record.exitTime ?? '--:--', missingExit ? Colors.grey : Colors.purple)]),
                if (missingExit) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(isToday ? Icons.info_outline : Icons.report_problem_rounded, size: 14, color: isToday ? const Color(0xFF1E3A8A) : Colors.red), const SizedBox(width: 4), Text(isToday ? 'DENTRO DEL PLANTEL' : 'SIN REGISTRO DE SALIDA', style: TextStyle(fontSize: 10, color: isToday ? const Color(0xFF1E3A8A) : Colors.red, fontWeight: FontWeight.bold))])),
              ],
            ),
          ),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isMissingExitAlert ? Colors.red : statusColor, borderRadius: BorderRadius.circular(10)), child: Text(isMissingExitAlert ? 'INCOMPLETO' : recordStatus, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]));
  }
}
