import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart'; // Importar
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class IncidenceReportScreen extends StatefulWidget {
  const IncidenceReportScreen({super.key});

  @override
  State<IncidenceReportScreen> createState() => _IncidenceReportScreenState();
}

class _IncidenceReportScreenState extends State<IncidenceReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedType;
  final List<String> _incidenceTypes = [
    'Uniforme Incompleto',
    'Cabello/Corte no permitido',
    'Uso de Celular en Clase',
    'Falta de Respeto',
    'Daño a Mobiliario',
    'Salida sin Pase',
    'Otro'
  ];

  Student? _selectedStudent;
  List<Student> _allStudents = [];
  List<Incidence> _recentIncidents = [];
  bool _isLoading = false;
  String? _campus;
  String? _cycle;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (snap.exists) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          _campus = data['campus'];
        }
      }

      final appSettings = AppSettingsService(
        Provider.of<HiveService>(context, listen: false), 
        Provider.of<ConnectivityService>(context, listen: false) // Usar Provider
      );
      _cycle = await appSettings.getCurrentSchoolCycleId();

      if (_campus != null && _cycle != null) {
        await _loadStudents();
        _loadRecentIncidents();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_cycle');
    final snap = await ref.get();
    if (snap.exists) {
      final List<Student> loaded = [];
      for (var child in snap.children) {
        final s = Student.fromSnapshot(child);
        if (s.isActive) loaded.add(s);
      }
      setState(() => _allStudents = loaded);
    }
  }

  void _loadRecentIncidents() {
    if (_campus == null) return;
    // Cargar incidencias de hoy (Firebase o Hive logic simple)
    // Por simplicidad, escuchamos Firebase
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
    ref.limitToLast(20).onValue.listen((event) {
      if (mounted) {
        final List<Incidence> loaded = [];
        if (event.snapshot.exists) {
          for (var child in event.snapshot.children) {
            final data = Map<String, dynamic>.from(child.value as Map);
            loaded.add(Incidence.fromFirebaseMap(child.key!, data));
          }
        }
        setState(() => _recentIncidents = loaded.reversed.toList());
      }
    });
  }

  Future<void> _saveIncidence() async {
    if (_selectedStudent == null || _selectedType == null) {
      UiHelpers.showSnackBar(context, 'Selecciona alumno y tipo de incidencia', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newRef = FirebaseDatabase.instance.ref('planteles/$_campus/incidents').push();
      final incidence = Incidence(
        id: newRef.key!,
        studentId: _selectedStudent!.studentId,
        studentName: _selectedStudent!.fullName,
        group: _selectedStudent!.group,
        type: _selectedType!,
        description: _descriptionController.text.trim(),
        date: DateTime.now(),
        campusId: _campus!,
        isSynced: true,
      );

      await newRef.set(incidence.toFirebaseMap());
      
      _searchController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedStudent = null;
        _selectedType = null;
      });
      
      if (mounted) UiHelpers.showSnackBar(context, 'Incidencia registrada correctamente');

    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error guardando: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- FORMULARIO ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nueva Incidencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // BUSCADOR ALUMNO
                    Autocomplete<Student>(
                      displayStringForOption: (Student option) => '${option.fullName} (${option.group})',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Student>.empty();
                        return _allStudents.where((Student option) {
                          return option.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                 option.studentId.contains(textEditingValue.text);
                        });
                      },
                      onSelected: (Student selection) {
                        setState(() => _selectedStudent = selection);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: InputDecoration(
                            labelText: 'Buscar Alumno',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: _selectedStudent != null 
                              ? const Icon(Icons.check_circle, color: Colors.green) 
                              : null,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // TIPO
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Falta',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.warning_amber_rounded),
                      ),
                      items: _incidenceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedType = v),
                    ),

                    const SizedBox(height: 12),

                    // DESCRIPCION
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observaciones (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveIncidence,
                        icon: const Icon(Icons.save),
                        label: const Text('Registrar Incidencia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- HISTORIAL RECIENTE ---
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text('Últimos Reportes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recentIncidents.isEmpty 
                ? const Center(child: Text('Sin registros recientes'))
                : ListView.builder(
                    itemCount: _recentIncidents.length,
                    itemBuilder: (context, index) {
                      final inc = _recentIncidents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.warning, color: Colors.red),
                          ),
                          title: Text(inc.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${inc.type} • ${DateFormat('dd/MM HH:mm').format(inc.date)}'),
                          trailing: Text(inc.group, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
