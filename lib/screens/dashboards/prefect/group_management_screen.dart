import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  DatabaseReference? _groupsRef;
  final DatabaseReference _schoolCyclesRef = FirebaseDatabase.instance.ref('school_cycles');

  StreamSubscription<DatabaseEvent>? _schoolCyclesSubscription;
  StreamSubscription<DatabaseEvent>? _groupsSubscription;

  List<Group> _groups = [];
  List<SchoolCycle> _schoolCycles = [];
  SchoolCycle? _selectedSchoolCycle;
  String? _campusId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (snap.exists) {
          final userData = Map<String, dynamic>.from(snap.value as Map);
          _campusId = userData['campus'];
          if (_campusId != null) {
            _groupsRef = FirebaseDatabase.instance.ref('planteles/$_campusId/groups');
          }
        }
      }
      _loadSchoolCycles();
    } catch (e) {
      debugPrint('Error en _initData: $e');
    }
  }

  void _loadSchoolCycles() {
    _schoolCyclesSubscription?.cancel();
    _schoolCyclesSubscription = _schoolCyclesRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final cycles = <SchoolCycle>[];
        for (final child in event.snapshot.children) {
          cycles.add(SchoolCycle.fromSnapshot(child));
        }
        setState(() {
          _schoolCycles = cycles;
          if (_schoolCycles.isNotEmpty && _selectedSchoolCycle == null) {
            _selectedSchoolCycle = _schoolCycles.first;
            _loadGroups();
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  void _loadGroups() {
    if (_selectedSchoolCycle == null || _groupsRef == null) return;
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!
        .orderByChild('schoolCycleId')
        .equalTo(_selectedSchoolCycle!.id)
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final groups = <Group>[];
        for (final child in event.snapshot.children) {
          groups.add(Group.fromSnapshot(child));
        }
        setState(() => _groups = groups);
      } else {
        setState(() => _groups = []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Gestión de Grupos'),
            if (_campusId != null) Text('Plantel: $_campusId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        elevation: 0,
        centerTitle: true,
      ),

      body: _isLoading 

        ? const Center(child: CircularProgressIndicator())

        : LayoutBuilder(builder: (context, constraints) {

            return Center(

              child: ConstrainedBox(

                constraints: const BoxConstraints(maxWidth: 800),

                child: Column(

                  children: [

                    Padding(

                      padding: const EdgeInsets.all(16.0),

                      child: Card(

                        elevation: 0,

                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),

                        child: Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 16),

                          child: DropdownButtonHideUnderline(

                            child: DropdownButton<SchoolCycle>(

                              value: _selectedSchoolCycle,

                              hint: const Text("Selecciona un ciclo"),

                              isExpanded: true,

                              onChanged: (newValue) {

                                if (newValue != null) {

                                  setState(() {

                                    _selectedSchoolCycle = newValue;

                                    _loadGroups();

                                  });

                                }

                              },

                              items: _schoolCycles.map((cycle) => DropdownMenuItem(value: cycle, child: Text('Ciclo: ${cycle.id} (${cycle.type})'))).toList(),

                            ),

                          ),

                        ),

                      ),

                    ),

                    Expanded(

                      child: _groups.isEmpty

                          ? Center(child: Text("No hay grupos para este ciclo en tu plantel", style: TextStyle(color: Colors.grey.shade500)))

                          : ListView.builder(

                              padding: const EdgeInsets.symmetric(horizontal: 16),

                              itemCount: _groups.length,

                              itemBuilder: (context, index) {

                                final group = _groups[index];

                                return FadeInUp(

                                  delay: Duration(milliseconds: 50 * index),

                                  child: Card(

                                    elevation: 0,

                                    margin: const EdgeInsets.only(bottom: 12),

                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade200)),

                                    color: isDark ? theme.cardTheme.color : Colors.white,

                                    child: ListTile(

                                      contentPadding: const EdgeInsets.all(16),

                                      leading: CircleAvatar(backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1), child: Icon(Icons.groups_outlined, color: theme.colorScheme.secondary)),

                                      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),

                                      subtitle: Text('Semestre: ${group.semester} • ${group.studentCount} Alumnos'),

                                      trailing: Row(

                                        mainAxisSize: MainAxisSize.min,

                                        children: [

                                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showGroupDialog(group: group)),

                                          IconButton(icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), onPressed: () => _confirmDelete(group)),

                                        ],

                                      ),

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

          }),

      floatingActionButton: FloatingActionButton(

        onPressed: () => _showGroupDialog(),

        backgroundColor: theme.colorScheme.primary,

        child: const Icon(Icons.add, color: Colors.white),

      ),

    );

  }



  Future<void> _confirmDelete(Group group) async {

    final confirm = await UiHelpers.showConfirmationDialog(context, title: 'Eliminar Grupo', content: '¿Estás seguro?', isDestructive: true);

    if (confirm && _groupsRef != null) {

      _groupsRef!.child(group.key).remove();

      if (mounted) UiHelpers.showSnackBar(context, 'Grupo eliminado.');

    }

  }



  void _showGroupDialog({Group? group}) {

    final nameController = TextEditingController(text: group?.name ?? '');

    final semesterController = TextEditingController(text: group?.semester.toString() ?? '');



    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: Text(group == null ? 'Nuevo Grupo' : 'Editar Grupo'),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre (ej. 201-A, 105-B)')),

              const SizedBox(height: 12),

              TextField(controller: semesterController, decoration: const InputDecoration(labelText: 'Semestre (1 al 6)'), keyboardType: TextInputType.number),

            ],

          ),

          actions: [

            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),

            ElevatedButton(

              onPressed: () {

                final name = nameController.text;

                final semester = int.tryParse(semesterController.text) ?? 0;

                

                if (name.isEmpty || semester <= 0 || _selectedSchoolCycle == null) {

                  UiHelpers.showSnackBar(context, 'Datos inválidos.', isError: true);

                  return;

                }



                // --- LÓGICA DE VALIDACIÓN COBACAM ---

                final String cycleType = _selectedSchoolCycle!.type;

                bool isValid = false;

                String errorMsg = '';



                if (cycleType == 'A') {

                  if (semester % 2 == 0) {
                    isValid = true;
                  } else {
                    errorMsg = 'Ciclo A solo permite semestres PARES (2, 4, 6).';
                  }

                } else if (cycleType == 'B') {

                  if (semester % 2 != 0) {
                    isValid = true;
                  } else {
                    errorMsg = 'Ciclo B solo permite semestres IMPARES (1, 3, 5).';
                  }

                } else if (cycleType == 'Propedéutico') {

                  if (semester == 1) {
                    isValid = true;
                  } else {
                    errorMsg = 'Cursos Propedéuticos solo permiten 1er semestre.';
                  }

                }



                if (!isValid) {

                  UiHelpers.showSnackBar(context, errorMsg, isError: true);

                  return;

                }



                if (group == null) {
                  _createGroup(name, semester);
                } else {
                  _updateGroup(group.key, name, semester);
                }

                Navigator.pop(context);

                UiHelpers.showSnackBar(context, 'Guardado correctamente.');

              },

              child: const Text('Guardar'),

            ),

          ],

        );

      },

    );

  }



  void _createGroup(String name, int semester) {

    if (_groupsRef == null) return;

    _groupsRef!.push().set({

      'name': name,

      'semester': semester,

      'studentCount': 0,

      'schoolCycleId': _selectedSchoolCycle!.id,

    });

  }



  void _updateGroup(String key, String name, int semester) {

    if (_groupsRef == null) return;

    _groupsRef!.child(key).update({'name': name, 'semester': semester});

  }

}
