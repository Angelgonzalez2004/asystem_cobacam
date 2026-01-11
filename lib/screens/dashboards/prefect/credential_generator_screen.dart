import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/credential_pdf_generator.dart';
import 'package:asystem_cobacam/utils/animations.dart'; // Importar animaciones
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart'; // Para guardar en galería
import 'package:path_provider/path_provider.dart'; // Para guardar temporalmente
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:provider/provider.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:image/image.dart' as img; // Para conversión JPG

class CredentialGeneratorScreen extends StatefulWidget {
  const CredentialGeneratorScreen({super.key});

  @override
  State<CredentialGeneratorScreen> createState() => _CredentialGeneratorScreenState();
}

class _CredentialGeneratorScreenState extends State<CredentialGeneratorScreen> {
  final TextEditingController _studentIdController = TextEditingController();
  
  late final AppSettingsService _appSettingsService;
  
  String? _selectedCycle;
  String? _campus;
  List<SchoolCycle> _schoolCycles = [];
  
  // Lista de alumnos agregados para generar credencial
  final List<Student> _studentsToGenerate = [];
  bool _isLoading = false;
  bool _isSearching = false;

  // Formato de descarga
  String _exportFormat = 'PNG'; // Default

  @override
  void initState() {
    super.initState();
    final hiveService = Provider.of<HiveService>(context, listen: false);
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(hiveService, connectivityService);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (userSnap.exists) {
          final userData = Map<String, dynamic>.from(userSnap.value as Map);
          _campus = userData['campus'];
        }
      }
      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      _selectedCycle = await _appSettingsService.getCurrentSchoolCycleId();
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error cargando datos: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addStudentsByMatriculas(String rawInput) async {
    if (_campus == null || _selectedCycle == null || rawInput.trim().isEmpty) return;

    // Normalizar entrada: separar por comas, saltos de línea o espacios
    final matriculas = rawInput
        .split(RegExp(r'[,\n\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet() // Eliminar duplicados en la entrada actual
        .toList();

    if (matriculas.isEmpty) return;

    setState(() => _isSearching = true);
    
    int addedCount = 0;
    int inactiveCount = 0;
    List<String> notFoundList = [];

    try {
      final ref = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_selectedCycle');
      
      // Procesar cada matrícula
      for (final matricula in matriculas) {
        // Verificar si ya está en la lista visual
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
          _studentIdController.clear(); // Limpiar solo si hubo éxito
        } else {
          message = '⚠️ No se agregaron alumnos nuevos.';
        }

        if (inactiveCount > 0) message += '\n🚫 $inactiveCount inactivos.';
        if (notFoundList.isNotEmpty) {
           message += '\n❌ No encontrados: ${notFoundList.length} (${notFoundList.take(3).join(", ")}${notFoundList.length > 3 ? "..." : ""})';
        }

        UiHelpers.showSnackBar(
          context, 
          message, 
          isError: addedCount == 0 && notFoundList.isNotEmpty,
          duration: const Duration(seconds: 4)
        );
      }

    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error procesando lote: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _downloadAllCredentials() async {
    if (_studentsToGenerate.isEmpty) return;

    if (mounted) UiHelpers.showSnackBar(context, 'Generando archivos $_exportFormat...');

    // Lista temporal para PDF
    final List<Uint8List> pdfImages = [];

    for (var i = 0; i < _studentsToGenerate.length; i++) {
      final student = _studentsToGenerate[i];
      final controller = ScreenshotController();

      // 1. Capturar como PNG (default de la librería)
      Uint8List imageBytes = await controller.captureFromWidget(
        Material(
          child: Container(
            width: 350,
            height: 220,
            color: Colors.white,
            child: _CredentialCardContent(student: student, campus: _campus ?? 'COBACAM'),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );

      // --- CASO PDF ---
      if (_exportFormat == 'PDF') {
        pdfImages.add(imageBytes);
        continue; // Saltar guardado individual
      }

      // --- CASO IMAGEN INDIVIDUAL (JPG/PNG) ---
      String extension = '.png';
      if (_exportFormat == 'JPG') {
        extension = '.jpg';
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          imageBytes = Uint8List.fromList(img.encodeJpg(decodedImage, quality: 90));
        }
      }

      final fileName = 'credencial_${student.studentId}_$_selectedCycle$extension';
      
      if (kIsWeb) {
        await downloadImageWeb(imageBytes, fileName);
      } else {
        try {
          await Gal.putImageBytes(imageBytes, name: fileName);
        } catch (e) {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
             final dir = await getApplicationDocumentsDirectory();
             final file = File('${dir.path}/$fileName');
             await file.writeAsBytes(imageBytes);
          }
        }
      }
    } // Fin del loop

    // --- GENERAR PDF FINAL ---
    if (_exportFormat == 'PDF' && pdfImages.isNotEmpty) {
      try {
        final pdfBytes = await CredentialPdfGenerator.generatePdf(pdfImages);
        final fileName = 'credenciales_lote_${DateTime.now().millisecondsSinceEpoch}.pdf';

        if (kIsWeb) {
          await downloadImageWeb(pdfBytes, fileName);
        } else {
          // Guardar archivo localmente (Windows/Android/iOS via File)
          // Nota: En móviles sería ideal share_plus o open_file, pero guardaremos en Docs por ahora.
           final dir = await getApplicationDocumentsDirectory();
           final file = File('${dir.path}/$fileName');
           await file.writeAsBytes(pdfBytes);
           if (mounted) UiHelpers.showSnackBar(context, 'PDF guardado en: ${file.path}', isError: false);
        }
      } catch (e) {
        if (mounted) UiHelpers.showSnackBar(context, 'Error creando PDF: $e', isError: true);
        return;
      }
    }
    
    if (mounted) {
      UiHelpers.showSnackBar(context, '¡Proceso completado con éxito!', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold( // Usar Scaffold interno para mejor estructura
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- HEADER & CONTROL PANEL ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.badge_outlined, color: theme.primaryColor, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Generador de Credenciales', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  Text('Procesamiento por lotes • $_exportFormat', style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // CONTROLES RESPONSIVOS
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CICLO
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: DropdownButtonFormField<String>(
                                value: _selectedCycle,
                                decoration: _inputDeco('Ciclo Escolar', Icons.calendar_today),
                                items: _schoolCycles.map((c) => DropdownMenuItem(
                                  value: c.id, 
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_outlined, size: 18, color: theme.primaryColor),
                                      const SizedBox(width: 8),
                                      Text(c.id),
                                    ],
                                  )
                                )).toList(),
                                onChanged: (val) => setState(() { _selectedCycle = val; _studentsToGenerate.clear(); }),
                              ),
                            ),
                            SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                            
                            // FORMATO
                            Expanded(
                              flex: isWide ? 2 : 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _formatOption('PNG', Icons.image),
                                    _formatOption('JPG', Icons.photo),
                                    _formatOption('PDF', Icons.picture_as_pdf),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // INPUT AREA
                        TextField(
                          controller: _studentIdController,
                          maxLines: 4,
                          minLines: 2,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: _inputDeco('Ingresa matrículas (pegar lista)', Icons.playlist_add).copyWith(
                            hintText: 'Ejemplo:\n2025001\n2025002',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton.filled(
                                onPressed: _isSearching ? null : () => _addStudentsByMatriculas(_studentIdController.text),
                                icon: _isSearching 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : const Icon(Icons.arrow_forward_rounded),
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(16)
                                ),
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

            // --- RESULTADOS ---
            if (_studentsToGenerate.isNotEmpty) ...[
              FadeInUp(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${_studentsToGenerate.length} Credenciales Listas',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _downloadAllCredentials,
                      icon: const Icon(Icons.download_rounded),
                      label: Text('DESCARGAR $_exportFormat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // GRID DE CREDENCIALES
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
                          _CredentialCardVisual(student: student, campus: _campus ?? ''),
                          Positioned(
                            top: -10, right: -10,
                            child: IconButton.filled(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _studentsToGenerate.removeAt(index)),
                              style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                      Icon(Icons.style_outlined, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      const Text('La lista de generación está vacía', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _formatOption(String label, IconData icon) {
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
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 24), child: Icon(icon)), // Ajuste para multiline
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(20),
    );
  }
}

// ... (Resto de clases _CredentialCardVisual y _CredentialCardContent sin cambios en lógica interna)

class _CredentialCardVisual extends StatelessWidget {
  final Student student;
  final String campus;
  const _CredentialCardVisual({required this.student, required this.campus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350, height: 220,
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
    return Stack(
      children: [
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(height: 60, decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          )),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Image.asset('assets/images/logo1.png', width: 40, height: 40),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COBACAM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('CREDENCIAL ESTUDIANTIL', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  )),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Container(
                    width: 70, 
                    height: 85, 
                    color: Colors.grey.shade100, 
                    child: Icon(
                      (student.gender.toUpperCase().startsWith('H') || (student.gender.toUpperCase().startsWith('M') && !student.gender.toUpperCase().contains('UJE')))
                          ? Icons.man 
                          : Icons.woman, 
                      size: 50, 
                      color: Colors.grey
                    )
                  ),
                  const SizedBox(width: 15),
                                        Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student.fullName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)), maxLines: 2),
                                        const SizedBox(height: 4),
                                        Text('NSS: ${student.nss ?? 'SIN REGISTRO'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                        Text('GÉNERO: ${student.gender.toUpperCase()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                                        Text('MATRÍCULA: ${student.studentId}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                        Text('GRUPO: ${student.group}', style: const TextStyle(fontSize: 10)),
                                        Text('CICLO: ${student.schoolCycle}', style: const TextStyle(fontSize: 10)),
                                        Text('PLANTEL: $campus', style: const TextStyle(fontSize: 9), maxLines: 1),
                                      ],
                                    )),                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity, height: 50, color: Colors.grey.shade50,
              child: Center(child: BarcodeWidget(barcode: Barcode.code128(), data: student.studentId, width: 180, height: 30, drawText: false)),
            ),
          ],
        ),
      ],
    );
  }
}