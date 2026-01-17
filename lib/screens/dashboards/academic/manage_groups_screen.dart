import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
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

class _ManageGroupsScreenState extends State<ManageGroupsScreen>
    with SingleTickerProviderStateMixin {
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

      final userProfileSnapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) {
        throw Exception('El usuario no tiene un plantel asignado.');
      }

      _groupsRef = FirebaseDatabase.instance.ref('planteles/$campus/groups');
      _classroomsRef =
          FirebaseDatabase.instance.ref('planteles/$campus/classrooms');

      _groupsSubscription = _groupsRef!.onValue.listen((event) {
        final items =
            _extractData(event.snapshot, (snap) => Group.fromSnapshot(snap));
        setState(() => _groups = items);
      });

      _classroomsSubscription = _classroomsRef!.onValue.listen((event) {
        final items = _extractData(
            event.snapshot, (snap) => Classroom.fromSnapshot(snap));
        setState(() => _classrooms = items);
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UiHelpers.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  List<T> _extractData<T>(
      DataSnapshot snapshot, T Function(DataSnapshot) fromSnapshot) {
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

  // --- Dialogs and CRUD for Groups ---
  void _showGroupDialog({Group? group}) {
    final nameController = TextEditingController(text: group?.name);
    final semesterController =
        TextEditingController(text: group?.semester.toString());
    final countController =
        TextEditingController(text: group?.studentCount.toString());
    final isEditing = group != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Grupo' : 'Añadir Grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del Grupo (e.g., 101-A)')),
              const SizedBox(height: 12),
              TextField(
                  controller: semesterController,
                  decoration: const InputDecoration(labelText: 'Semestre'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(
                  controller: countController,
                  decoration:
                      const InputDecoration(labelText: 'Número de Alumnos'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'semester': int.tryParse(semesterController.text) ?? 0,
                  'studentCount': int.tryParse(countController.text) ?? 0,
                };
                if (data['name']!.toString().isNotEmpty && _groupsRef != null) {
                  try {
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      UiHelpers.showSnackBar(context,
                          isEditing ? 'Grupo actualizado.' : 'Grupo añadido.');
                    }
                  } catch (e) {
                    if (mounted) {
                      UiHelpers.showSnackBar(
                          context, 'Error al guardar: ${e.toString()}',
                          isError: true);
                    }
                  }
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
    final capacityController =
        TextEditingController(text: classroom?.capacity.toString());
    final isEditing = classroom != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Aula' : 'Añadir Aula'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del Aula (e.g., Aula 5)')),
              const SizedBox(height: 12),
              TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(labelText: 'Capacidad'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text,
                  'capacity': int.tryParse(capacityController.text) ?? 0,
                };
                if (data['name']!.toString().isNotEmpty &&
                    _classroomsRef != null) {
                  try {
                    if (isEditing) {
                      await _classroomsRef!.child(classroom.key).update(data);
                    } else {
                      await _classroomsRef!.push().set(data);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      UiHelpers.showSnackBar(context,
                          isEditing ? 'Aula actualizada.' : 'Aula añadida.');
                    }
                  } catch (e) {
                    if (mounted) {
                      UiHelpers.showSnackBar(
                          context, 'Error al guardar: ${e.toString()}',
                          isError: true);
                    }
                  }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Grupos y Aulas'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Grupos', icon: Icon(Icons.group_outlined)),
            Tab(text: 'Aulas', icon: Icon(Icons.class_outlined)),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupsRef == null
                      ? const Center(
                          child: Text(
                              'No se pudo cargar la información del plantel.'))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList<Group>(
                                _groups,
                                'No hay grupos registrados.',
                                (group, index) => FadeInUp(
                                      delay: Duration(milliseconds: 50 * index),
                                      child: Card(
                                        elevation: 0,
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          side: isDark
                                              ? BorderSide.none
                                              : BorderSide(
                                                  color: Colors.grey.shade200),
                                        ),
                                        color: isDark
                                            ? theme.cardTheme.color
                                            : Colors.white,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                          leading: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Icon(Icons.group,
                                                color: Colors.purple.shade600),
                                          ),
                                          title: Text(group.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              'Semestre: ${group.semester}  |  Alumnos: ${group.studentCount}',
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodyMedium?.color
                                                      ?.withValues(
                                                          alpha: 0.7))),
                                          trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.edit_outlined,
                                                        color: theme.colorScheme
                                                            .primary),
                                                    onPressed: () =>
                                                        _showGroupDialog(
                                                            group: group)),
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.delete_outline,
                                                        color: theme
                                                            .colorScheme.error),
                                                    onPressed: () async {
                                                      if (await UiHelpers
                                                          .showConfirmationDialog(
                                                              context,
                                                              title:
                                                                  'Eliminar Grupo',
                                                              content:
                                                                  '¿Seguro?',
                                                              isDestructive:
                                                                  true)) {
                                                        _groupsRef
                                                            ?.child(group.key)
                                                            .remove();
                                                        if (mounted) {
                                                          UiHelpers.showSnackBar(
                                                              context,
                                                              'Grupo eliminado.');
                                                        }
                                                      }
                                                    }),
                                              ]),
                                        ),
                                      ),
                                    )),
                            _buildList<Classroom>(
                                _classrooms,
                                'No hay aulas registradas.',
                                (classroom, index) => FadeInUp(
                                      delay: Duration(milliseconds: 50 * index),
                                      child: Card(
                                        elevation: 0,
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          side: isDark
                                              ? BorderSide.none
                                              : BorderSide(
                                                  color: Colors.grey.shade200),
                                        ),
                                        color: isDark
                                            ? theme.cardTheme.color
                                            : Colors.white,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                          leading: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Icon(Icons.meeting_room,
                                                color: Colors.teal.shade600),
                                          ),
                                          title: Text(classroom.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              'Capacidad: ${classroom.capacity} personas',
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodyMedium?.color
                                                      ?.withValues(
                                                          alpha: 0.7))),
                                          trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.edit_outlined,
                                                        color: theme.colorScheme
                                                            .primary),
                                                    onPressed: () =>
                                                        _showClassroomDialog(
                                                            classroom:
                                                                classroom)),
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.delete_outline,
                                                        color: theme
                                                            .colorScheme.error),
                                                    onPressed: () async {
                                                      if (await UiHelpers
                                                          .showConfirmationDialog(
                                                              context,
                                                              title:
                                                                  'Eliminar Aula',
                                                              content:
                                                                  '¿Seguro?',
                                                              isDestructive:
                                                                  true)) {
                                                        _classroomsRef
                                                            ?.child(
                                                                classroom.key)
                                                            .remove();
                                                        if (mounted) {
                                                          UiHelpers.showSnackBar(
                                                              context,
                                                              'Aula eliminada.');
                                                        }
                                                      }
                                                    }),
                                              ]),
                                        ),
                                      ),
                                    )),
                          ],
                        ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showGroupDialog();
          } else {
            _showClassroomDialog();
          }
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildList<T>(
      List<T> items, String noDataText, Widget Function(T, int) tileBuilder) {
    if (items.isEmpty) {
      return Center(child: Text(noDataText));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => tileBuilder(items[index], index),
    );
  }
}
