import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  List<AttendanceRecord> _attendanceRecords = [];
  String? _campus;

  @override
  void initState() {
    super.initState();
    _campus = widget.campusId;
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    if (_campus == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Attendance is stored at: planteles/$campus/attendance/$cycleId/$studentId/$date
      final attendanceRef = FirebaseDatabase.instance.ref(
        'planteles/$_campus/attendance/${widget.student.schoolCycle}/${widget.student.id}'
      );
      
      final snapshot = await attendanceRef.get();
      
      List<AttendanceRecord> records = [];
      if (snapshot.exists) {
        for (final dateSnapshot in snapshot.children) {
          final data = Map<String, dynamic>.from(dateSnapshot.value as Map);
          records.add(AttendanceRecord.fromFirebaseMap(
            widget.student.id,
            dateSnapshot.key!,
            data,
            campusId: _campus!,
            schoolCycle: widget.student.schoolCycle,
          ));
        }
      }
      
      // Sort by date descending
      records.sort((a, b) => b.date.compareTo(a.date));
      
      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading attendance for tutor: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? _buildEmptyState()
              : _buildAttendanceList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay registros de asistencia todavía.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando el alumno asista a clases, aparecerán aquí.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        return _buildAttendanceCard(record);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final theme = Theme.of(context);
    
    // Parse the String date 'yyyy-MM-dd' to DateTime
    DateTime attendanceDate;
    try {
      attendanceDate = DateTime.parse(record.date);
    } catch (e) {
      attendanceDate = DateTime.now();
    }

    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es_MX').format(attendanceDate);
    final timeStr = record.entryTime ?? '--:--';
    
    Color statusColor;
    IconData statusIcon;
    String statusText = record.status ?? 'Desconocido';

    switch (statusText.toLowerCase()) {
      case 'asistencia':
      case 'presente':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'retardo':
      case 'tarde':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'falta':
      case 'ausente':
        statusColor = Colors.red;
        statusIcon = Icons.highlight_off;
        break;
      case 'justificado':
        statusColor = Colors.blue;
        statusIcon = Icons.description_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr[0].toUpperCase() + dateStr.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hora de entrada: $timeStr',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (record.reasonTardy != null && record.reasonTardy!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Motivo: ${record.reasonTardy}',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
