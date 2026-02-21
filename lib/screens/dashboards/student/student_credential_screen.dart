import 'dart:async';
import 'dart:io';

import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
// Asegúrate de que este import sea el correcto para tu widget de credencial.
// En tu código anterior lo llamabas CredentialCardContent, si da error, cámbialo por el nombre correcto.
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
  const StudentCredentialScreen({super.key});

  @override
  State<StudentCredentialScreen> createState() =>
      _StudentCredentialScreenState();
}

class _StudentCredentialScreenState extends State<StudentCredentialScreen> {
  // Services & Controllers
  late final AppSettingsService _appSettingsService;
  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  bool _isLoading = true;
  bool _isFetchingCredential = false;
  bool _isDownloading = false;
  String? _errorMessage;

  // User and Cycle Data
  String? _userId;
  String? _userMatricula;
  String? _userCampusId;
  List<SchoolCycle> _schoolCycles = [];
  Student? _credentialData;

  // Download Limit State
  int _downloadCount = 0;
  final int _maxDownloads = 3;

  // ---> CAMBIO AQUI: Definimos las dimensiones fijas EXACTAS del generador <---
  final double _fixedCredentialWidth = 1030.0;
  final double _fixedCredentialHeight = 666.0;

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No hay un usuario autenticado.");
      _userId = user.uid;

      final userProfileSnap =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnap.exists) throw Exception("No se encontró tu perfil de usuario.");

      final userProfile = Map<String, dynamic>.from(userProfileSnap.value as Map);
      _userMatricula = userProfile['studentId'];
      _userCampusId = userProfile['campus'];

      if (_userMatricula == null || _userCampusId == null) {
        throw Exception("Tu perfil no tiene una matrícula o plantel asignado.");
      }

      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      if (_schoolCycles.isEmpty) throw Exception("No se encontraron ciclos escolares.");

      await _fetchDownloadCount();

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
      setState(() {
        _downloadCount = snap.value as int;
      });
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
        setState(() {
          _credentialData = Student.fromMap(Map<String, dynamic>.from(credentialSnap.value as Map));
        });
      } else {
        setState(() {
          _errorMessage = "Tu matrícula no fue encontrada en el ciclo escolar $selectedCycle. Por favor, comunícate con la prefecta.";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error al buscar tu credencial: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isFetchingCredential = false);
    }
  }

  Future<void> _handleDownload() async {
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

    if (!confirmed || !mounted) {
      debugPrint('[_handleDownload] Descarga cancelada por el usuario.');
      return;
    }

    setState(() => _isDownloading = true);

    try {
      // Nota: pixelRatio: 1.0 es suficiente si ya estamos forzando un tamaño gigante de 1030x666.
      // Si usas 2.0, la imagen será de 2060x1332, quizás demasiado grande. Puedes probar con 1.0 o 2.0.
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 50),
        pixelRatio: 1.0, // Cambiado a 1.0 porque el tamaño base ya es muy grande.
      );

      if (imageBytes != null) {
        final fileName = '${_credentialData!.studentId}_credencial.png';
        if (kIsWeb) {
          debugPrint('[_handleDownload] Es Web. Intentando descargar con WebDownloader.');
          await WebDownloader.downloadFile(imageBytes, fileName, 'image/png');
          if (mounted) UiHelpers.showSnackBar(context, "¡Descarga iniciada! Revisa tus descargas.");
        } else {
          debugPrint('[_handleDownload] No es Web. Intentando guardar con FilePicker.');
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar Credencial',
            fileName: fileName,
            type: FileType.image,
            allowedExtensions: ['png', 'jpg'],
          );

          if (outputFile != null) {
            debugPrint('[_handleDownload] Archivo seleccionado: $outputFile');
            final file = File(outputFile);
            await file.writeAsBytes(imageBytes);
            if (mounted) UiHelpers.showSnackBar(context, "¡Credencial guardada en: $outputFile!");
          } else {
            debugPrint('[_handleDownload] Usuario canceló el diálogo de guardar.');
            if (mounted) UiHelpers.showSnackBar(context, "Descarga cancelada.", isError: false);
            return;
          }
        }

        final dbPath = 'user_private/$_userId/credential_downloads/$_currentYearMonth';
        final dbRef = FirebaseDatabase.instance.ref(dbPath);
        await dbRef.set(ServerValue.increment(1));
        debugPrint('[_handleDownload] Contador de descargas incrementado.');

        if (mounted) {
          setState(() => _downloadCount++);
        }
      } else {
        debugPrint('[_handleDownload] imageBytes es null. No se pudo capturar la imagen.');
        if (mounted) UiHelpers.showSnackBar(context, "Error: No se pudo capturar la imagen de la credencial.", isError: true);
      }
    } catch (e) {
      debugPrint('[_handleDownload] Error al guardar/descargar la imagen: $e');
      if (mounted) UiHelpers.showSnackBar(context, "Error al guardar la imagen: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
      debugPrint('[_handleDownload] Finalizado. _isDownloading = false.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCredentialUI(),
    );
  }

  Widget _buildCredentialUI() {
    final downloadsLeft = _maxDownloads - _downloadCount;
    final canDownload = downloadsLeft > 0;

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
              if (value != null) {
                _fetchCredential(value);
              }
            },
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 16), hintText: 'Seleccionar...'),
          ),
          const SizedBox(height: 24),

          // ---> CAMBIO IMPORTANTE AQUI <---
          // Se ha modificado la estructura dentro del Expanded para permitir Scroll
          // y mantener el tamaño original para el Screenshot.
          Expanded(
            child: _isFetchingCredential
                ? const Center(child: CircularProgressIndicator())
                : _credentialData != null
                    ? Center(
                        // Scroll Horizontal
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          // Scroll Vertical
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            // El Screenshot envuelve el contenido que tiene el tamaño forzado
                            child: Screenshot(
                              controller: _screenshotController,
                              child: _buildCredentialView(_credentialData!),
                            ),
                          ),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildFeedbackMessage(_errorMessage!, isError: true)
                        : _buildFeedbackMessage('Por favor, selecciona un ciclo escolar para ver tu credencial.', isError: false),
          ),
          // ---> FIN DEL CAMBIO IMPORTANTE <---

          const SizedBox(height: 16),
          if (_isDownloading)
            const Center(child: CircularProgressIndicator())
          else
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

  // ---> CAMBIO AQUI: Modificamos esta función para forzar el tamaño exacto <---
  Widget _buildCredentialView(Student student) {
    // Usamos un Container para forzar las dimensiones exactas (1030x666)
    // Esto asegura que el Screenshot capture el tamaño original y no el ajustado a la pantalla.
    return Container(
      width: _fixedCredentialWidth,
      height: _fixedCredentialHeight,
      // Opcional: Sombra para que se distinga el fondo
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      // NOTA: En tu código pegado usabas 'CredentialCardContent'.
      // Si tu widget real se llama 'CredentialCard', cámbialo aquí.
      child: CredentialCardContent(
        student: student,
        campus: _userCampusId ?? 'N/A',
        // Si tu widget CredentialCardContent acepta width y height, pásalos aquí también:
        // width: _fixedCredentialWidth,
        // height: _fixedCredentialHeight,
      ),
    );
  }

  Widget _buildFeedbackMessage(String message, {required bool isError}) {
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(isError ? Icons.error_outline : Icons.info_outline, color: isError ? Colors.red : Colors.blue, size: 50),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isError ? Colors.red : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}