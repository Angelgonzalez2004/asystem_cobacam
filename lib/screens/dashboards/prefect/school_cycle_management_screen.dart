import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchoolCycleManagementScreen extends StatefulWidget {
  const SchoolCycleManagementScreen({super.key});

  @override
  _SchoolCycleManagementScreenState createState() =>
      _SchoolCycleManagementScreenState();
}

class _SchoolCycleManagementScreenState
    extends State<SchoolCycleManagementScreen> {
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('school_cycles');

  List<SchoolCycle> _schoolCycles = [];

  @override
  void initState() {
    super.initState();
    _loadSchoolCycles();
  }

  void _loadSchoolCycles() {
    _schoolCyclesRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final cycles = <SchoolCycle>[];
        for (final child in event.snapshot.children) {
          cycles.add(SchoolCycle.fromSnapshot(child));
        }
        setState(() {
          _schoolCycles = cycles;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSchoolCycleDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _schoolCycles.length,
        itemBuilder: (context, index) {
          final cycle = _schoolCycles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('${cycle.id} (Tipo: ${cycle.type})'),
              subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(cycle.startDate)} - ${DateFormat('dd/MM/yyyy').format(cycle.endDate)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showSchoolCycleDialog(cycle: cycle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteSchoolCycle(cycle.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSchoolCycleDialog({SchoolCycle? cycle}) {
    final idController = TextEditingController(text: cycle?.id ?? '');
    String? selectedType = cycle?.type;
    DateTime startDate = cycle?.startDate ?? DateTime.now();
    DateTime endDate = cycle?.endDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog state
          builder: (context, setState) {
            return AlertDialog(
              title: Text(cycle == null ? 'Nuevo Ciclo' : 'Editar Ciclo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'ID (ej. 2025-A)'),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo de Ciclo'),
                      items: ['A', 'B', 'Propedéutico']
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                           selectedType = value;
                        });
                      },
                      validator: (value) => value == null ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 20),
                    Text('Fecha de Inicio: ${DateFormat('dd/MM/yyyy').format(startDate)}'),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            startDate = pickedDate;
                          });
                        }
                      },
                      child: const Text('Seleccionar Fecha'),
                    ),
                    const SizedBox(height: 20),
                    Text('Fecha de Fin: ${DateFormat('dd/MM/yyyy').format(endDate)}'),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            endDate = pickedDate;
                          });
                        }
                      },
                      child: const Text('Seleccionar Fecha'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final id = idController.text;
                    if (id.isNotEmpty && selectedType != null) {
                      final newCycle = SchoolCycle(
                        id: id,
                        type: selectedType!,
                        startDate: startDate,
                        endDate: endDate,
                      );
                      if (cycle == null) {
                        _createSchoolCycle(newCycle);
                      } else {
                        _updateSchoolCycle(newCycle);
                      }
                      Navigator.of(context).pop();
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, complete todos los campos.'), backgroundColor: Colors.orange,));
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _createSchoolCycle(SchoolCycle cycle) {
    _schoolCyclesRef.child(cycle.id).set(cycle.toFirebaseMap());
  }

  void _updateSchoolCycle(SchoolCycle cycle) {
    _schoolCyclesRef.child(cycle.id).update(cycle.toFirebaseMap());
  }

  void _deleteSchoolCycle(String id) {
    _schoolCyclesRef.child(id).remove();
  }
}