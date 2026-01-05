import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:asystem_cobacam/models/group_model.dart'; // Import the new Group model

// --- Data Models ---
class Classroom {
  String key;
  String name;
  int capacity;

  Classroom({required this.key, required this.name, required this.capacity});

  factory Classroom.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Classroom(
      key: snapshot.key!,
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 0,
    );
  }
}

class ManageGroupsScreen extends StatefulWidget {
  const ManageGroupsScreen({super.key});

  @override
  State<ManageGroupsScreen> createState() => _ManageGroupsScreenState();
}

class _ManageGroupsScreenState extends State<ManageGroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DatabaseReference? _groupsRef;
  DatabaseReference? _classroomsRef;

  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  StreamSubscription<DatabaseEvent>? _classroomsSubscription;

  List<Group> _groups = [];
  List<Classroom> _classrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }
  
  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      _groupsRef = FirebaseDatabase.instance.ref('planteles/$campus/groups');
      _classroomsRef = FirebaseDatabase.instance.ref('planteles/$campus/classrooms');

      _groupsSubscription = _groupsRef!.onValue.listen((event) {
        final items = _extractData(event.snapshot, (snap) => Group.fromSnapshot(snap));
        setState(() => _groups = items);
      });

      _classroomsSubscription = _classroomsRef!.onValue.listen((event) {
         final items = _extractData(event.snapshot, (snap) => Classroom.fromSnapshot(snap));
        setState(() => _classrooms = items);
      });

      setState(() => _isLoading = false);

    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar(e.toString());
    }
  }

  List<T> _extractData<T>(DataSnapshot snapshot, T Function(DataSnapshot) fromSnapshot) {
    if (!snapshot.exists) return [];
    return snapshot.children.map((child) => fromSnapshot(child)).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupsSubscription?.cancel();
    _classroomsSubscription?.cancel();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // --- Dialogs and CRUD for Groups ---
  void _showGroupDialog({Group? group}) {
    final nameController = TextEditingController(text: group?.name);
    final semesterController = TextEditingController(text: group?.semester.toString());
    final countController = TextEditingController(text: group?.studentCount.toString());
    final isEditing = group != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Grupo' : 'Añadir Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del Grupo (e.g., 101-A)')),
              TextField(controller: semesterController, decoration: const InputDecoration(labelText: 'Semestre'), keyboardType: TextInputType.number),
              TextField(controller: countController, decoration: const InputDecoration(labelText: 'Número de Alumnos'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'semester': int.tryParse(semesterController.text) ?? 0,
                  'studentCount': int.tryParse(countController.text) ?? 0,
                };
                if (data['name']!.toString().isNotEmpty && _groupsRef != null) {
                  try {
                    if (isEditing) {
                      await _groupsRef!.child(group.key).update(data);
                    } else {
                      await _groupsRef!.push().set(data);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) { _showErrorSnackBar('Error al guardar: ${e.toString()}'); }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // --- Dialogs and CRUD for Classrooms ---
  void _showClassroomDialog({Classroom? classroom}) {
    final nameController = TextEditingController(text: classroom?.name);
    final capacityController = TextEditingController(text: classroom?.capacity.toString());
    final isEditing = classroom != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Aula' : 'Añadir Aula'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del Aula (e.g., Aula 5)')),
              TextField(controller: capacityController, decoration: const InputDecoration(labelText: 'Capacidad'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'capacity': int.tryParse(capacityController.text) ?? 0,
                };
                 if (data['name']!.toString().isNotEmpty && _classroomsRef != null) {
                  try {
                    if (isEditing) {
                      await _classroomsRef!.child(classroom.key).update(data);
                    } else {
                      await _classroomsRef!.push().set(data);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) { _showErrorSnackBar('Error al guardar: ${e.toString()}'); }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Grupos y Aulas'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Grupos', icon: Icon(Icons.group)),
            Tab(text: 'Aulas', icon: Icon(Icons.class_outlined)),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _groupsRef == null 
              ? const Center(child: Text('No se pudo cargar la información del plantel.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList<Group>(_groups, 'No hay grupos registrados.', (group) => ListTile(
                      title: Text('Grupo: ${group.name}'),
                      subtitle: Text('Semestre: ${group.semester}, Alumnos: ${group.studentCount}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _showGroupDialog(group: group)),
                        IconButton(icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), onPressed: () => _groupsRef?.child(group.key).remove()),
                      ]),
                    )),
                    _buildList<Classroom>(_classrooms, 'No hay aulas registradas.', (classroom) => ListTile(
                      title: Text(classroom.name),
                      subtitle: Text('Capacidad: ${classroom.capacity} personas'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _showClassroomDialog(classroom: classroom)),
                        IconButton(icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), onPressed: () => _classroomsRef?.child(classroom.key).remove()),
                      ]),
                    )),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showGroupDialog();
          } else {
            _showClassroomDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList<T>(List<T> items, String noDataText, Widget Function(T) tileBuilder) {
    if (items.isEmpty) {
      return Center(child: Text(noDataText));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => tileBuilder(items[index]),
    );
  }
}
