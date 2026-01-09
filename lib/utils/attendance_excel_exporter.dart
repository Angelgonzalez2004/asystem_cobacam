import 'dart:io';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AttendanceExcelExporter {
  static Future<String?> exportToExcel({
    required List<Student> students,
    required Map<String, List<AttendanceRecord>> attendanceMap,
    required DateTime startDate,
    required DateTime endDate,
    required String cycle,
    String? groupFilter,
    required List<NonAttendanceDay> nonAttendanceDays,
  }) async {
    final excel = Excel.createExcel();
    
    String generalSheetName = 'Reporte General';
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', generalSheetName);
    } else if (excel.sheets.isNotEmpty) {
       generalSheetName = excel.sheets.keys.first;
       excel.rename(generalSheetName, 'Reporte General');
       generalSheetName = 'Reporte General';
    }
    
    final title = "REPORTE DE ASISTENCIA Y RIESGO - DEL ${DateFormat('dd/MM/yyyy').format(startDate)} AL ${DateFormat('dd/MM/yyyy').format(endDate)}";

    final Sheet sheetGeneral = excel[generalSheetName];
    _fillSheet(sheetGeneral, students, attendanceMap, cycle, title, startDate, endDate, nonAttendanceDays);

    final Map<String, List<Student>> studentsByGroup = {};
    for (var s in students) {
      if (!studentsByGroup.containsKey(s.group)) {
        studentsByGroup[s.group] = [];
      }
      studentsByGroup[s.group]!.add(s);
    }

    final sortedGroups = studentsByGroup.keys.toList()..sort();
    
    if (sortedGroups.isNotEmpty) {
       for (var groupName in sortedGroups) {
          // Limpieza de nombre de hoja para evitar errores de Excel
          final safeName = 'Gpo ${groupName.replaceAll(RegExp(r'[\/?:*[\]'), '_')}';
          final finalSheetName = safeName.length > 30 ? safeName.substring(0, 30) : safeName;
          final Sheet sheetGroup = excel[finalSheetName];
          _fillSheet(sheetGroup, studentsByGroup[groupName]!, attendanceMap, cycle, "GRUPO $groupName - $title", startDate, endDate, nonAttendanceDays);
       }
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) return null;

    final dateStr = '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}';
    final groupStr = groupFilter != null ? '_Gpo$groupFilter' : '_Todos';
    final fileName = 'Asistencia_Riesgo_$dateStr$groupStr.xlsx';

    if (kIsWeb) {
      await downloadImageWeb(Uint8List.fromList(fileBytes), fileName);
      return 'Descarga iniciada';
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
         try {
           Directory? dir;
           if (Platform.isAndroid) {
             dir = await getExternalStorageDirectory(); 
           } else {
             dir = await getApplicationDocumentsDirectory();
           }
           
           if (dir != null) {
             final path = '${dir.path}/$fileName';
             final file = File(path);
             await file.writeAsBytes(fileBytes);
             return path;
           }
         } catch (e) {
           debugPrint("Error guardando Excel: $e");
           return null;
         }
      }
      return null;
    }
  }

  static void _fillSheet(Sheet sheet, List<Student> list, Map<String, List<AttendanceRecord>> attendanceMap, String cycle, String title, DateTime start, DateTime end, List<NonAttendanceDay> nonAttendanceDays) {
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
    
    final riskHeaderStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.red,
      fontColorHex: ExcelColor.white,
    );

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );

    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("P1"), customValue: TextCellValue(title));
    final titleCell = sheet.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue(title.toUpperCase());
    titleCell.cellStyle = titleStyle;

    final headers = [
      'Matrícula', 'Nombre Completo', 'Grupo', 'Ciclo Escolar',
      'Días Hábiles', 'Asistencias', 'Faltas', 'ALERTA RIESGO', 'Fechas de Faltas',
      'Nombre Tutor', 'Teléfono Tutor', 'Teléfono Alumno', 
      'Género', 'Salud/Alergias'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(headers[i]); 
      cell.cellStyle = (headers[i] == 'ALERTA RIESGO' || headers[i] == 'Faltas') ? riskHeaderStyle : headerStyle;
      sheet.setColumnWidth(i, 20.0); 
    }
    sheet.setColumnWidth(1, 35.0);
    sheet.setColumnWidth(8, 40.0);
    sheet.setColumnWidth(9, 30.0);

    int currentRow = 2; 

    for (var student in list) {
      final stats = _calculateStats(student, attendanceMap[student.studentId] ?? [], start, end, nonAttendanceDays);
      
      void write(int col, dynamic val, {bool isRiskCell = false}) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        cell.value = val is int ? IntCellValue(val) : TextCellValue(val?.toString() ?? '');
        if (isRiskCell) {
           cell.cellStyle = CellStyle(fontColorHex: ExcelColor.red, bold: true);
        }
      }

      write(0, student.studentId);
      write(1, student.fullName);
      write(2, student.group);
      write(3, cycle);
      write(4, stats['businessDays']);
      write(5, stats['presences']);
      write(6, stats['faults'], isRiskCell: stats['faults'] as int > 0);
      write(7, stats['isRisk'] as bool ? 'SI - RIESGO DE BAJA' : 'NO', isRiskCell: stats['isRisk'] as bool);
      write(8, stats['faultDates']);
      write(9, student.guardianFullName);
      write(10, student.guardianPhone);
      write(11, student.studentPhone ?? '');
      write(12, student.gender);
      
      final salud = '${student.allergies ?? ''} ${student.healthConditions ?? ''}'.trim();
      write(13, salud.isEmpty ? 'Ninguna' : salud);
      
      currentRow++;
    }
  }

  static Map<String, dynamic> _calculateStats(Student student, List<AttendanceRecord> records, DateTime start, DateTime end, List<NonAttendanceDay> nonAttendanceDays) {
    int businessDays = 0;
    int faults = 0;
    int presences = 0;
    List<String> faultDates = [];

    final daysCount = end.difference(start).inDays + 1;
    
    for (var i = 0; i < daysCount; i++) {
      final date = start.add(Duration(days: i));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;
      
      final isNonAttendance = nonAttendanceDays.any((d) => 
          d.date.year == date.year && d.date.month == date.month && d.date.day == date.day);
      if (isNonAttendance) continue;

      businessDays++;

      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final record = records.firstWhere(
          (r) => r.date == dateStr, 
          orElse: () => AttendanceRecord(studentId: '', studentFullName: '', group: '', date: '', campusId: '', schoolCycle: '', status: 'null', entryTime: null, exitTime: null)
      );
      
      if (record.status != 'null') {
         presences++;
      } else {
         faults++;
         faultDates.add(DateFormat('dd/MM').format(date));
      }
    }

    return {
      'businessDays': businessDays,
      'presences': presences,
      'faults': faults,
      'isRisk': faults >= 2,
      'faultDates': faultDates.join(', ')
    };
  }
}