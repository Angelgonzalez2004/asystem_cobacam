import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/credential_pdf_generator.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';

class CredentialGeneratorScreen extends StatefulWidget {
  const CredentialGeneratorScreen({super.key});

  @override
  State<CredentialGeneratorScreen> createState() =>
      _CredentialGeneratorScreenState();
}

class _CredentialGeneratorScreenState extends State<CredentialGeneratorScreen> {
  final TextEditingController _studentIdController = TextEditingController();

  late final AppSettingsService _appSettingsService;

  String? _selectedCycle;
  String? _selectedGroup;
  String? _campus;
  List<SchoolCycle> _schoolCycles = [];
  List<Group> _availableGroups = [];

  final List<Student> _studentsToGenerate = [];
  bool _isLoading = false;
  bool _isSearching = false;

  String _exportFormat = 'PNG';

  @override
  void initState() {
    super.initState();
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSnap =
            await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (userSnap.exists) {
          final userData = Map<String, dynamic>.from(userSnap.value as Map);
          _campus = userData['campus'];
        }
      }
      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      final current = await _appSettingsService.getCurrentSchoolCycleId();
      if (mounted) {
        setState(() => _selectedCycle = current);
        if (current.isNotEmpty) _loadGroupsForCycle(current);
      }
    } catch (e) {
      if (mounted)
        UiHelpers.showSnackBar(context, 'Error cargando datos: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupsForCycle(String cycleId) async {
    if (_campus == null) return;

    setState(() {
      _availableGroups = []; // Limpiar lista actual
      _selectedGroup = null; // Resetear selección
    });

    try {
      final ref = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
      final snap = await ref.get(); // Obtener todos los grupos del plantel

      final List<Group> groups = [];
      if (snap.exists) {
        for (var child in snap.children) {
          final g = Group.fromSnapshot(child);
          // Filtrar por ciclo usando Dart
          if (g.schoolCycleId == cycleId) {
            groups.add(g);
          }
        }
        groups.sort((a, b) => a.name.compareTo(b.name));
      }

      if (mounted) {
        setState(() {
          _availableGroups = groups;
        });
        if (groups.isEmpty) {
          debugPrint(
              'No se encontraron grupos para el ciclo $cycleId en $_campus');
        }
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted)
        UiHelpers.showSnackBar(context, 'Error al cargar grupos.',
            isError: true);
    }
  }

  Future<void> _loadStudentsFromGroup(String groupName) async {
    if (_campus == null || _selectedCycle == null) return;
    setState(() {
      _isSearching = true;
      _studentsToGenerate.clear(); // LIMPIAR LISTA PREVIA AL CAMBIAR DE GRUPO
    });

    try {
      final ref = FirebaseDatabase.instance
          .ref('planteles/$_campus/students/$_selectedCycle');
      final snap = await ref
          .get(); // Obtener todos los alumnos del ciclo (más fiable que query parcial)

      final List<Student> loaded = [];
      if (snap.exists) {
        for (var child in snap.children) {
          final s = Student.fromSnapshot(child);
          // Filtrar por grupo y estatus activo
          if (s.isActive && s.group == groupName) {
            loaded.add(s);
          }
        }
      }

      if (mounted) {
        setState(() {
          int added = 0;
          for (var s in loaded) {
            if (!_studentsToGenerate
                .any((existing) => existing.studentId == s.studentId)) {
              _studentsToGenerate.add(s);
              added++;
            }
          }
          UiHelpers.showSnackBar(context,
              'Se cargaron $added alumnos nuevos del grupo $groupName.');
        });
      }
    } catch (e) {
      if (mounted)
        UiHelpers.showSnackBar(context, 'Error cargando grupo: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addStudentsByMatriculas(String rawInput) async {
    if (_campus == null || _selectedCycle == null || rawInput.trim().isEmpty)
      return;

    final matriculas = rawInput
        .split(RegExp(r'[,\n\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (matriculas.isEmpty) return;

    setState(() => _isSearching = true);

    int addedCount = 0;
    int inactiveCount = 0;
    List<String> notFoundList = [];

    try {
      final ref = FirebaseDatabase.instance
          .ref('planteles/$_campus/students/$_selectedCycle');

      for (final matricula in matriculas) {
        if (_studentsToGenerate.any((s) => s.studentId == matricula)) {
          continue;
        }

        final snap = await ref.child(matricula).get();
        if (snap.exists) {
          final student = Student.fromSnapshot(snap);
          if (student.isActive) {
            setState(() => _studentsToGenerate.add(student));
            addedCount++;
          } else {
            inactiveCount++;
          }
        } else {
          notFoundList.add(matricula);
        }
      }

      if (mounted) {
        String message = '';
        if (addedCount > 0) {
          message = '✅ Se agregaron $addedCount alumno(s).';
          _studentIdController.clear();
        } else {
          message = '⚠️ No se agregaron alumnos nuevos.';
        }

        if (inactiveCount > 0) message += '\n🚫 $inactiveCount inactivos.';
        if (notFoundList.isNotEmpty) {
          message +=
              '\n❌ No encontrados: ${notFoundList.length} (${notFoundList.take(3).join(", ")}${notFoundList.length > 3 ? "..." : ""})';
        }

        UiHelpers.showSnackBar(context, message,
            isError: addedCount == 0 && notFoundList.isNotEmpty);
      }
    } catch (e) {
      if (mounted)
        UiHelpers.showSnackBar(context, 'Error procesando lote: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _downloadAllCredentials() async {
    if (_studentsToGenerate.isEmpty) return;

    if (mounted)
      UiHelpers.showSnackBar(context, 'Generando archivos $_exportFormat...');

    final Map<String, Uint8List> generatedImages = {};

    for (var i = 0; i < _studentsToGenerate.length; i++) {
      final student = _studentsToGenerate[i];
      final controller = ScreenshotController();

      Uint8List imageBytes = await controller.captureFromWidget(
        Material(
          child: Container(
            width: 350,
            height: 220,
            color: Colors.white,
            child: _CredentialCardContent(
                student: student, campus: _campus ?? 'COBACAM'),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );

      String extension = '.png';
      if (_exportFormat == 'JPG') {
        extension = '.jpg';
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          imageBytes =
              Uint8List.fromList(img.encodeJpg(decodedImage, quality: 90));
        }
      }

      final fileName =
          '${student.studentId}_${student.fullName.replaceAll(" ", "_")}$extension';
      generatedImages[fileName] = imageBytes;
    }

    if (_exportFormat == 'PDF') {
      try {
        final imagesList = generatedImages.values.toList();
        final pdfBytes = await CredentialPdfGenerator.generatePdf(imagesList);

        String groupSuffix =
            _selectedGroup != null ? '_Grupo_$_selectedGroup' : '';
        final fileName = 'Credenciales_$_selectedCycle$groupSuffix.pdf';

        if (kIsWeb) {
          await downloadImageWeb(pdfBytes, fileName);
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          if (mounted) UiHelpers.showSnackBar(context, 'PDF guardado.');
        }
      } catch (e) {
        if (mounted)
          UiHelpers.showSnackBar(context, 'Error creando PDF: $e',
              isError: true);
      }
    } else {
      if (generatedImages.length == 1) {
        final entry = generatedImages.entries.first;
        if (kIsWeb) {
          await downloadImageWeb(entry.value, entry.key);
        } else {
          await Gal.putImageBytes(entry.value, name: entry.key);
        }
      } else {
        final archive = Archive();
        generatedImages.forEach((name, bytes) {
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        });

        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        if (zipBytes != null) {
          String groupSuffix =
              _selectedGroup != null ? '_Grupo_$_selectedGroup' : '';
          final zipName = 'Credenciales_$_selectedCycle$groupSuffix.zip';

          if (kIsWeb) {
            await downloadImageWeb(Uint8List.fromList(zipBytes), zipName);
          } else {
            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/$zipName');
            await file.writeAsBytes(zipBytes);
            if (mounted) UiHelpers.showSnackBar(context, 'ZIP guardado.');
          }
        }
      }
    }

    if (mounted) UiHelpers.showSnackBar(context, '¡Proceso completado!');
  }

  Future<void> _downloadSingleCredential(Student student) async {
    if (mounted)
      UiHelpers.showSnackBar(
          context, 'Descargando credencial de ${student.fullName}...');

    final controller = ScreenshotController();
    Uint8List imageBytes = await controller.captureFromWidget(
      Material(
        child: Container(
          width: 350,
          height: 220,
          color: Colors.white,
          child: _CredentialCardContent(
              student: student, campus: _campus ?? 'COBACAM'),
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 3.0,
    );

    String extension = '.png';
    if (_exportFormat == 'JPG') {
      extension = '.jpg';
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        imageBytes =
            Uint8List.fromList(img.encodeJpg(decodedImage, quality: 90));
      }
    }

    final fileName =
        '${student.studentId}_${student.fullName.replaceAll(" ", "_")}$extension';

    if (kIsWeb) {
      await downloadImageWeb(imageBytes, fileName);
    } else {
      try {
        await Gal.putImageBytes(imageBytes, name: fileName);
        if (mounted) UiHelpers.showSnackBar(context, 'Guardado.');
      } catch (e) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(imageBytes);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor:
          isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.badge_outlined,
                                  color: theme.primaryColor, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Generador de Credenciales',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Text(
                                      'Procesamiento por lotes • $_exportFormat',
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: DropdownButtonFormField<String>(
                                value: _selectedCycle,
                                decoration: _inputDeco(
                                    'Ciclo Escolar', Icons.calendar_today),
                                items: _schoolCycles
                                    .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_month_outlined,
                                                size: 18,
                                                color: theme.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(c.id),
                                          ],
                                        )))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedCycle = val;
                                      _studentsToGenerate.clear();
                                      _selectedGroup = null;
                                      _availableGroups = [];
                                    });
                                    _loadGroupsForCycle(
                                        val); // Cargar nuevos grupos
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                                width: isWide ? 16 : 0,
                                height: isWide ? 0 : 16),
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                    'group_dropdown_${_selectedCycle}_${_availableGroups.length}'), // Key dinámico para refresco
                                value: _selectedGroup,
                                decoration:
                                    _inputDeco('Grupo', Icons.groups).copyWith(
                                  hintText: _availableGroups.isEmpty
                                      ? 'Sin grupos'
                                      : 'Elegir...',
                                ),
                                items: _availableGroups
                                    .map((g) => DropdownMenuItem(
                                          value: g.name,
                                          child: Text('Grupo ${g.name}'),
                                        ))
                                    .toList(),
                                onChanged: _availableGroups.isEmpty
                                    ? null
                                    : (val) {
                                        setState(() => _selectedGroup = val);
                                        if (val != null)
                                          _loadStudentsFromGroup(val);
                                      },
                              ),
                            ),
                            SizedBox(
                                width: isWide ? 16 : 0,
                                height: isWide ? 0 : 16),
                            Expanded(
                              flex: isWide ? 2 : 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black26
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: theme.dividerColor
                                            .withOpacity(0.1))),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _formatOption(context, 'PNG', Icons.image),
                                    _formatOption(context, 'JPG', Icons.photo),
                                    _formatOption(
                                        context, 'PDF', Icons.picture_as_pdf),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _studentIdController,
                          maxLines: 4,
                          minLines: 2,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: _inputDeco(
                                  'Ingresa matrículas (pegar lista)',
                                  Icons.playlist_add)
                              .copyWith(
                            hintText: 'Ejemplo:\n2025001\n2025002',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton.filled(
                                onPressed: _isSearching
                                    ? null
                                    : () => _addStudentsByMatriculas(
                                        _studentIdController.text),
                                icon: _isSearching
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Icon(Icons.arrow_forward_rounded),
                                style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.all(16)),
                              ),
                            ),
                          ),
                          onSubmitted: _addStudentsByMatriculas,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_studentsToGenerate.isNotEmpty) ...[
              FadeInUp(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${_studentsToGenerate.length} Credenciales Listas',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _downloadAllCredentials,
                      icon: const Icon(Icons.download_rounded),
                      label: Text('DESCARGAR PACK ($_exportFormat)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: _studentsToGenerate.asMap().entries.map((entry) {
                    final index = entry.key;
                    final student = entry.value;
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _CredentialCardVisual(
                              student: student, campus: _campus ?? ''),
                          Positioned(
                            top: -10,
                            right: -10,
                            child: IconButton.filled(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(
                                  () => _studentsToGenerate.removeAt(index)),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                              tooltip: 'Quitar de la lista',
                            ),
                          ),
                          Positioned(
                            top: -10,
                            left: -10,
                            child: IconButton.filled(
                              icon:
                                  const Icon(Icons.download_rounded, size: 18),
                              onPressed: () =>
                                  _downloadSingleCredential(student),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white),
                              tooltip: 'Descargar solo esta',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 100),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    children: [
                      Icon(Icons.style_outlined,
                          size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      const Text('La lista de generación está vacía',
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _formatOption(BuildContext context, String label, IconData icon) {
    bool isSelected = _exportFormat == label;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _exportFormat = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 24), child: Icon(icon)),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(20),
    );
  }
}

class _CredentialCardVisual extends StatelessWidget {
  final Student student;
  final String campus;
  const _CredentialCardVisual({required this.student, required this.campus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: _CredentialCardContent(student: student, campus: campus),
    );
  }
}

class _CredentialCardContent extends StatelessWidget {
  final Student student;
  final String campus;
  const _CredentialCardContent({required this.student, required this.campus});

  @override
  Widget build(BuildContext context) {
    // Colores Institucionales Profesionales
    const primaryColor = Color(0xFF1B396A); // Azul Marino Institucional
    const accentColor = Color(0xFFD4AF37); // Dorado Metálico
    const bgColor = Color(0xFFF8F9FA); // Blanco Humo

    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        // Sutil patrón de fondo o marca de agua (opcional)
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Stack(
        children: [
          // --- FONDO DECORATIVO ---
          Positioned(
            bottom: -50,
            right: -50,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset('assets/images/logo1.png',
                  width: 250, height: 250),
            ),
          ),

          Column(
            children: [
              // --- HEADER ---
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: ClipOval(
                          child: Image.asset('assets/images/logo1.png',
                              width: 36, height: 36)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 8.5),
                            maxLines: 1,
                          ),
                          SizedBox(height: 1),
                          Text(
                            'CREDENCIAL PARA ASISTENCIAS',
                            style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- CINTA DORADA SEPARADORA ---
              Container(height: 4, width: double.infinity, color: accentColor),

              // --- CUERPO ---
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // COLUMNA IZQUIERDA: FOTO
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 95,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              border: Border.all(color: primaryColor, width: 2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Icon(
                                (student.gender.toUpperCase().startsWith('F') ||
                                        student.gender
                                            .toUpperCase()
                                            .contains('MUJER'))
                                    ? Icons.woman
                                    : Icons.man,
                                size: 60,
                                color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 6),
                          Text(student.schoolCycle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: primaryColor)),
                          const Text('VIGENCIA',
                              style:
                                  TextStyle(fontSize: 6, color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(width: 14),

                      // COLUMNA DERECHA: DATOS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // NOMBRE DEL ALUMNO
                            Text(
                              student.fullName.toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                (student.gender.toUpperCase().startsWith('F') ||
                                        student.gender
                                            .toUpperCase()
                                            .contains('MUJER'))
                                    ? 'ALUMNA'
                                    : 'ALUMNO',
                                style: const TextStyle(
                                    fontSize: 7,
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),

                            const SizedBox(height: 8),

                            // GRID DE DATOS
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dataField('MATRÍCULA', student.studentId,
                                    primaryColor,
                                    isLarge: true),
                                const SizedBox(width: 12),
                                _dataField(
                                    'GRUPO', student.group, Colors.black87),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _dataField('NSS', student.nss ?? 'N/A',
                                    Colors.black54),
                                const SizedBox(width: 12),
                                _dataField('PLANTEL', campus, Colors.black54),
                              ],
                            ),

                            const Spacer(),

                            // CÓDIGO DE BARRAS
                            SizedBox(
                              width: double.infinity,
                              height: 28,
                              child: BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: student.studentId,
                                drawText: false,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- FOOTER ---
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataField(String label, String value, Color color,
      {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 6, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(
          value.toUpperCase(),
          style: TextStyle(
              fontSize: isLarge ? 12 : 9,
              fontWeight: FontWeight.bold,
              color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
