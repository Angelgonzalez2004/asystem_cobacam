import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
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
  
  Incidence? _editingIncidence;

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
        Provider.of<ConnectivityService>(context, listen: false)
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

  void _prepareEdit(Incidence incidence) {
    setState(() {
      _editingIncidence = incidence;
      _selectedType = incidence.type;
      _descriptionController.text = incidence.description;
      
      try {
        _selectedStudent = _allStudents.firstWhere((s) => s.studentId == incidence.studentId);
        _searchController.text = _selectedStudent!.fullName; 
      } catch (e) {
        debugPrint('Alumno no encontrado en lista actual');
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIncidence = null;
      _selectedStudent = null;
      _selectedType = null;
      _searchController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _deleteIncidence(String id) async {
    try {
      await FirebaseDatabase.instance.ref('planteles/$_campus/incidents/$id').remove();
      if (mounted) UiHelpers.showSnackBar(context, 'Incidencia eliminada correctamente.', duration: const Duration(seconds: 3));
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al eliminar: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(Incidence incidence) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Incidencia'),
        content: Text('¿Estás seguro de eliminar el reporte de ${incidence.studentName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteIncidence(incidence.id);
    }
  }

  Future<void> _saveOrUpdateIncidence() async {
    if (_selectedStudent == null && _editingIncidence == null) {
       UiHelpers.showSnackBar(context, 'Selecciona un alumno.', isError: true);
       return;
    }
    if (_selectedType == null) {
      UiHelpers.showSnackBar(context, 'Selecciona el tipo de falta.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final DatabaseReference ref;
      String id;
      
      final studentId = _selectedStudent?.studentId ?? _editingIncidence!.studentId;
      final studentName = _selectedStudent?.fullName ?? _editingIncidence!.studentName;
      final group = _selectedStudent?.group ?? _editingIncidence!.group;

      if (_editingIncidence != null) {
        id = _editingIncidence!.id;
        ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents/$id');
      } else {
        ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents').push();
        id = ref.key!;
      }

      final incidence = Incidence(
        id: id,
        studentId: studentId,
        studentName: studentName,
        group: group,
        type: _selectedType!,
        description: _descriptionController.text.trim(),
        date: _editingIncidence?.date ?? DateTime.now(),
        campusId: _campus!,
        isSynced: true,
      );

      if (_editingIncidence != null) {
        await ref.update(incidence.toFirebaseMap());
        if (mounted) UiHelpers.showSnackBar(context, 'Incidencia actualizada.', duration: const Duration(seconds: 3));
      } else {
        await ref.set(incidence.toFirebaseMap());
        if (mounted) UiHelpers.showSnackBar(context, 'Incidencia registrada.', duration: const Duration(seconds: 3));
      }
      
      _cancelEdit();

    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error guardando: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Incidencias')), 
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_editingIncidence != null ? 'Editar Reporte' : 'Nueva Incidencia', 
                             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_editingIncidence != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: _cancelEdit,
                            tooltip: 'Cancelar Edición',
                          )
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // BUSCADOR ALUMNO
                    Autocomplete<Student>(
                      initialValue: _editingIncidence != null 
                          ? TextEditingValue(text: _editingIncidence!.studentName) 
                          : null,
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
                            labelText: 'Buscar Alumno (Nombre o Matrícula)',
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
                    Row(
                      children: [
                        if (_editingIncidence != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancelEdit,
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveOrUpdateIncidence,
                            icon: Icon(_editingIncidence != null ? Icons.update : Icons.save),
                            label: Text(_editingIncidence != null ? 'Actualizar' : 'Registrar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingIncidence != null ? Colors.orange : Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
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
                          title: Text(inc.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${inc.type} • ${DateFormat('dd/MM HH:mm').format(inc.date)}', style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _prepareEdit(inc),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _confirmDelete(inc),
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
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