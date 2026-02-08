import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:asystem_cobacam/utils/web_downloader.dart';

class DetailedAttendanceExcelExporter {
  static Future<void> exportDetailedAttendanceReport({
    required BuildContext context,
    required List<AttendanceRecord> attendanceRecords,
    required Map<String, GroupSchedule> groupSchedules,
    required String campus,
    required String cycle,
    required String exportType, // New parameter: 'entry' or 'exit'
    String? customFileName,
  }) async {
    final excel = Excel.createExcel();
    final String sheetName = 'Reporte Detallado (${exportType == 'entry' ? 'Entradas' : 'Salidas'})';

    // Rename default sheet if it exists
    if (excel.sheets.keys.isNotEmpty) {
      final defaultSheet = excel.sheets.keys.first;
      excel.rename(defaultSheet, sheetName);
    }

    final Sheet sheet = excel[sheetName];

    // --- STYLES ---
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final centerStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

    // --- REPORT HEADER ---
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("I1"));
    var cellTitle = sheet.cell(CellIndex.indexByString("A1"));
    cellTitle.value = TextCellValue("REPORTE DETALLADO DE ${exportType == 'entry' ? 'ENTRADAS' : 'SALIDAS'} - $campus");
    cellTitle.cellStyle = CellStyle(
        bold: true, fontSize: 14, horizontalAlign: HorizontalAlign.Center);

    sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("I2"));
    var cellSub = sheet.cell(CellIndex.indexByString("A2"));
    cellSub.value = TextCellValue("Ciclo Escolar: $cycle");
    cellSub.cellStyle =
        CellStyle(italic: true, horizontalAlign: HorizontalAlign.Center);

    // --- COLUMN HEADERS ---
    final headers = [
      'Matrícula',
      'Nombre',
      'Grupo',
      'Fecha',
      'Hora Actual',
      'Hora Programada',
      'Motivo de Incidencia', // New column
      'Asistencia',
      'Observaciones',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    int rowIndex = 4; // Excel rows are 1-indexed, starting data from row 4

    // Sort records by group, then student name, then date
    attendanceRecords.sort((a, b) {
      int cmp = a.group.compareTo(b.group);
      if (cmp != 0) return cmp;
      cmp = a.studentFullName.compareTo(b.studentFullName);
      if (cmp != 0) return cmp;
      return a.date.compareTo(b.date);
    });

    for (var record in attendanceRecords) {
      String? actualTime;
      String? scheduledTime; // This will be either entry or exit scheduled time

      // The calling screen already filters for actualTime != null, so actualTime is guaranteed not null here.
      if (exportType == 'entry') {
        actualTime = record.entryTime;
      } else { // exportType == 'exit'
        actualTime = record.exitTime;
      }

      final GroupSchedule? groupSchedule = groupSchedules[record.group];

      if (groupSchedule != null) {
        final DateTime recordDate = DateTime.parse(record.date);
        final String dayOfWeek = DateFormat('EEEE', 'es').format(recordDate); // e.g., 'lunes', 'martes'

        final List<ClassSession>? sessions = groupSchedule.dailySchedules[dayOfWeek.toLowerCase()];

        if (sessions != null && sessions.isNotEmpty) {
          if (exportType == 'entry') {
            scheduledTime = sessions.map((s) => s.startTime).reduce((a, b) => a.compareTo(b) < 0 ? a : b);
          } else { // exportType == 'exit'
            scheduledTime = sessions.map((s) => s.endTime).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          }
        }
      }

      // If scheduled time couldn't be determined, use a default '00:00' for formula comparison
      scheduledTime ??= '00:00';

      // --- Populate Fixed Data ---
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(record.studentId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(record.studentFullName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(record.group);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(record.date);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(actualTime!); // Actual time, guaranteed not null
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(scheduledTime); // Scheduled time

      // --- Add Excel Formulas ---
      final excelRow = rowIndex + 1; // Excel row numbers are 1-indexed for formulas
      final actualTimeCellRef = 'E$excelRow'; // E column for Hora Actual
      final scheduledTimeCellRef = 'F$excelRow'; // F column for Hora Programada
      final asistenciaCellRef = 'H$excelRow'; // H column for Asistencia

      String asistenciaFormula;
      String motivoIncidenciaFormula;
      String observacionesFormula; // For the optional column I

      if (exportType == 'entry') {
        // Asistencia formula (new column H): Check for tardy (actualTime > scheduledTime)
        asistenciaFormula = '=IF(TIMEVALUE($scheduledTimeCellRef)=0,"PRESENTE",' 'IF(TIMEVALUE($actualTimeCellRef)>TIMEVALUE($scheduledTimeCellRef),"RETARDO","PRESENTE"))';

        // Motivo de Incidencia formula (new column G): Mandatory reason for late
        motivoIncidenciaFormula = '=IF($asistenciaCellRef="RETARDO",' 'IF(TRIM("""${record.reasonTardy ?? ""}""")<>"","""${record.reasonTardy ?? ""}""",""Llegó tarde.""),' '"" )'; // Blank if not RETARDO

        // Observaciones formula (new column I): Optional, defaults to blank
        observacionesFormula = '""'; // Truly optional, so default to blank
      } else { // exportType == 'exit'
        // Asistencia formula (new column H): Check for early exit (actualTime < scheduledTime)
        asistenciaFormula = '=IF(TIMEVALUE($scheduledTimeCellRef)=0,"PRESENTE",' 'IF(TIMEVALUE($actualTimeCellRef)<TIMEVALUE($scheduledTimeCellRef),"SALIDA ANTICIPADA","PRESENTE"))';
        
        // Motivo de Incidencia formula (new column G): Mandatory reason for early exit
        motivoIncidenciaFormula = '=IF($asistenciaCellRef="SALIDA ANTICIPADA",' 'IF(TRIM("""${record.reasonEarlyExit ?? ""}""")<>"","""${record.reasonEarlyExit ?? ""}""",""Salió temprano.""),' '"" )'; // Blank if not SALIDA ANTICIPADA

        // Observaciones formula (new column I): Optional, defaults to blank
        observacionesFormula = '""'; // Truly optional, so default to blank
      }
      
      // Assigning the formulas
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = FormulaCellValue(motivoIncidenciaFormula);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = FormulaCellValue(asistenciaFormula);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = FormulaCellValue(observacionesFormula);

      // Apply center style to formula cells too
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = centerStyle;

      rowIndex++;
    }

    // AUTO-ANCHO PROFESIONAL
    sheet.setColumnWidth(0, 15.0); // Matrícula
    sheet.setColumnWidth(1, 40.0); // Nombre
    sheet.setColumnWidth(2, 12.0); // Grupo
    sheet.setColumnWidth(3, 15.0); // Fecha
    sheet.setColumnWidth(4, 20.0); // Hora Actual
    sheet.setColumnWidth(5, 20.0); // Hora Programada
    sheet.setColumnWidth(6, 40.0); // Motivo de Incidencia (NEW)
    sheet.setColumnWidth(7, 15.0); // Asistencia (SHIFTED)
    sheet.setColumnWidth(8, 40.0); // Observaciones (SHIFTED)

    final List<int>? fileBytes = excel.encode();
    if (fileBytes == null) return;

    // Intelligent File Naming
    final String fileName = customFileName ?? 'FORMATOASISTENCIAS_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.xlsx';

    // --- Add a new sheet for Incidence Types as a reference ---
    final Sheet incidenceTypesSheet = excel['Tipos de Incidencia'];
    incidenceTypesSheet.cell(CellIndex.indexByString("A1")).value = TextCellValue("LISTA DE TIPOS DE INCIDENCIA");
    incidenceTypesSheet.cell(CellIndex.indexByString("A1")).cellStyle = headerStyle; // Reuse header style
    incidenceTypesSheet.setColumnWidth(0, 50.0); // Adjust width for the list

    final List<String> incidenceTypes = [
      'Uniforme Incompleto',
      'Cabello/Corte no permitido',
      'Uso de Celular sin autorización',
      'Falta de Respeto a Autoridad',
      'Daño a Mobiliario o Instalaciones',
      'Salida del Plantel sin Pase',
      'Retardo injustificado',
      'Incumplimiento de Tareas/Material',
      'Agresión Física o Verbal',
      'Robo o Extorsión',
      'Vandalismo o Grafiti',
      'Consumo de Sustancias Prohibidas',
      'Acoso Escolar (Bullying)',
      'Falsificación de Firmas/Documentos',
      'Interrupción de la Labor Docente',
      'Lenguaje Obsceno o Inapropiado',
      'Consumo de Alimentos en Aula',
      'Desobediencia a Instrucciones',
      'Copia en Examen o Plagio',
      'Riña o Connatos de Violencia',
      'Portación de Objetos Peligrosos',
      'Inasistencia Injustificada (Saltarse clases)',
      'Uso de Gorras o Lentes de Sol en Aula',
      'Otro'
    ];

    for (int i = 0; i < incidenceTypes.length; i++) {
      incidenceTypesSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(incidenceTypes[i]);
    }
    // End of new sheet addition

    if (kIsWeb) {
      await WebDownloader.downloadFile(Uint8List.fromList(fileBytes), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo guardado: $fileName')));
      }
    }
  }
}
