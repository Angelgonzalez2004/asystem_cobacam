import 'dart:io';
import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class IncidenceExcelExporter {
  static Future<String?> exportToExcel({
    required List<Incidence> incidents,
    required String campus,
  }) async {
    final excel = Excel.createExcel();
    
    // Configurar hoja principal
    String sheetName = 'Reporte Incidencias';
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    
    final Sheet sheet = excel[sheetName];

    // Estilos
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.red, // Rojo para incidencias
      fontColorHex: ExcelColor.white,
    );

    // Título
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("G1"), customValue: TextCellValue("REPORTE DE INCIDENCIAS DISCIPLINARIAS - $campus"));
    sheet.cell(CellIndex.indexByString("A1")).cellStyle = CellStyle(bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);

    // Encabezados
    final headers = [
      'Fecha y Hora', 'Matrícula', 'Nombre del Alumno', 
      'Grupo', 'Ciclo Escolar', 'Tipo de Falta', 'Observaciones'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, 25.0);
    }
    sheet.setColumnWidth(2, 40.0); // Nombre más ancho
    sheet.setColumnWidth(6, 50.0); // Observaciones más ancho

    // Datos
    for (var i = 0; i < incidents.length; i++) {
      final item = incidents[i];
      final row = i + 2;

      void write(int col, dynamic val) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = val is int ? IntCellValue(val) : TextCellValue(val.toString());
        // Alternar color de filas para legibilidad
        if (i % 2 != 0) {
           cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString("#F5F5F5"));
        }
      }

      write(0, DateFormat('dd/MM/yyyy HH:mm').format(item.date));
      write(1, item.studentId);
      write(2, item.studentName);
      write(3, item.group);
      write(4, item.schoolCycle);
      write(5, item.type);
      write(6, item.description);
    }

    // Guardar
    // Usar encode() para evitar descarga automática duplicada en Web
    final fileBytes = excel.encode();
    if (fileBytes == null) return null;

    final fileName = 'Incidencias_${campus}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

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
           return null;
         }
      }
      return null;
    }
  }
}
