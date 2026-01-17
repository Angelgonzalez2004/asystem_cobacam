import 'dart:io';
import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class IncidenceExcelExporter {
  /// Exporta incidencias a Excel.
  static Future<String?> exportToExcel({
    required List<Incidence> incidents,
    required List<Student> students,
    required String campus,
    String filterDescription = 'General',
    String? specificGroupName,
    List<String>?
        forceAllGroups, // Lista completa de grupos para generar hojas vacías
  }) async {
    final excel = Excel.createExcel();

    // --- ESTILOS ---
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("#1E88E5"),
      fontColorHex: ExcelColor.white,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.black,
    );

    // CASO 1: GRUPO ESPECÍFICO
    if (specificGroupName != null) {
      String sheetName = 'Grupo $specificGroupName';
      if (sheetName.length > 30) sheetName = sheetName.substring(0, 30);

      if (excel.sheets.containsKey('Sheet1')) {
        excel.rename('Sheet1', sheetName);
      }

      _buildSheet(
          excel,
          sheetName,
          incidents, // Datos filtrados (pueden ser vacíos)
          students,
          campus,
          "REPORTE DE INCIDENCIAS - GRUPO $specificGroupName",
          headerStyle,
          titleStyle);
    }
    // CASO 2: GENERAL (Todos)
    else {
      String mainSheetName = 'Reporte Global';
      if (excel.sheets.containsKey('Sheet1')) {
        excel.rename('Sheet1', mainSheetName);
      }

      // Hoja 1: Acumulado Global
      _buildSheet(
          excel,
          mainSheetName,
          incidents,
          students,
          campus,
          "REPORTE INTEGRAL DE INCIDENCIAS - $filterDescription",
          headerStyle,
          titleStyle);

      // Agrupar datos existentes
      final Map<String, List<Incidence>> groupedData = {};
      for (var inc in incidents) {
        if (!groupedData.containsKey(inc.group)) {
          groupedData[inc.group] = [];
        }
        groupedData[inc.group]!.add(inc);
      }

      // Definir qué grupos procesar (Forzados o solo los que tienen datos)
      List<String> groupsToProcess = [];
      if (forceAllGroups != null && forceAllGroups.isNotEmpty) {
        groupsToProcess = List.from(forceAllGroups);
      } else {
        groupsToProcess = groupedData.keys.toList();
      }

      // Ordenar y evitar duplicados
      groupsToProcess = groupsToProcess.toSet().toList();
      groupsToProcess.sort(); // Alfabético

      for (var groupName in groupsToProcess) {
        String sheetName = 'Grupo $groupName';
        // Limpieza de caracteres inválidos para Excel
        sheetName = sheetName.replaceAll(RegExp(r'[\/:*?"<>|[]'), '_');
        if (sheetName.length > 30) sheetName = sheetName.substring(0, 30);

        // Obtener datos (o lista vacía)
        final groupIncidents = groupedData[groupName] ?? [];

        _buildSheet(excel, sheetName, groupIncidents, students, campus,
            "REPORTE GRUPO $groupName", headerStyle, titleStyle);
      }
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) return null;

    final fileName =
        'Incidencias_${specificGroupName ?? "General"}_${campus}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (kIsWeb) {
      await downloadImageWeb(Uint8List.fromList(fileBytes), fileName);
      return 'Descarga iniciada';
    } else {
      if (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isAndroid ||
          Platform.isIOS) {
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

  static void _buildSheet(
      Excel excel,
      String sheetName,
      List<Incidence> data,
      List<Student> students,
      String campus,
      String title,
      CellStyle headerStyle,
      CellStyle titleStyle) {
    // Si la hoja ya existe (raro), usarla, si no, crearla
    final Sheet sheet = excel[sheetName];

    // Ajustar rango de merge para incluir nuevas columnas (hasta la U)
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("U1"),
        customValue: TextCellValue(title));
    sheet.cell(CellIndex.indexByString("A1")).cellStyle = titleStyle;

    sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("U2"),
        customValue: TextCellValue(
            "Plantel: $campus  |  Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}"));
    sheet.cell(CellIndex.indexByString("A2")).cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center, fontSize: 10, italic: true);

    final headers = [
      'Fecha', 'Hora', 'Matrícula', 'Nombre del Alumno', 'Edad', 'Género',
      'NSS',
      'Grupo', 'Ciclo',
      'Nombre Tutor', 'Tel. Tutor', 'Tel. Alumno', 'Correo Inst.', 'Domicilio',
      'Alergias', 'Condiciones de Salud',
      'Estado de Salud', // Columnas Médicas Separadas
      'Tipo de Falta', 'Observaciones',
      'Estatus', 'Resolución: Motivo', 'Resolución: Detalles',
      'Resolución: Fecha'
    ];

    int headerRow = 4;

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow - 1));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;

      double width = 15.0;
      if (i == 3) width = 35.0;
      if (i == 9) width = 30.0;
      if (i == 12) width = 25.0;
      if (i == 13) width = 30.0;
      if (i >= 14 && i <= 16) width = 25.0; // Ancho para campos médicos
      if (i == 18) width = 50.0; // Observaciones (ahora índice 18)
      if (i == 21) width = 40.0; // Resolución Detalles (ahora índice 21)
      sheet.setColumnWidth(i, width);
    }

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final row = headerRow + i;

      Student? s;
      try {
        s = students.firstWhere((st) => st.studentId == item.studentId);
      } catch (_) {}

      void write(int col, dynamic val) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = val is int
            ? IntCellValue(val)
            : TextCellValue(val?.toString() ?? 'N/A');

        // Estilo condicional para el estatus
        CellStyle style = CellStyle(
            backgroundColorHex: i % 2 == 0
                ? ExcelColor.fromHexString("#F9FAFB")
                : ExcelColor.white,
            verticalAlign: VerticalAlign.Top,
            textWrapping: TextWrapping.WrapText);

        if (headers[col] == 'Estatus' && val == 'Solucionado') {
          style = CellStyle(
            backgroundColorHex: i % 2 == 0
                ? ExcelColor.fromHexString("#F9FAFB")
                : ExcelColor.white,
            verticalAlign: VerticalAlign.Top,
            textWrapping: TextWrapping.WrapText,
            fontColorHex: ExcelColor.green,
            bold: true,
          );
        }

        cell.cellStyle = style;
      }

      write(0, DateFormat('dd/MM/yyyy').format(item.date));
      write(1, DateFormat('HH:mm').format(item.date));
      write(2, item.studentId);
      write(3, item.studentName);
      write(4, s?.age ?? 0);
      write(5, s?.gender ?? '-');
      write(6, s?.nss ?? 'Sin NSS');
      write(7, "👥 ${item.group}");
      write(8, item.schoolCycle);
      write(9, s?.guardianFullName ?? '-');
      write(10, s?.guardianPhone ?? '-');
      write(11, s?.studentPhone ?? '-');
      write(12, s?.institutionalEmail ?? '-');
      write(13, s?.placeOfResidence ?? '-');
      // Campos Médicos Separados
      write(14, s?.allergies?.isNotEmpty == true ? s!.allergies : 'Ninguna');
      write(
          15,
          s?.healthConditions?.isNotEmpty == true
              ? s!.healthConditions
              : 'Ninguna');
      write(
          16,
          s?.generalHealthStatus?.isNotEmpty == true
              ? s!.generalHealthStatus
              : 'Sano');

      write(17, item.type);
      write(18, item.description);
      // Nuevos datos
      write(19, item.status);
      write(20, item.resolutionReason ?? '-');
      write(21, item.resolutionDetails ?? '-');
      write(
          22,
          item.resolutionDate != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(item.resolutionDate!)
              : '-');
    }
  }
}
