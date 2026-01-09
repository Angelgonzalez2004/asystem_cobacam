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
  /// Incluye datos personales del alumno y del registro de asistencia.
  static Future<String?> exportToExcel({
    required List<Student> students,
    required Map<String, AttendanceRecord> attendanceMap,
    required DateTime date,
    required String cycle,
    String? groupFilter,
  }) async {
    final excel = Excel.createExcel();
    
    // Usar la hoja por defecto o crear una nueva
    final Sheet sheet = excel['Asistencia'];
    // Intentar borrar la hoja "Sheet1" si se creó otra, aunque createExcel suele traer Sheet1
    // Si cambiamos el nombre de Sheet1 a Asistencia es más seguro
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', 'Asistencia');
    }

    // Estilos Básicos (Nota: La versión 4.0.0 tiene soporte limitado de estilos en la versión gratuita/comunitaria, pero intentaremos)
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );

    // --- ENCABEZADOS ---
    final headers = [
      'Matrícula', 'Nombre Completo', 'Grupo', 'Ciclo Escolar', 
      'Estado Asistencia', 'Hora Entrada', 'Hora Salida', 
      'Motivo Retardo', 'Motivo Salida Anticipada',
      'Nombre Tutor', 'Teléfono Tutor', 'Teléfono Alumno', 
      'Género', 'Condiciones Médicas / Alergias'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]); 
      cell.cellStyle = headerStyle;
    }

    // --- DATOS ---
    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final record = attendanceMap[student.studentId];
      final row = i + 1;

      // Determinar Estado Legible
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

      // Helper para escribir celda de forma segura
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

    // --- GUARDAR ARCHIVO ---
    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final dateStr = DateFormat('yyyyMMdd').format(date);
    final groupStr = groupFilter != null ? '_$groupFilter' : '_General';
    final fileName = 'Reporte_Asistencia_$dateStr$groupStr.xlsx';

    if (kIsWeb) {
      // Reutilizamos la utilidad de descarga web existente
      await downloadImageWeb(Uint8List.fromList(fileBytes), fileName);
      return 'Archivo descargado';
    } else {
      // Escritorio / Móvil
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
         try {
           // Usamos path_provider para encontrar un lugar seguro
           Directory? dir;
           if (Platform.isAndroid) {
             dir = await getExternalStorageDirectory(); // Carpeta de app
             // O intentar downloads si es accesible, pero externalStorage es seguro
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
}
