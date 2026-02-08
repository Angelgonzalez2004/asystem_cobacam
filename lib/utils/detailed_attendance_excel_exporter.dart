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
    required String exportType, // 'entry' or 'exit'
    String? customFileName,
  }) async {
    final excel = Excel.createExcel();
    final String sheetName =
        'Reporte Detallado (${exportType == 'entry' ? 'Entradas' : 'Salidas'})';

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

    final centerStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // --- REPORT HEADER ---
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("I1"));
    var cellTitle = sheet.cell(CellIndex.indexByString("A1"));
    cellTitle.value = TextCellValue(
        "REPORTE DETALLADO DE ${exportType == 'entry' ? 'ENTRADAS' : 'SALIDAS'} - $campus");
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
      'Motivo de Incidencia',
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
      String? scheduledTime;

      // The calling screen already filters for actualTime != null
      if (exportType == 'entry') {
        actualTime = record.entryTime;
      } else {
        // exportType == 'exit'
        actualTime = record.exitTime;
      }

      final GroupSchedule? groupSchedule = groupSchedules[record.group];

      if (groupSchedule != null) {
        final DateTime recordDate = DateTime.parse(record.date);
        final String dayOfWeek = DateFormat('EEEE', 'es')
            .format(recordDate); // e.g., 'lunes', 'martes'

        final List<ClassSession>? sessions =
            groupSchedule.dailySchedules[dayOfWeek.toLowerCase()];

        if (sessions != null && sessions.isNotEmpty) {
          if (exportType == 'entry') {
            scheduledTime = sessions
                .map((s) => s.startTime)
                .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
          } else {
            // exportType == 'exit'
            scheduledTime = sessions
                .map((s) => s.endTime)
                .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          }
        }
      }

      // If scheduled time couldn't be determined, use a default '00:00'
      scheduledTime ??= '00:00';
      actualTime ??= '00:00';

      // --- Populate Fixed Data ---
      var cellCol0 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      cellCol0.value = TextCellValue(record.studentId);
      cellCol0.cellStyle = centerStyle;

      var cellCol1 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      cellCol1.value = TextCellValue(record.studentFullName);
      cellCol1.cellStyle = centerStyle;

      var cellCol2 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      cellCol2.value = TextCellValue(record.group);
      cellCol2.cellStyle = centerStyle;

      var cellCol3 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      cellCol3.value = TextCellValue(
          DateFormat('dd/MM/yyyy').format(DateTime.parse(record.date)));
      cellCol3.cellStyle = centerStyle;

      // Formatting times as HH:mm strings for Excel TIMEVALUE compatibility
      var cellCol4 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      // Using arbitrary date to parse time safely
      try {
        cellCol4.value = TextCellValue(DateFormat('HH:mm')
            .format(DateTime.parse('2000-01-01 $actualTime')));
      } catch (e) {
        cellCol4.value = TextCellValue(actualTime);
      }
      cellCol4.cellStyle = centerStyle;

      var cellCol5 = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      try {
        cellCol5.value = TextCellValue(DateFormat('HH:mm')
            .format(DateTime.parse('2000-01-01 $scheduledTime')));
      } catch (e) {
        cellCol5.value = TextCellValue(scheduledTime);
      }
      cellCol5.cellStyle = centerStyle;

      // --- Add Excel Formulas ---
      // Excel row numbers are 1-indexed. Since our loop rowIndex is 0-based relative to the sheet array logic in some libs,
      // but 'excel' package treats rowIndex as 0-indexed for access.
      // However, for the FORMULA STRING (e.g. "E5"), we need the actual Excel row number.
      // If rowIndex starts at 4 (which is row 5 in Excel visually), we add 1.
      final excelRow = rowIndex + 1;

      final actualTimeCellRef = 'E$excelRow'; // E column
      final scheduledTimeCellRef = 'F$excelRow'; // F column

      String asistenciaFormula;
      String motivoIncidenciaFormula;
      String observacionesFormula = '""'; // Default empty

      // Helper to safely format strings for Excel formulas (escaping double quotes)
      String safeExcelString(String? text) {
        if (text == null || text.trim().isEmpty) return '""';
        return '"${text.replaceAll('"', '""')}"';
      }

      if (exportType == 'entry') {
        // Asistencia: Check for tardy
        // IF(Scheduled=0, "PRESENTE", IF(Actual > Scheduled, "RETARDO", "PRESENTE"))
        asistenciaFormula =
            '=IF(TIMEVALUE($scheduledTimeCellRef)=0, "PRESENTE", IF(TIMEVALUE($actualTimeCellRef)>TIMEVALUE($scheduledTimeCellRef), "RETARDO", "PRESENTE"))';

        // Motivo:
        final reasonTardyExcel = safeExcelString(record.reasonTardy);

        // Logic:
        // IF(Actual > Scheduled + 15min, check reason (Strict),
        //   IF(Actual > Scheduled, check reason (Warning),
        //     ""
        //   )
        // )
        // Note: 15 mins in Excel day fraction is 15/1440
        motivoIncidenciaFormula =
            '=IF(TIMEVALUE($actualTimeCellRef) > TIMEVALUE($scheduledTimeCellRef) + (15/1440), IF(TRIM($reasonTardyExcel)="", "⚠️ RETARDO - PIDE MOTIVO", $reasonTardyExcel), IF(TIMEVALUE($actualTimeCellRef) > TIMEVALUE($scheduledTimeCellRef), IF(TRIM($reasonTardyExcel)="", "Llegó tarde.", $reasonTardyExcel), ""))';
      } else {
        // Exit: Check for early exit
        // IF(Scheduled=0, "PRESENTE", IF(Actual < Scheduled, "SALIDA ANTICIPADA", "PRESENTE"))
        asistenciaFormula =
            '=IF(TIMEVALUE($scheduledTimeCellRef)=0, "PRESENTE", IF(TIMEVALUE($actualTimeCellRef)<TIMEVALUE($scheduledTimeCellRef), "SALIDA ANTICIPADA", "PRESENTE"))';

        // Motivo:
        final reasonEarlyExitExcel = safeExcelString(record.reasonEarlyExit);

        motivoIncidenciaFormula =
            '=IF(TIMEVALUE($actualTimeCellRef) < TIMEVALUE($scheduledTimeCellRef), IF(TRIM($reasonEarlyExitExcel)="", "⚠️ FALTA MOTIVO ⚠️", $reasonEarlyExitExcel), "")';
      }

      // Assign formulas
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = FormulaCellValue(motivoIncidenciaFormula);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = FormulaCellValue(asistenciaFormula);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = FormulaCellValue(observacionesFormula);

      // Apply styles
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .cellStyle = centerStyle;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .cellStyle = centerStyle;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .cellStyle = centerStyle;

      rowIndex++;
    }

    // AUTO-WIDTH
    sheet.setColumnWidth(0, 15.0); // Matrícula
    sheet.setColumnWidth(1, 40.0); // Nombre
    sheet.setColumnWidth(2, 12.0); // Grupo
    sheet.setColumnWidth(3, 15.0); // Fecha
    sheet.setColumnWidth(4, 20.0); // Hora Actual
    sheet.setColumnWidth(5, 20.0); // Hora Programada
    sheet.setColumnWidth(6, 40.0); // Motivo
    sheet.setColumnWidth(7, 20.0); // Asistencia
    sheet.setColumnWidth(8, 30.0); // Observaciones

    // --- SECOND SHEET: REFERENCE DATA ---
    // (Optional: You can keep or remove this section based on preference)
    final Sheet incidenceTypesSheet = excel['Tipos de Incidencia'];
    var refTitle =
        incidenceTypesSheet.cell(CellIndex.indexByString("A1"));
    refTitle.value = TextCellValue("LISTA DE TIPOS DE INCIDENCIA");
    refTitle.cellStyle = headerStyle;
    incidenceTypesSheet.setColumnWidth(0, 50.0);

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
      incidenceTypesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
          .value = TextCellValue(incidenceTypes[i]);
    }

    // --- SAVE FILE ---
    final List<int>? fileBytes = excel.save();

    if (fileBytes == null) return;

    final String fileName = customFileName ??
        'FORMATOASISTENCIAS_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.xlsx';

    if (kIsWeb) {
      await WebDownloader.downloadFile(
          Uint8List.fromList(fileBytes),
          fileName,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      if (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        
        // Ensure directory exists (though getApplicationDocumentsDirectory usually implies it)
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }

        await file.writeAsBytes(fileBytes);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Archivo guardado en: ${file.path}')));
        }
      }
    }
  }
}