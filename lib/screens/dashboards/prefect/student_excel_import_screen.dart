// ignore_for_file: unnecessary_nullable_for_final_variable_declarations
import 'dart:io';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW IMPORT
import 'dart:typed_data';
class StudentExcelImportScreen extends StatefulWidget {
  final String campusId;
  final String currentSchoolCycle;

  const StudentExcelImportScreen({
    super.key,
    required this.campusId,
    required this.currentSchoolCycle,
  });

  @override
  State<StudentExcelImportScreen> createState() =>
      _StudentExcelImportScreenState();
}

class _StudentExcelImportScreenState extends State<StudentExcelImportScreen> {
  List<Student> _parsedStudents = [];
  String? _filePath;
  bool _isLoading = false;
  bool _isImporting = false;
  List<Group> _availableGroups = [];
  bool _isLoadingGroups = true; // NEW: Loading state for groups

  // Cycle Management
  List<SchoolCycle> _availableSchoolCycles = [];
  String? _targetSchoolCycle;
  bool _isLoadingCycles = true;

  late final AppSettingsService _appSettingsService;

  @override
  void initState() {
    super.initState();
    _appSettingsService = AppSettingsService(
      Provider.of<HiveService>(context, listen: false),
      Provider.of<ConnectivityService>(context, listen: false),
    );
    _targetSchoolCycle = widget.currentSchoolCycle;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cycles = await _appSettingsService.getAllSchoolCycles();
      if (mounted) {
        setState(() {
          _availableSchoolCycles = cycles;
          _isLoadingCycles = false;
        });
        // Cargar grupos del ciclo por defecto
        setState(() {
          _isLoadingGroups = true; // Set loading to true before fetching groups
        });
        await _loadAvailableGroups(_targetSchoolCycle!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCycles = false);
    }
  }

