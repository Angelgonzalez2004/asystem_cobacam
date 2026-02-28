import 'dart:async';
import 'dart:io';

import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:asystem_cobacam/widgets/credential_card_widget.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_picker/file_picker.dart';

class StudentCredentialScreen extends StatefulWidget {
  final Student? student;
  final String? campusId; // NEW: To receive campus context
  const StudentCredentialScreen({super.key, this.student, this.campusId});

  @override
  State<StudentCredentialScreen> createState() =>
      _StudentCredentialScreenState();
}

class _StudentCredentialScreenState extends State<StudentCredentialScreen> {
  late final AppSettingsService _appSettingsService;
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isLoading = true;
  bool _isFetchingCredential = false;
  bool _isDownloading = false;
  String? _errorMessage;

  String? _userId;
  String? _userMatricula;
  String? _userCampusId;
  List<SchoolCycle> _schoolCycles = [];
  Student? _credentialData;

  int _downloadCount = 0;
  final int _maxDownloads = 3;

  bool get isViewerMode => widget.student != null;

  @override
  void initState() {
    super.initState();
    _appSettingsService = AppSettingsService(
      Provider.of<HiveService>(context, listen: false),
      Provider.of<ConnectivityService>(context, listen: false),
    );
    _loadInitialData();
  }

  String get _currentYearMonth => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (isViewerMode) {
        // Tutor is viewing. Use the passed student data and campusId.
        _credentialData = widget.student;
        _userMatricula = widget.student!.studentId;
        _userCampusId = widget.campusId; // Use passed campusId
        
        if (_userCampusId == null) {
          throw Exception("No se proporcionó el plantel para la visualización.");
        }
        
        // Fetch school cycles for the tutor too
        _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      } else {
        // Student is viewing their own credential. Fetch their data.
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("No hay un usuario autenticado.");
        _userId = user.uid;

        final userProfileSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (!userProfileSnap.exists) throw Exception("No se encontró tu perfil de usuario.");
        
        final userProfile = Map<String, dynamic>.from(userProfileSnap.value as Map);
        _userMatricula = userProfile['studentId'];
        _userCampusId = userProfile['campus'];

        if (_userMatricula == null || _userCampusId == null) {
          throw Exception("Tu perfil no tiene una matrícula o plantel asignado.");
        }

        _schoolCycles = await _appSettingsService.getAllSchoolCycles();
        
        await _fetchDownloadCount();
      }

      if (_schoolCycles.isEmpty) throw Exception("No se encontraron ciclos escolares registrados.");
      
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDownloadCount() async {
    if (_userId == null) return;
    final dbPath = 'user_private/$_userId/credential_downloads/$_currentYearMonth';
    final snap = await FirebaseDatabase.instance.ref(dbPath).get();
    if (mounted && snap.exists) {
      setState(() => _downloadCount = snap.value as int);
    }
  }

  Future<void> _fetchCredential(String selectedCycle) async {
    if (_userMatricula == null || _userCampusId == null) return;

    setState(() {
      _isFetchingCredential = true;
      _credentialData = null;
      _errorMessage = null;
    });

    try {
      final dbPath = 'planteles/$_userCampusId/students/$selectedCycle/$_userMatricula';
      final credentialSnap = await FirebaseDatabase.instance.ref(dbPath).get();

      if (credentialSnap.exists) {
        final studentData = Student.fromMap(Map<String, dynamic>.from(credentialSnap.value as Map));
        if (studentData.studentId.isNotEmpty && studentData.fullName.isNotEmpty) {
          setState(() => _credentialData = studentData);
        } else {
          setState(() => _errorMessage = "Los datos para el ciclo escolar $selectedCycle están incompletos.");
        }
      } else {
        setState(() => _errorMessage = "No se encontró registro para la matrícula $_userMatricula en el ciclo escolar $selectedCycle.");
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error al buscar la credencial: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isFetchingCredential = false);
    }
  }

  Future<void> _handleDownload() async {
    // Download is disabled for tutors viewing a credential.
    if (isViewerMode) return;

    debugPrint('[_handleDownload] Descarga iniciada.');
    if (_downloadCount >= _maxDownloads) {
      UiHelpers.showAlertDialog(context, title: "Límite Alcanzado", content: "Has alcanzado tu límite de $_maxDownloads descargas para este mes.");
      return;
    }

    final remaining = _maxDownloads - _downloadCount;
    final confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Confirmar Descarga',
      content: "Te quedan $remaining descargas este mes. ¿Deseas usar una ahora?",
      confirmText: "Sí, descargar",
    );

    if (!confirmed || !mounted) return;

    setState(() => _isDownloading = true);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);

      if (imageBytes != null) {
        final fileName = '${_credentialData!.studentId}_credencial.png';
        if (kIsWeb) {
          await WebDownloader.downloadFile(imageBytes, fileName, 'image/png');
        } else {
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar Credencial',
            fileName: fileName,
            type: FileType.image,
            allowedExtensions: ['png'],
          );

          if (outputFile != null) {
            await File(outputFile).writeAsBytes(imageBytes);
            if (mounted) UiHelpers.showSnackBar(context, "¡Credencial guardada!");
          } else {
            if (mounted) UiHelpers.showSnackBar(context, "Descarga cancelada.");
            return;
          }
        }

        final dbPath = 'user_private/$_userId/credential_downloads/$_currentYearMonth';
        final dbRef = FirebaseDatabase.instance.ref(dbPath);
        await dbRef.set(ServerValue.increment(1));
        
        if (mounted) setState(() => _downloadCount++);
      } else {
        throw Exception("No se pudo capturar la imagen.");
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, "Error al guardar la imagen: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final downloadsLeft = _maxDownloads - _downloadCount;
    final canDownload = downloadsLeft > 0 && !isViewerMode;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('1. Selecciona un Ciclo Escolar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            items: _schoolCycles.map((cycle) => DropdownMenuItem(value: cycle.id, child: Text(cycle.id))).toList(),
            onChanged: (value) {
              if (value != null) _fetchCredential(value);
            },
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 16), hintText: 'Seleccionar...'),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: _isFetchingCredential
                ? const Center(child: CircularProgressIndicator())
                : _credentialData != null
                    ? Center(
                        child: Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            width: 350,
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                            ),
                            child: CredentialCardContent(
                              student: _credentialData!,
                              campus: _userCampusId ?? 'N/A',
                            ),
                          ),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildFeedbackMessage(_errorMessage!, isError: true)
                        : _buildFeedbackMessage(
                            'Por favor, selecciona un ciclo escolar para ver tu credencial.',
                            isError: false,
                          ),
          ),

          const SizedBox(height: 16),
          if (_isDownloading)
            const Center(child: CircularProgressIndicator())
          else if (!isViewerMode)
            ElevatedButton.icon(
              onPressed: _credentialData != null && canDownload ? _handleDownload : null,
              icon: const Icon(Icons.download),
              label: Text(canDownload ? 'Descargar (Te quedan $downloadsLeft)' : 'Límite de descargas alcanzado'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: canDownload ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackMessage(String message, {required bool isError}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline, color: isError ? Colors.red : Colors.blue, size: 50),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isError ? Colors.red : Colors.black87)),
          ],
        ),
      ),
    );
  }
}