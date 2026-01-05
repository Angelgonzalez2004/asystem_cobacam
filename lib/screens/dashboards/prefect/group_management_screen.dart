import 'dart:async'; // Necesario para StreamSubscription
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final DatabaseReference _groupsRef =
      FirebaseDatabase.instance.ref('groups');
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('school_cycles');

  // CORRECCIÓN 1: Variables para controlar las suscripciones
  StreamSubscription<DatabaseEvent>? _schoolCyclesSubscription;
  StreamSubscription<DatabaseEvent>? _groupsSubscription;

  List<Group> _groups = [];
  List<SchoolCycle> _schoolCycles = [];
  SchoolCycle? _selectedSchoolCycle;

  @override
  void initState() {
    super.initState();
    _loadSchoolCycles();
  }

  // CORRECCIÓN 2: Limpiar suscripciones al salir
  @override
  void dispose() {
    _schoolCyclesSubscription?.cancel();
    _groupsSubscription?.cancel();
    super.dispose();
  }

  void _loadSchoolCycles() {
    // Cancelamos suscripción anterior si existe
    _schoolCyclesSubscription?.cancel();

    _schoolCyclesSubscription = _schoolCyclesRef.onValue.listen((event) {
      // CORRECCIÓN 3: Verificar si el widget sigue vivo (mounted)
      if (!mounted) return;

      if (event.snapshot.exists) {
        final cycles = <SchoolCycle>[];
        for (final child in event.snapshot.children) {
          cycles.add(SchoolCycle.fromSnapshot(child));
        }
        
        setState(() {
          _schoolCycles = cycles;
          // Solo seleccionamos el primero si no hay uno ya seleccionado
          if (_schoolCycles.isNotEmpty && _selectedSchoolCycle == null) {
            _selectedSchoolCycle = _schoolCycles.first;
            _loadGroups();
          }
        });
      }
    });
  }

  void _loadGroups() {
    if (_selectedSchoolCycle == null) return;

    // Cancelamos la escucha anterior para no tener múltiples listeners activos
    _groupsSubscription?.cancel();

    _groupsSubscription = _groupsRef
        .orderByChild('schoolCycleId')
        .equalTo(_selectedSchoolCycle!.id)
        .onValue
        .listen((event) {
      
      // CORRECCIÓN 3: Verificar si el widget sigue vivo
      if (!mounted) return;

      if (event.snapshot.exists) {
        final groups = <Group>[];
        for (final child in event.snapshot.children) {
          groups.add(Group.fromSnapshot(child));
        }
        setState(() {
          _groups = groups;
        });
      } else {
        setState(() {
          _groups = [];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<SchoolCycle>(
              value: _selectedSchoolCycle,
              hint: const Text("Selecciona un ciclo"),
              isExpanded: true, // Para evitar errores de desbordamiento
              onChanged: (SchoolCycle? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedSchoolCycle = newValue;
                    _loadGroups();
                  });
                }
              },
              items: _schoolCycles
                  .map<DropdownMenuItem<SchoolCycle>>((SchoolCycle cycle) {
                return DropdownMenuItem<SchoolCycle>(
                  value: cycle,
                  child: Text(cycle.id),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _groups.isEmpty
                ? const Center(child: Text("No hay grupos para este ciclo"))
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(group.name),
                          subtitle: Text(
                              'Semestre: ${group.semester} - Alumnos: ${group.studentCount}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showGroupDialog(group: group),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteGroup(group.key),
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
    );
  }

  void _showGroupDialog({Group? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final semesterController =
        TextEditingController(text: group?.semester.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(group == null ? 'Nuevo Grupo' : 'Editar Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: semesterController,
                decoration: const InputDecoration(labelText: 'Semestre'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text;
                final semester = int.tryParse(semesterController.text) ?? 0;

                if (name.isEmpty || semester <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Por favor, complete todos los campos correctamente.'),
                      backgroundColor: Colors.orange));
                  return;
                }

                if (_selectedSchoolCycle == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Por favor, seleccione un ciclo escolar.'),
                      backgroundColor: Colors.orange));
                  return;
                }

                // --- VALIDATION LOGIC ---
                final String cycleType = _selectedSchoolCycle!.type;
                final bool isSemesterEven = semester % 2 == 0;
                final bool isSemesterOdd = !isSemesterEven;

                if (cycleType == 'A' && isSemesterOdd) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Error: En el ciclo A solo se pueden crear semestres pares (2, 4, 6).'),
                      backgroundColor: Colors.red));
                  return;
                }

                if (cycleType == 'B' && isSemesterEven) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Error: En el ciclo B solo se pueden crear semestres impares (1, 3, 5).'),
                      backgroundColor: Colors.red));
                  return;
                }

                if (cycleType == 'Propedéutico' && semester != 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Error: En el ciclo Propedéutico solo se pueden crear grupos de primer semestre.'),
                      backgroundColor: Colors.red));
                  return;
                }
                // --- END VALIDATION ---

                if (group == null) {
                  _createGroup(name, semester);
                } else {
                  _updateGroup(group.key, name, semester);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _createGroup(String name, int semester) {
    _groupsRef.push().set({
      'name': name,
      'semester': semester,
      'studentCount': 0,
      'schoolCycleId': _selectedSchoolCycle!.id,
    });
  }

  void _updateGroup(String key, String name, int semester) {
    _groupsRef.child(key).update({
      'name': name,
      'semester': semester,
    });
  }

  void _deleteGroup(String key) {
    _groupsRef.child(key).remove();
  }
}