import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/incidence_excel_exporter.dart';
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
  // Controllers
  final TextEditingController _searchStudentController = TextEditingController(); // Para el autocomplete
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _historyFilterController = TextEditingController(); // Nuevo filtro historial

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
  List<Incidence> _allIncidents = []; // Lista completa descargada
  List<Incidence> _filteredIncidents = []; // Lista visual filtrada
  
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

      if (_campus != null) {
        await _loadStudents(); // Carga estudiantes del ciclo actual para el form
        _loadIncidentsHistory(); // Carga TODAS las incidencias para consulta
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_cycle == null) return;
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

  void _loadIncidentsHistory() {
    if (_campus == null) return;
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
    // Escuchar cambios en tiempo real
    ref.onValue.listen((event) {
      if (mounted) {
        final List<Incidence> loaded = [];
        if (event.snapshot.exists) {
          for (var child in event.snapshot.children) {
            final data = Map<String, dynamic>.from(child.value as Map);
            loaded.add(Incidence.fromFirebaseMap(child.key!, data));
          }
        }
        // Ordenar por fecha desc
        loaded.sort((a, b) => b.date.compareTo(a.date));
        
        setState(() {
          _allIncidents = loaded;
          _filterIncidents(); // Aplicar filtro actual
        });
      }
    });
  }

  void _filterIncidents() {
    final query = _historyFilterController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredIncidents = _allIncidents);
      return;
    }

    setState(() {
      _filteredIncidents = _allIncidents.where((i) {
        final dateStr = DateFormat('dd/MM/yyyy').format(i.date);
        return i.studentName.toLowerCase().contains(query) ||
               i.studentId.contains(query) ||
               dateStr.contains(query);
      }).toList();
    });
  }

  void _prepareEdit(Incidence incidence) {
    setState(() {
      _editingIncidence = incidence;
      _selectedType = incidence.type;
      _descriptionController.text = incidence.description;
      
      // Intentar pre-llenar el autocomplete
      // Nota: Si el alumno es de otro ciclo, puede que no esté en _allStudents, 
      // pero permitiremos editar la incidencia igual.
      try {
        _selectedStudent = _allStudents.firstWhere((s) => s.studentId == incidence.studentId);
      } catch (e) {
        // Alumno histórico no presente en ciclo actual, ok.
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIncidence = null;
      _selectedStudent = null;
      _selectedType = null;
      _searchStudentController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _deleteIncidence(String id) async {
    try {
      await FirebaseDatabase.instance.ref('planteles/$_campus/incidents/$id').remove();
      if (mounted) UiHelpers.showSnackBar(context, 'Reporte eliminado.', duration: const Duration(seconds: 3));
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al eliminar: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(Incidence incidence) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reporte'),
        content: Text('¿Seguro que deseas borrar la incidencia de ${incidence.studentName}? Esta acción no se puede deshacer.'),
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

  Future<void> _exportExcel() async {
    if (_filteredIncidents.isEmpty) {
      UiHelpers.showSnackBar(context, 'No hay datos para exportar.', isError: true);
      return;
    }
    
    UiHelpers.showSnackBar(context, 'Generando Excel...');
    try {
      final path = await IncidenceExcelExporter.exportToExcel(
        incidents: _filteredIncidents, 
        campus: _campus ?? 'COBACAM'
      );
      if (mounted && path != null) {
         UiHelpers.showSnackBar(context, 'Exportado exitosamente.', duration: const Duration(seconds: 3));
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error exportando: $e', isError: true);
    }
  }

  Future<void> _saveOrUpdateIncidence() async {
    // Validaciones
    if (_editingIncidence == null && _selectedStudent == null) {
       UiHelpers.showSnackBar(context, 'Debes buscar y seleccionar un alumno.', isError: true);
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
      
      // Si editamos, usamos datos existentes si no se seleccionó otro alumno nuevo
      final studentId = _selectedStudent?.studentId ?? _editingIncidence!.studentId;
      final studentName = _selectedStudent?.fullName ?? _editingIncidence!.studentName;
      final group = _selectedStudent?.group ?? _editingIncidence!.group;
      final cycle = _selectedStudent?.schoolCycle ?? _editingIncidence!.schoolCycle; // Importante: Ciclo

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
        schoolCycle: cycle, // Guardar ciclo
        type: _selectedType!,
        description: _descriptionController.text.trim(),
        date: _editingIncidence?.date ?? DateTime.now(),
        campusId: _campus!,
        isSynced: true,
      );

      if (_editingIncidence != null) {
        await ref.update(incidence.toFirebaseMap());
        if (mounted) UiHelpers.showSnackBar(context, 'Reporte actualizado correctamente.', duration: const Duration(seconds: 3));
      } else {
        await ref.set(incidence.toFirebaseMap());
        if (mounted) UiHelpers.showSnackBar(context, 'Reporte registrado exitosamente.', duration: const Duration(seconds: 3));
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Incidencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar a Excel',
            onPressed: _exportExcel,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- FORMULARIO DE REGISTRO ---
            if (_editingIncidence != null) 
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade100,
                child: Center(child: Text('EDITANDO REPORTE: ${_editingIncidence!.studentName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
              ),
              
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BUSCADOR ALUMNO (Autocomplete)
                    Autocomplete<Student>(
                      initialValue: _editingIncidence != null 
                          ? TextEditingValue(text: _editingIncidence!.studentName) 
                          : null,
                      displayStringForOption: (Student option) => '${option.fullName} (${option.group})',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Student>.empty();
                        return _allStudents.where((Student option) {
                          final input = textEditingValue.text.toLowerCase();
                          return option.fullName.toLowerCase().contains(input) ||
                                 option.studentId.contains(input);
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
                            labelText: 'Alumno (Nombre o Matrícula)',
                            prefixIcon: const Icon(Icons.person_search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: _selectedStudent != null 
                              ? const Icon(Icons.check_circle, color: Colors.green) 
                              : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Tipo de Falta',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _incidenceTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _selectedType = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveOrUpdateIncidence,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingIncidence != null ? Colors.orange : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_editingIncidence != null ? 'ACTUALIZAR' : 'AGREGAR'),
                          ),
                        ),
                        if (_editingIncidence != null) ...[
                           const SizedBox(width: 8),
                           IconButton.filledTonal(
                             icon: const Icon(Icons.close),
                             onPressed: _cancelEdit,
                             tooltip: 'Cancelar',
                           )
                        ]
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Detalles / Observaciones',
                        prefixIcon: const Icon(Icons.notes),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // --- BARRA DE FILTRO ---
            TextField(
              controller: _historyFilterController,
              decoration: InputDecoration(
                hintText: 'Buscar en historial (Fecha, Nombre, Matrícula)...',
                prefixIcon: const Icon(Icons.filter_list),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (_) => _filterIncidents(),
            ),
            
            const SizedBox(height: 12),
            
            // --- LISTA DE RESULTADOS ---
            Expanded(
              child: _filteredIncidents.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu, size: 60, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        Text('Sin registros encontrados', style: TextStyle(color: Colors.grey.withOpacity(0.5))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80), // Espacio para FAB si hubiera
                    itemCount: _filteredIncidents.length,
                    itemBuilder: (context, index) {
                      final inc = _filteredIncidents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade50,
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          ),
                          title: Text(inc.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${inc.type} • ${DateFormat('dd/MM/yyyy').format(inc.date)}', 
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                onPressed: () => _prepareEdit(inc),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(inc),
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow('Matrícula:', inc.studentId),
                                  _infoRow('Grupo:', inc.group),
                                  _infoRow('Ciclo Escolar:', inc.schoolCycle),
                                  const Divider(),
                                  const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(inc.description.isEmpty ? 'Sin detalles' : inc.description),
                                ],
                              ),
                            )
                          ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
