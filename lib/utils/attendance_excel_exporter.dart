import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:asystem_cobacam/utils/web_downloader.dart';


class AttendanceExcelExporter {
  static Future<void> exportAdvancedReport({
    required BuildContext context,
    required List<Student> students,
    required Map<String, Map<String, dynamic>> stats,
    required String campus,
    required String rangeLabel,
    required String cycle,
    bool isIndividual = false,
  }) async {
    final excel = Excel.createExcel();
    const String generalSheetName = 'General';
    // Renombrar hoja default si existe
    if (excel.sheets.keys.isNotEmpty) {
      final defaultSheet = excel.sheets.keys.first;
      excel.rename(defaultSheet, generalSheetName);
    }

    // --- ESTILOS ---
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue, // Fixed color
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final warningStyle = CellStyle(
        backgroundColorHex: ExcelColor.orange, bold: true); // Fixed color
    final criticalStyle = CellStyle(
        backgroundColorHex: ExcelColor.red,
        fontColorHex: ExcelColor.white,
        bold: true); // Fixed color
    final centerStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

    final Set<String> groups = students.map((s) => s.group).toSet();
    final List<String> sortedGroups = groups.toList()..sort();

    // --- 1. HOJA GENERAL ---
    _buildSheet(excel, generalSheetName, students, stats, headerStyle,
        warningStyle, criticalStyle, centerStyle, campus, rangeLabel, cycle,
        isGeneral: true);

    // --- 2. HOJAS POR GRUPO (Solo si NO es individual y hay varios grupos) ---
    if (!isIndividual && sortedGroups.length > 1) {
      for (final groupName in sortedGroups) {
        final groupStudents =
            students.where((s) => s.group == groupName).toList();
        _buildSheet(
            excel,
            "Grupo $groupName",
            groupStudents,
            stats,
            headerStyle,
            warningStyle,
            criticalStyle,
            centerStyle,
            campus,
            rangeLabel,
            cycle);
      }
    }

    final List<int>? fileBytes = excel.encode();
    if (fileBytes == null) return;

    // Nombre de Archivo Inteligente
    final cleanRange =
        rangeLabel.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    String fileName;

    if (isIndividual && students.isNotEmpty) {
      final safeName = students.first.fullName.replaceAll(' ', '_');
      fileName = 'Reporte_Individual_${safeName}_$cleanRange.xlsx';
    } else {
      fileName = 'Reporte_Asistencias_$cleanRange.xlsx';
    }

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

  static void _buildSheet(
      Excel excel,
      String sheetName,
      List<Student> sheetStudents,
      Map<String, Map<String, dynamic>> stats,
      CellStyle headerStyle,
      CellStyle warningStyle,
      CellStyle criticalStyle,
      CellStyle centerStyle,
      String campus,
      String range,
      String cycle,
      {bool isGeneral = false}) {
    // Si la hoja no existe, la creamos al accederla implícitamente o actualizando una celda
    // En excel 4.0+, updateCell crea la hoja si no existe.
    if (!excel.sheets.keys.contains(sheetName)) {
      // Fix: updateCell requires CellValue
      excel.updateCell(
          sheetName, CellIndex.indexByString("A1"), TextCellValue(""));
    }
    final Sheet sheet = excel[sheetName];

    // HEADER DEL REPORTE
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("J1"));
    var cellTitle = sheet.cell(CellIndex.indexByString("A1"));
    cellTitle.value = TextCellValue("REPORTE DE ASISTENCIAS - $campus");
    cellTitle.cellStyle = CellStyle(
        bold: true, fontSize: 14, horizontalAlign: HorizontalAlign.Center);

    sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("J2"));
    var cellSub = sheet.cell(CellIndex.indexByString("A2"));
    cellSub.value = TextCellValue(
        "Periodo: $range | Ciclo: $cycle | ${isGeneral ? 'Vista General' : sheetName}");
    cellSub.cellStyle =
        CellStyle(italic: true, horizontalAlign: HorizontalAlign.Center);

