import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/credential_pdf_generator.dart';
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

    return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- PANEL DE CONTROL ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardColor : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCycle,
                              decoration: _inputDeco('Ciclo', Icons.calendar_month),
                              items: _schoolCycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.id))).toList(),
                              onChanged: (val) => setState(() { _selectedCycle = val; _studentsToGenerate.clear(); }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // SELECTOR DE FORMATO
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Row(
                              children: [
                                _formatChip('PNG'),
                                _formatChip('JPG'),
                                _formatChip('PDF'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _studentIdController,
                        maxLines: 3, // Permite pegar múltiples líneas
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        decoration: _inputDeco('Matrícula(s) - Separa por espacio, coma o enter', Icons.badge_rounded).copyWith(
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add_circle, size: 32, color: Colors.blue), // Más prominente
                                  onPressed: () => _addStudentsByMatriculas(_studentIdController.text),
                                ),
                        ),
                        onSubmitted: _addStudentsByMatriculas,
                      ),
                    ],
                  ),
                ),

                // --- ACCIONES ---
                if (_studentsToGenerate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text('${_studentsToGenerate.length} Alumnos en lista', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _downloadAllCredentials,
                          icon: const Icon(Icons.download_for_offline),
                          label: Text('Descargar $_exportFormat'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),

                // --- LISTA ---
                Expanded(
                  child: _studentsToGenerate.isEmpty
                      ? const Center(child: Text('Lista vacía. Agrega una matrícula arriba.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _studentsToGenerate.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final student = _studentsToGenerate[index];
                            return Center(
                              child: Stack(
                                children: [
                                  _CredentialCardVisual(student: student, campus: _campus ?? ''),
                                  Positioned(
                                    top: 0, right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                                      onPressed: () => setState(() => _studentsToGenerate.removeAt(index)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
  }

  Widget _formatChip(String label) {
    bool isSelected = _exportFormat == label;
    return GestureDetector(
      onTap: () => setState(() => _exportFormat = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Container(width: 70, height: 85, color: Colors.grey.shade100, child: const Icon(Icons.person, size: 40, color: Colors.grey)),
                  const SizedBox(width: 15),
                                        Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student.fullName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)), maxLines: 2),
                                        const SizedBox(height: 4),
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