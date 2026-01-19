import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:flutter/material.dart';

class ScheduleDisplayWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, List<ClassSession>> scheduleData;
  final String viewType; // 'group' or 'teacher'
  final String mainTitle; // Added
  final String campusName; // Added
  final String logoPath; // Added

  const ScheduleDisplayWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scheduleData,
    this.viewType = 'group',
    required this.mainTitle, // Added
    required this.campusName, // Added
    required this.logoPath, // Added
  });

  final List<String> _weekdays = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes'
  ];
  
  final List<Map<String, String>> _timeSlots = const [
    {'start': '07:00', 'end': '07:50'},
    {'start': '07:50', 'end': '08:40'},
    {'start': '08:40', 'end': '09:30'},
    {'start': '09:30', 'end': '09:50'}, // Receso
    {'start': '09:50', 'end': '10:40'},
    {'start': '10:40', 'end': '11:30'},
    {'start': '11:30', 'end': '12:20'},
    {'start': '12:20', 'end': '13:10'},
    {'start': '13:10', 'end': '14:00'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final cellStyle = theme.textTheme.bodySmall;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // New Header for institutional branding
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  logoPath,
                  height: 60,
                  fit: BoxFit.contain,
                  colorBlendMode: BlendMode.srcIn, // Ensures logo respects theme color if needed
                ),
                const SizedBox(height: 8),
                Text(
                  mainTitle,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Horario del Plantel: $campusName',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16), // Separator before specific schedule title
                // Existing specific schedule title and subtitle
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          // Existing Table
          Table(
            border: TableBorder.all(color: theme.dividerColor, width: 1),
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              ...{1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth(), 4: FlexColumnWidth(), 5: FlexColumnWidth()}
            },
            children: [
              _buildHeaderRow(headerStyle),
              ..._buildScheduleRows(cellStyle),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow(TextStyle? style) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        _buildHeaderCell('Hora'),
        ..._weekdays.map((day) => _buildHeaderCell(day)),
      ],
    );
  }

  List<TableRow> _buildScheduleRows(TextStyle? style) {
    return _timeSlots.map((slot) {
      final startTime = slot['start']!;
      final isBreak = startTime == '09:30';

      return TableRow(
        children: [
          _buildTimeCell(slot),
          ..._weekdays.map((day) {
            final sessions = scheduleData[day] ?? [];
            ClassSession? session;
            try {
              session = sessions.firstWhere((s) => s.startTime == startTime);
            } catch (e) {
              session = null;
            }
            return _buildSessionCell(session, isBreak, style);
          }),
        ],
      );
    }).toList();
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTimeCell(Map<String, String> slot) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          "${slot['start']!}\n-\n${slot['end']!}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSessionCell(ClassSession? session, bool isBreak, TextStyle? style) {
    if (isBreak) {
      return Container(
        color: Colors.cyan.shade50,
        padding: const EdgeInsets.all(4.0),
        child: const Center(
          child: Text('Receso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
        ),
      );
    }
    if (session == null) { // If no session exists for this slot, it's free
      return Container(
        padding: const EdgeInsets.all(4.0),
        child: Center(
          child: Text(
            'Libre',
            style: TextStyle(
              fontSize: 10,
              color: style?.color?.withOpacity(0.6) ?? Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    String topText = session.subjectName;
    String bottomText = '';

    if (viewType == 'group') {
      bottomText = session.teacherName ?? '';
    } else { // teacher view
      bottomText = session.groupName ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: style,
            children: [
              TextSpan(
                text: topText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              if (bottomText.isNotEmpty)
                TextSpan(
                  text: "\n$bottomText",
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