    // COLUMNAS COMPLETAS (18+ campos)
    final headers = [
      'Matrícula',
      'Nombre Completo',
      'Grupo',
      'Género',
      'Edad',
      'NSS',
      'Estado General Salud',
      'Alergias',
      'Condiciones Médicas',
      'Tutor',
      'Teléfono Tutor',
      'Teléfono Alumno',
      'Email Institucional',
      'Domicilio',
      'Estado (Activo/Baja)',
      'Motivo de Baja',
      'Alerta Médica Crítica',
      'Asistencias',
      'Retardos',
      'Faltas',
      'Estatus de Riesgo'
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    int rowIndex = 4;

    // Ordenar
    sheetStudents.sort((a, b) {
      int cmp = a.group.compareTo(b.group);
      if (cmp != 0) return cmp;
      return a.fullName.compareTo(b.fullName);
    });

    for (var student in sheetStudents) {
      final stat = stats[student.studentId];
      if (stat == null) continue;

      final int presences = stat['presences'] ?? 0;
      final int faults = stat['faults'] ?? 0;
      final int lates = stat['lates'] ?? 0;
      final String alert = stat['alertLevel'] ?? 'none';

      var rowCells = [
        student.studentId,
        student.fullName,
        student.group,
        student.gender,
        student.age,
        student.nss ?? 'N/A',
        student.generalHealthStatus ?? 'Sano',
        student.allergies ?? 'Ninguna',
        student.healthConditions ?? 'Ninguna',
        student.guardianFullName,
        student.guardianPhone,
        student.studentPhone ?? 'N/A',
        student.institutionalEmail,
        student.placeOfResidence,
        student.isActive ? 'ACTIVO' : 'BAJA',
        student.deactivationReason ?? 'N/A',
        student.medicalAlert ? 'SÍ (CRÍTICO)' : 'NO',
        presences,
        lates,
        faults,
        alert == 'urgent'
            ? 'CRÍTICO (3+)'
            : (alert == 'warning' ? 'ADVERTENCIA (2)' : 'NORMAL')
      ];

      for (var col = 0; col < rowCells.length; col++) {
        var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = _getValue(rowCells[col]);
        cell.cellStyle = centerStyle;

        // Colorear SOLO la celda de riesgo (Índice 20 ahora)
        if (col == 20) {
          if (alert == 'urgent') {
            cell.cellStyle = criticalStyle;
          } else if (alert == 'warning') {
            cell.cellStyle = warningStyle;
          }
        }
      }
      rowIndex++;
    }

    // AUTO-ANCHO PROFESIONAL (Generoso para lectura fácil)
    sheet.setColumnWidth(0, 18.0); // Matrícula
    sheet.setColumnWidth(1, 55.0); // Nombre Completo (Muy amplio)
    sheet.setColumnWidth(2, 15.0); // Grupo
    sheet.setColumnWidth(3, 12.0); // Género
    sheet.setColumnWidth(4, 8.0); // Edad
    sheet.setColumnWidth(5, 20.0); // NSS
    sheet.setColumnWidth(6, 30.0); // Estado Salud
    sheet.setColumnWidth(7, 40.0); // Alergias
    sheet.setColumnWidth(8, 40.0); // Condiciones
    sheet.setColumnWidth(9, 45.0); // Tutor
    sheet.setColumnWidth(10, 20.0); // Tel Tutor
    sheet.setColumnWidth(11, 20.0); // Tel Alumno
    sheet.setColumnWidth(12, 45.0); // Email
    sheet.setColumnWidth(13, 60.0); // Domicilio (El más ancho)
    sheet.setColumnWidth(14, 15.0); // Estado
    sheet.setColumnWidth(15, 30.0); // Motivo Baja
    sheet.setColumnWidth(16, 20.0); // Alerta Médica
    sheet.setColumnWidth(17, 15.0); // Asistencias
    sheet.setColumnWidth(18, 15.0); // Retardos
    sheet.setColumnWidth(19, 15.0); // Faltas
    sheet.setColumnWidth(20, 25.0); // Riesgo
  }

  static CellValue _getValue(dynamic val) {
    if (val is int) return IntCellValue(val);
    if (val is double) return DoubleCellValue(val);
    return TextCellValue(val.toString());
  }
}
