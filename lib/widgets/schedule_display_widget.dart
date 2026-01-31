import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:flutter/material.dart';

class ScheduleDisplayWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, List<ClassSession>> scheduleData;
  final String viewType; // 'group' or 'teacher'
  final String mainTitle;
  final String campusName;
  final String logoPath;
  final Function(ClassSession? session, String day, String startTime, String endTime)? onSessionTap;

  const ScheduleDisplayWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scheduleData,
    this.viewType = 'group',
    required this.mainTitle,
    required this.campusName,
    required this.logoPath,
    this.onSessionTap,
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

    return Card(
      elevation: 6, // Slightly more elevation
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // New Header for institutional branding
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: theme.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Ensure overall column is centered
              children: [
                Image.asset(
                  logoPath,
                  height: 60,
                  fit: BoxFit.contain,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 8),
                Text(
                  mainTitle,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center, // Center text within its own space
                ),
                const SizedBox(height: 4),
                Text(
                  'Horario del Plantel: $campusName',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center, // Center text within its own space
                ),
                const SizedBox(height: 16),
                const Icon(Icons.calendar_month, color: Colors.white, size: 30),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  textAlign: TextAlign.center, // Center text within its own space
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center, // Center text within its own space
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: theme.dividerColor.withOpacity(0.5), width: 1), // Softer borders
              columnWidths: const {
                0: IntrinsicColumnWidth(), // Time column
                1: FixedColumnWidth(160), // Lunes
                2: FixedColumnWidth(160), // Martes
                3: FixedColumnWidth(160), // Miércoles
                4: FixedColumnWidth(160), // Jueves
                5: FixedColumnWidth(160), // Viernes
              },
              children: [
                _buildHeaderRow(theme),
                ..._buildScheduleRows(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow(ThemeData theme) {
    return TableRow(
      decoration: BoxDecoration(color: theme.primaryColorLight.withOpacity(0.2)), // Lighter primary color
      children: [
        _buildHeaderCell('Hora', theme),
        ..._weekdays.map((day) => _buildHeaderCell(day, theme)),
      ],
    );
  }

  List<TableRow> _buildScheduleRows(ThemeData theme) {
    return _timeSlots.map((slot) {
      final startTime = slot['start']!;
      final endTime = slot['end']!;
      final isBreak = startTime == '09:30';
      final isEvenRow = _timeSlots.indexOf(slot) % 2 == 0;

      return TableRow(
        decoration: BoxDecoration(
          color: isEvenRow ? theme.colorScheme.surface : theme.colorScheme.surface.withOpacity(0.8), // Alternate row colors
        ),
        children: [
          _buildTimeCell(slot, theme),
          ..._weekdays.map((day) {
            final sessions = scheduleData[day] ?? [];
            ClassSession? session;
            try {
              session = sessions.firstWhere((s) => s.startTime == startTime);
            } catch (e) {
              session = null;
            }
            return _buildSessionCell(session, day, startTime, endTime, isBreak, theme);
          }),
        ],
      );
    }).toList();
  }

  Widget _buildHeaderCell(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTimeCell(Map<String, String> slot, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      color: theme.primaryColor.withOpacity(0.1), // Distinct background for time cells
      child: Center(
        child: Text(
          "${slot['start']!}\n-\n${slot['end']!}",
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSessionCell(ClassSession? session, String day, String startTime, String endTime, bool isBreak, ThemeData theme) {
    final cellContent = _buildCellContent(session, isBreak, theme);

    if (onSessionTap != null) {
      return InkWell(
        onTap: () {
          final sessionToEdit = session ?? ClassSession(startTime: startTime, endTime: endTime);
          onSessionTap!(sessionToEdit, day, startTime, endTime);
        },
        child: cellContent,
      );
    }
    return cellContent;
  }
  
  Widget _buildCellContent(ClassSession? session, bool isBreak, ThemeData theme) {
    if (isBreak) {
      return Container(
        color: theme.colorScheme.secondary.withOpacity(0.1), // Different color for break
        padding: const EdgeInsets.all(4.0),
        child: Center(
          child: Text(
            'Receso',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.secondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget content;
    if (session == null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Libre',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            if (onSessionTap != null) // If editable, show add icon
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Icon(Icons.add_circle_outline, color: Colors.grey.shade400, size: 20),
              ),
          ],
        ),
      );
    } else {
      String topText = session.subjectName;
      String bottomText =
          viewType == 'group' ? session.teacherName ?? '' : session.groupName ?? '';
      
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
              children: [
                TextSpan(
                  text: topText,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                if (bottomText.isNotEmpty)
                  TextSpan(
                    text: "\n$bottomText",
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary), // Use primary color for group/teacher name
                  ),
                if (onSessionTap != null && !isBreak)
                  WidgetSpan(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Icon(
                        session.subjectId == null ? Icons.add_circle : Icons.edit,
                        size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4.0),
      child: content,
    );
  }
}
