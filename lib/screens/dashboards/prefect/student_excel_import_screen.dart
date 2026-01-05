import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart'; // Import the excel package
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';

class StudentExcelImportScreen extends StatefulWidget {
  final String campusId;
  final String currentSchoolCycle;

  const StudentExcelImportScreen({
    super.key,
    required this.campusId,
    required this.currentSchoolCycle,
  });

  @override
  State<StudentExcelImportScreen> createState() => _StudentExcelImportScreenState();
}

class _StudentExcelImportScreenState extends State<StudentExcelImportScreen> {
  List<Student> _parsedStudents = [];
  String? _filePath;
  bool _isLoading = false;
  bool _isImporting = false;
  List<Group> _availableGroups = []; // To validate groups from Excel

  @override
  void initState() {
    super.initState();
    _loadAvailableGroups();
  }

  Future<void> _loadAvailableGroups() async {
    try {
      final groupsSnapshot = await FirebaseDatabase.instance.ref('planteles/${widget.campusId}/groups').get();
      if (groupsSnapshot.exists) {
        final List<Group> fetchedGroups = [];
        for (final child in groupsSnapshot.children) {
          fetchedGroups.add(Group.fromSnapshot(child));
        }
        if (mounted) {
          setState(() {
            _availableGroups = fetchedGroups;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error al cargar grupos disponibles para validación: ${e.toString()}');
    }
  }

  Future<void> _pickExcelFile() async {
    setState(() {
      _isLoading = true;
      _parsedStudents = [];
      _filePath = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        _filePath = result.files.single.path;
        await _parseExcel(_filePath!);
      } else {
        // User canceled the picker
        if (mounted) _showErrorSnackBar('Selección de archivo cancelada.');
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar el archivo: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _parseExcel(String path) async {
    try {
      var bytes = File(path).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      List<Student> studentsToImport = [];
      final List<String> expectedHeaders = [
        'nombre_completo',
        'tutor',
        'edad',
        'telefono_tutor',
        'telefono_alumno',
        'genero',
        'residencia',
        'email_institucional',
        'matricula',
        'grupo',
      ];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null || sheet.maxCols < expectedHeaders.length) {
          _showErrorSnackBar('La hoja "$table" del Excel no tiene el formato esperado (mínimo ${expectedHeaders.length} columnas).');
          continue; // Skip this sheet
        }

        // --- Validar Encabezados ---
        final List<String> headers = sheet.row(0).map((cell) => cell?.value?.toString().toLowerCase().replaceAll(' ', '_') ?? '').toList();
        
        bool headersMatch = true;
        for (int i = 0; i < expectedHeaders.length; i++) {
          if (headers[i] != expectedHeaders[i]) {
            headersMatch = false;
            break;
          }
        }
        if (!headersMatch) {
          _showErrorSnackBar('La hoja "$table" del Excel no tiene los encabezados esperados o el orden es incorrecto. Se esperaban: ${expectedHeaders.join(', ')}');
          continue;
        }

        final String sheetGroupName = table; // Sheet name is the group name
        if (!_availableGroups.any((g) => g.name == sheetGroupName)) {
          _showErrorSnackBar('El grupo "$sheetGroupName" (nombre de la hoja) no existe. Por favor, asegúrate de que el grupo esté registrado.');
          continue; // Skip this sheet
        }

        // Assuming first row is header, skip it.
        for (int i = 1; i < sheet.maxRows; i++) { // Start from second row
          var row = sheet.row(i);
          if (row.every((cell) => cell?.value == null)) continue; // Skip entirely empty rows

          try {
            final String studentFullName = row[headers.indexOf('nombre_completo')]?.value?.toString() ?? '';
            final String guardianFullName = row[headers.indexOf('tutor')]?.value?.toString() ?? '';
            final String ageStr = row[headers.indexOf('edad')]?.value?.toString() ?? '0';
            final String guardianPhone = row[headers.indexOf('telefono_tutor')]?.value?.toString() ?? '';
            final String studentPhone = row[headers.indexOf('telefono_alumno')]?.value?.toString() ?? '';
            final String gender = row[headers.indexOf('genero')]?.value?.toString() ?? '';
            final String placeOfResidence = row[headers.indexOf('residencia')]?.value?.toString() ?? '';
            final String institutionalEmail = row[headers.indexOf('email_institucional')]?.value?.toString() ?? '';
            final String studentId = row[headers.indexOf('matricula')]?.value?.toString() ?? ''; // Matrícula
            final String excelGroupName = row[headers.indexOf('grupo')]?.value?.toString() ?? ''; // Group from Excel column

            // Basic validation
            if (studentFullName.isEmpty || guardianFullName.isEmpty || gender.isEmpty || studentId.isEmpty || excelGroupName.isEmpty) {
              _showErrorSnackBar('Fila ${i+1} en hoja "$table": faltan datos obligatorios.');
              continue;
            }
            if (!['Masculino', 'Femenino', 'No Binario', 'Otro'].contains(gender)) { // Added more gender options
              _showErrorSnackBar('Fila ${i+1} en hoja "$table": género inválido ("$gender").');
              continue;
            }
            final int age = int.tryParse(ageStr) ?? -1;
            if (age < 0 || age > 100) { // More robust age validation
              _showErrorSnackBar('Fila ${i+1} en hoja "$table": edad inválida ("$ageStr").');
              continue;
            }
            if (excelGroupName != sheetGroupName) {
              _showErrorSnackBar('Fila ${i+1} en hoja "$table": el grupo de la columna ("$excelGroupName") no coincide con el nombre de la hoja ("$sheetGroupName").');
              continue;
            }

            studentsToImport.add(Student(
              id: studentId, // Use matricula as ID
              fullName: studentFullName,
              guardianFullName: guardianFullName,
              age: age,
              guardianPhone: guardianPhone,
              studentPhone: studentPhone.isNotEmpty ? studentPhone : null,
              gender: gender,
              placeOfResidence: placeOfResidence,
              schoolCycle: widget.currentSchoolCycle,
              group: sheetGroupName, // Use sheet name as the definitive group
              institutionalEmail: institutionalEmail,
              studentId: studentId,
              isActive: true, // New students are active
            ));
          } catch (e) {
            _showErrorSnackBar('Error al procesar fila ${i+1} en hoja "$table": ${e.toString()}');
            continue;
          }
        }
      }
      if (mounted) {
        setState(() {
          _parsedStudents = studentsToImport;
        });
        _showSuccessSnackBar('Archivo Excel procesado. ${studentsToImport.length} alumnos listos para importar.');
      }
    } catch (e) {
      _showErrorSnackBar('Error al leer o parsear el archivo Excel: ${e.toString()}');
    }
  }

  Future<void> _importStudentsToFirebase() async {
    if (_parsedStudents.isEmpty) {
      _showErrorSnackBar('No hay alumnos para importar.');
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Importación Masiva'),
        content: Text('Se importarán ${_parsedStudents.length} alumnos. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Importar')),
        ],
      ),
    );

    if (confirm != true) {
      _showErrorSnackBar('Importación cancelada por el usuario.');
      return;
    }

    if (!mounted) return;
    setState(() => _isImporting = true);

    try {
      final databaseRef = FirebaseDatabase.instance.ref('planteles/${widget.campusId}/students/${widget.currentSchoolCycle}');
      int importedCount = 0;
      int updatedCount = 0;
      int errorCount = 0;
      final List<String> errorMessages = [];

      for (final student in _parsedStudents) {
        try {
          // Check if student already exists (by studentId)
          final existingStudentSnapshot = await databaseRef.child(student.studentId).get();
          if (existingStudentSnapshot.exists) {
            // Student exists, update their data
            await databaseRef.child(student.studentId).update(student.toFirebaseMap());
            updatedCount++;
          } else {
            // New student, set their data
            await databaseRef.child(student.studentId).set(student.toFirebaseMap());
            importedCount++;
          }
        } catch (e) {
          errorCount++;
          errorMessages.add('Error al importar alumno ${student.fullName} (Matrícula: ${student.studentId}): ${e.toString()}');
        }
      }

      String summaryMessage = 'Importación finalizada:\n';
      if (importedCount > 0) summaryMessage += '$importedCount alumnos nuevos importados.\n';
      if (updatedCount > 0) summaryMessage += '$updatedCount alumnos existentes actualizados.\n';
      if (errorCount > 0) summaryMessage += '$errorCount errores.\n';
      if (errorMessages.isNotEmpty) summaryMessage += 'Detalles de errores:\n${errorMessages.join('\n')}';

      if (mounted) {
        _showSuccessSnackBar(summaryMessage);
        // Maybe pop only after user acknowledges the message
        // Navigator.of(context).pop(true); // Indicate success and close screen
      }
    } catch (e) {
      _showErrorSnackBar('Error general durante la importación: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading || _isImporting
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Seleccionar Archivo Excel (.xlsx)'),
                        onPressed: _pickExcelFile,
                      ),
                    ),
                    if (_filePath != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Archivo seleccionado: ${_filePath!.split('/').last}'),
                      ),
                    if (_parsedStudents.isNotEmpty)
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('${_parsedStudents.length} alumnos encontrados en el archivo:'),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _parsedStudents.length,
                                itemBuilder: (context, index) {
                                  final student = _parsedStudents[index];
                                  return ListTile(
                                    title: Text(student.fullName),
                                    subtitle: Text('Matrícula: ${student.studentId}, Grupo: ${student.group}'),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Importar a Firebase'),
                                onPressed: _importStudentsToFirebase,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_filePath != null)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No se encontraron alumnos válidos en el archivo Excel o el formato es incorrecto.'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
