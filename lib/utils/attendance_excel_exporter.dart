import 'dart:io';
import 'package:asystem_cobacam/models/attendance_record_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AttendanceExcelExporter {
  /// Genera y descarga un archivo Excel con el reporte detallado de asistencia.
  /// Estructura:
  /// - Hoja 1: Reporte General (Todos los registros).
  /// - Hoja 2+: Un reporte por cada Grupo encontrado.
  static Future<String?> exportToExcel({
    required List<Student> students,
    required Map<String, AttendanceRecord> attendanceMap,
    required DateTime date,
    required String cycle,
    String? groupFilter,
  }) async {
    final excel = Excel.createExcel();
    
    // --- HOJA MAESTRA (GENERAL) ---
    // Renombrar la hoja por defecto si existe
    String generalSheetName = 'Reporte General';
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', generalSheetName);
    } else {
      // Si no existe Sheet1 (raro), usar la primera disponible o crearla
      if (excel.sheets.isNotEmpty) {
         generalSheetName = excel.sheets.keys.first;
         excel.rename(generalSheetName, 'Reporte General');
         generalSheetName = 'Reporte General';
      }
    }
    
    final Sheet sheetGeneral = excel[generalSheetName];
    _fillSheet(sheetGeneral, students, attendanceMap, cycle, "Reporte General");

    // --- HOJAS POR GRUPO ---
    // Agrupar estudiantes
    final Map<String, List<Student>> studentsByGroup = {};
    for (var s in students) {
      if (!studentsByGroup.containsKey(s.group)) {
        studentsByGroup[s.group] = [];
      }
      studentsByGroup[s.group]!.add(s);
    }

    // Crear hojas ordenadas por grupo (solo si hay más de un grupo o si se quiere detalle)
    // Si ya filtramos por un solo grupo en la pantalla, la hoja General es igual a la del grupo.
    // Pero el usuario pidió: "primera hoja todos, segunda en adelante por grupos".
    // Si 'groupFilter' es null (Todos), hacemos esto. Si es específico, quizás solo una hoja basta, pero cumpliremos el requisito.
    
    final sortedGroups = studentsByGroup.keys.toList()..sort();
    
    // Si hay multiples grupos, crear hojas adicionales
    if (sortedGroups.isNotEmpty) {
       for (var groupName in sortedGroups) {
          // Limpiar nombre de hoja (Excel tiene limites de caracteres y caracteres prohibidos)
          final safeName = 'Gpo ${groupName.replaceAll(RegExp(r'[\/*?:[\\]'), '_')}';
          // Si el nombre es muy largo, cortarlo
          final finalSheetName = safeName.length > 30 ? safeName.substring(0, 30) : safeName;
          
          final Sheet sheetGroup = excel[finalSheetName];
          _fillSheet(sheetGroup, studentsByGroup[groupName]!, attendanceMap, cycle, "Grupo $groupName");
       }
    }

    // --- GUARDAR ARCHIVO ---
    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final dateStr = DateFormat('yyyyMMdd').format(date);
    final groupStr = groupFilter != null ? '_Gpo$groupFilter' : '_Todos';
    final fileName = 'Asistencia_COBACAM_$dateStr$groupStr.xlsx';

    if (kIsWeb) {
      // Reutilizamos la utilidad de descarga web existente que usa anchor.download = fileName
      await downloadImageWeb(Uint8List.fromList(fileBytes), fileName);
      return 'Descarga iniciada';
    } else {
      // Escritorio / Móvil
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

  static void _fillSheet(Sheet sheet, List<Student> list, Map<String, AttendanceRecord> attendanceMap, String cycle, String title) {
    // Estilos Básicos
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );

    // Título de la hoja en la primera fila
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("N1"), customValue: TextCellValue(title));
    final titleCell = sheet.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue(title.toUpperCase());
    titleCell.cellStyle = titleStyle;

    // --- ENCABEZADOS (Fila 2) ---
    final headers = [
      'Matrícula', 'Nombre Completo', 'Grupo', 'Ciclo Escolar',
      'Estado Asistencia', 'Hora Entrada', 'Hora Salida',
      'Motivo Retardo', 'Motivo Salida Anticipada',
      'Nombre Tutor', 'Teléfono Tutor', 'Teléfono Alumno',
      'Género', 'Condiciones Médicas / Alergias'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1)); // Row 1 (0-based is row 2)
      cell.value = TextCellValue(headers[i]); 
      cell.cellStyle = headerStyle;
      // Intento de ancho de columna (aproximado, la librería v4 no siempre lo respeta visualmente igual)
      sheet.setColumnWidth(i, 20.0); 
    }
    sheet.setColumnWidth(1, 35.0); // Nombre más ancho
    sheet.setColumnWidth(9, 30.0); // Tutor más ancho

    // --- DATOS (Fila 3 en adelante) ---
    for (var i = 0; i < list.length; i++) {
      final student = list[i];
      final record = attendanceMap[student.studentId];
      final row = i + 2; // Empezar en fila index 2 (Visualmente fila 3)

      String status = 'FALTA';
      if (record != null) {
        if (record.status == 'presente' || record.status == 'presente_masivo') {
          status = 'PRESENTE';
        } else if (record.status == 'tarde') {
          status = 'RETARDO';
        } else if (record.status == 'justificada') {
          status = 'JUSTIFICADO';
        }
      }

      void write(int col, dynamic val) {
        final cellIndex = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
        if (val == null) {
          sheet.cell(cellIndex).value = null;
        } else if (val is int) {
          sheet.cell(cellIndex).value = IntCellValue(val);
        } else {
          sheet.cell(cellIndex).value = TextCellValue(val.toString());
        }
      }

      write(0, student.studentId);
      write(1, student.fullName);
      write(2, student.group);
      write(3, cycle);
      write(4, status);
      write(5, record?.entryTime ?? '--:--');
      write(6, record?.exitTime ?? '--:--');
      write(7, record?.reasonTardy ?? '');
      write(8, record?.reasonEarlyExit ?? '');
      write(9, student.guardianFullName);
      write(10, student.guardianPhone);
      write(11, student.studentPhone ?? '');
      write(12, student.gender);
      
      final salud = '${student.allergies ?? ''} ${student.healthConditions ?? ''}'.trim();
      write(13, salud.isEmpty ? 'Ninguna' : salud);
    }
  }
}