  Future<void> _loadAvailableGroups(String cycleId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingGroups = true; // Start loading groups
      _availableGroups = []; // Clear previous groups
    });
    try {
      final groupsSnapshot = await FirebaseDatabase.instance
          .ref('planteles/${widget.campusId}/groups')
          .orderByChild('schoolCycleId') // Filtrar por ciclo
          .equalTo(cycleId)
          .get();

      if (groupsSnapshot.exists) {
        final List<Group> fetchedGroups = [];
        for (final child in groupsSnapshot.children) {
          fetchedGroups.add(Group.fromSnapshot(child));
        }
        if (mounted) setState(() => _availableGroups = fetchedGroups);
      } else {
        if (mounted) setState(() => _availableGroups = []);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar grupos.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingGroups = false); // End loading groups
    }
  }

  Future<void> _pickExcelFile() async {
    // 1. Mostrar un diálogo de confirmación/recordatorio primero.
    final bool? confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Recordatorio Importante',
      content:
          'Antes de importar el archivo Excel, asegúrate de que los grupos para el ciclo escolar seleccionado ya han sido creados en el sistema.',
      confirmText: 'Continuar',
      cancelText: 'Cancelar',
    );

    if (confirmed != true) {
      return; // El usuario canceló la operación.
    }

    if (_isLoadingGroups) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Cargando grupos, por favor espera.',
            isError: true);
      }
      return;
    }
    
    if (_targetSchoolCycle == null) return;

    // Validación crítica: Deben existir grupos para este ciclo
    if (_availableGroups.isEmpty) {
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Sin Grupos Registrados'),
                content: Text(
                    'No existen grupos registrados para el ciclo escolar $_targetSchoolCycle.\n\nPor favor, ve a "Gestión de Grupos" y crea los grupos (ej. 101, 102) antes de importar alumnos.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Entendido'))
                ],
              ));
      return;
    }

    setState(() {
      _isLoading = true;
      _parsedStudents = [];
      _filePath = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // Asegura que los bytes se carguen en la web
      );

      if (result != null) {
        final PlatformFile file = result.files.single;
        setState(() {
          _filePath = file.name; // Usar file.name para mostrar en la UI
        });

        // En la web, file.bytes no será nulo si withData es true.
        // En móvil/escritorio, podríamos necesitar leer desde la ruta si file.bytes es nulo.
        Uint8List? fileBytes = file.bytes;

        if (fileBytes == null && file.path != null) {
          // Fallback para móvil/escritorio si los bytes no se cargaron directamente
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null) {
          await _parseExcel(fileBytes);
        } else {
          if (mounted) {
            UiHelpers.showSnackBar(context, 'No se pudo leer el archivo.',
                isError: true);
          }
        }
      } else {
        if (mounted) UiHelpers.showSnackBar(context, 'Selección cancelada.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al seleccionar archivo: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _parseExcel(Uint8List bytes) async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? ''; // Get current prefect's UID
    try {
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
        'grupo', // Esto podría ser redundante si el nombre de la hoja es el grupo, pero sirve para validar
        'alergias',
        'condiciones_salud',
        'estado_salud',
        'alerta_medica', // Nuevo campo
      ];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) {
          continue;
        }

        // Validar si el nombre de la hoja corresponde a un grupo existente

        final groupNameFromSheet = table.trim();
        // Verificar si este grupo existe en el ciclo seleccionado
        if (!_availableGroups.any((g) => g.name == groupNameFromSheet)) {
          debugPrint(
              "Grupo $groupNameFromSheet no encontrado en ciclo $_targetSchoolCycle. Saltando hoja.");
          continue;
        }

        final List<String> headers = sheet
            .row(0)
            .map((cell) =>
                cell?.value?.toString().toLowerCase().replaceAll(' ', '_') ??
                '')
            .toList();

        bool headersMatch = true;
        for (var h in expectedHeaders) {
          if (!headers.contains(h)) {
            // Permitir que las médicas sean opcionales
            if (![
              'alergias',
              'condiciones_salud',
              'estado_salud',
              'grupo',
              'alerta_medica'
            ].contains(h)) {
              headersMatch = false;
              break;
            }
          }
        }
        if (!headersMatch) continue;

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.every((cell) => cell?.value == null)) continue;

          try {
            // --- VALIDACIÓN DE CAMPOS OBLIGATORIOS (EXCEL) ---
            final studentId =
                row[headers.indexOf('matricula')]?.value?.toString().trim() ??
                    '';
            final fullName = row[headers.indexOf('nombre_completo')]
                    ?.value
                    ?.toString()
                    .trim() ??
                '';
            final gender =
                row[headers.indexOf('genero')]?.value?.toString().trim() ?? '';

            // Si falta alguno de los obligatorios, saltamos la fila
            if (studentId.isEmpty || fullName.isEmpty || gender.isEmpty) {
              debugPrint(
                  "Fila $i omitida: Faltan datos obligatorios (Matrícula, Nombre o Género)");
              continue;
            }

            // Lógica para Alerta Médica
            bool isMedicalAlert = false;
            if (headers.contains('alerta_medica')) {
              final val = row[headers.indexOf('alerta_medica')]
                  ?.value
                  ?.toString()
                  .toLowerCase()
                  .trim();
              if (val == 'si' || val == '1' || val == 'true') {
                isMedicalAlert = true;
              }
            }

            studentsToImport.add(Student(
              id: studentId,
              userId: '', // Will be updated when student first logs in or account is created
              registeredByUserId: currentUserUid, // Prefect who registered this student
              fullName: fullName,
              guardianFullName:
                  row[headers.indexOf('tutor')]?.value?.toString() ?? '',
              age: int.tryParse(
                      row[headers.indexOf('edad')]?.value?.toString() ?? '0') ??
                  0,
              guardianPhone:
                  row[headers.indexOf('telefono_tutor')]?.value?.toString() ??
                      '',
              studentPhone:
                  row[headers.indexOf('telefono_alumno')]?.value?.toString(),
              gender: gender,
              placeOfResidence:
                  row[headers.indexOf('residencia')]?.value?.toString() ?? '',
              schoolCycle:
                  _targetSchoolCycle!, // OBLIGATORIO (Seleccionado en UI)
              group: groupNameFromSheet, // OBLIGATORIO (Nombre de la Hoja)
              institutionalEmail: row[headers.indexOf('email_institucional')]
                      ?.value
                      ?.toString() ??
                  '',
              studentId: studentId,
              isActive: true,
              allergies: headers.contains('alergias')
                  ? row[headers.indexOf('alergias')]?.value?.toString()
                  : null,
              healthConditions: headers.contains('condiciones_salud')
                  ? row[headers.indexOf('condiciones_salud')]?.value?.toString()
                  : null,
              generalHealthStatus: headers.contains('estado_salud')
                  ? (row[headers.indexOf('estado_salud')]?.value?.toString() ??
                      'Sano')
                  : 'Sano',
              medicalAlert: isMedicalAlert,
            ));
          } catch (e) {
            continue;
          }
        }
      }

      if (studentsToImport.isEmpty) {
        if (mounted) {
          UiHelpers.showSnackBar(context,
              'No se encontraron alumnos válidos o los grupos del Excel no existen en este ciclo.',
              isError: true);
        }
      } else {
        if (mounted) {
          setState(() => _parsedStudents = studentsToImport);
          UiHelpers.showSnackBar(context,
              'Excel procesado: ${studentsToImport.length} alumnos listos.');
        }
      }
    } catch (e) {
      if (mounted) {
        // Limpiar el estado para que el usuario pueda reintentar sin confusión
        setState(() {
          _filePath = null;
          _parsedStudents = [];
        });

        String errorMessage = 'Error al procesar Excel: $e';
        if (e.toString().contains('_Namespace')) {
          await UiHelpers.showAlertDialog(
            context,
            title: 'Error de Formato de Excel',
            content:
                'El archivo .xlsx que intentas importar parece tener un formato XML interno no compatible, lo que causa el error: "Unsupported operation: _Namespace".\n\n'
                '**¿Cómo solucionarlo?**\n'
                '1. Abre el archivo en un editor de hojas de cálculo (como Microsoft Excel o Google Sheets).\n'
                '2. Ve a **"Guardar como"**.\n'
                '3. Asegúrate de seleccionar el formato **"Libro de Excel (*.xlsx)"** estándar (no "Strict Open XML" ni otros formatos).\n'
                '4. Guarda el archivo con un nuevo nombre e intenta importarlo de nuevo.\n\n'
                'Este paso usualmente corrige los problemas de compatibilidad de formato.',
          );
        } else {
          UiHelpers.showSnackBar(context, errorMessage, isError: true);
        }
      }
    }
  }

  Future<void> _importStudentsToFirebase() async {
    if (_parsedStudents.isEmpty) return;

    final confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Importación Masiva',
      content:
          '¿Importar ${_parsedStudents.length} alumnos al ciclo $_targetSchoolCycle?',
    );

    if (!confirmed) return;

    setState(() => _isImporting = true);

    try {
      // Guardar en el nodo del ciclo seleccionado
      final dbRef = FirebaseDatabase.instance
          .ref('planteles/${widget.campusId}/students/$_targetSchoolCycle');

      for (final student in _parsedStudents) {
        await dbRef.child(student.studentId).set(student.toFirebaseMap());
      }
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Importación completada exitosamente.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error en la importación.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
          title: const Text('Importar Alumnos'),
          elevation: 0,
          centerTitle: true),
      body: _isLoading || _isImporting || _isLoadingCycles || _isLoadingGroups
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // SELECTOR DE CICLO ESCOLAR
                          FadeInUp(
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color:
                                          Colors.grey.withValues(alpha: 0.2))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: DropdownButtonFormField<String>(
                                  value: _targetSchoolCycle,
                                  decoration: const InputDecoration(
                                    labelText: 'Ciclo Escolar de Destino',
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.calendar_month),
                                  ),
                                  items: _availableSchoolCycles
                                      .map((c) => DropdownMenuItem(
                                          value: c.id, child: Text(c.id)))
                                      .toList(),
                                  onChanged: (val) async { // Added async
                                    if (val != null) {
                                      setState(() {
                                        _targetSchoolCycle = val;
                                        _parsedStudents =
                                            []; // Limpiar previos si cambia el ciclo
                                        _filePath = null;
                                        _isLoadingGroups = true; // Set loading groups to true
                                      });
                                      await _loadAvailableGroups(val); // Await the group loading
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          FadeInUp(
                            delay: const Duration(milliseconds: 100),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    width: 2),
                              ),
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.05),
                              child: InkWell(
                                onTap: _pickExcelFile,
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      Icon(Icons.upload_file_rounded,
                                          size: 64,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(height: 16),
                                      Text('Seleccionar Excel',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Asegúrate de que los nombres de las hojas\ncoincidan con los grupos creados (ej. "101", "302")',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6))),
                                      if (_filePath != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16.0),
                                          child: Chip(
                                              label: Text(_filePath!)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_parsedStudents.isNotEmpty)
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          'Alumnos detectados: ${_parsedStudents.length}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextButton(
                                          onPressed: () => setState(
                                              () => _parsedStudents = []),
                                          child: const Text('Limpiar')),
                                    ],
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _parsedStudents.length,
                                      itemBuilder: (context, index) {
                                        final s = _parsedStudents[index];
                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                              title: Text(s.fullName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              subtitle: Text(
                                                  'ID: ${s.studentId} • Grupo: ${s.group}')),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _importStudentsToFirebase,
                                      icon:
                                          const Icon(Icons.cloud_done_outlined),
                                      label: const Text('Importar al Sistema'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
