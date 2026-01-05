import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// Modelo de datos para un Maestro, adaptado para Firebase
class Teacher {
  String key; // Firebase key
  String name;
  List<String> subjects;

  Teacher({required this.key, required this.name, required this.subjects});

  factory Teacher.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final subjectsFromDb = data['subjects'];
    List<String> subjectsList = [];
    if (subjectsFromDb is List) {
      subjectsList = List<String>.from(subjectsFromDb);
    } else if (subjectsFromDb is String) {
      subjectsList = subjectsFromDb.split(',').map((s) => s.trim()).toList();
    }

    return Teacher(
      key: snapshot.key!,
      name: data['name'] ?? 'Sin Nombre',
      subjects: subjectsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'subjects': subjects,
      };
}

class ManageTeachersScreen extends StatefulWidget {
  const ManageTeachersScreen({super.key});

  @override
  State<ManageTeachersScreen> createState() => _ManageTeachersScreenState();
}

class _ManageTeachersScreenState extends State<ManageTeachersScreen> {
  DatabaseReference? _teachersRef;
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _streamSubscription;
  List<Teacher> _teachers = [];

  @override
  void initState() {
    super.initState();
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

      _teachersRef =
          FirebaseDatabase.instance.ref('planteles/$campus/teachers');

      _streamSubscription = _teachersRef!.onValue.listen((event) {
        if (!event.snapshot.exists) {
          setState(() {
            _teachers = [];
            _isLoading = false;
          });
          return;
        }
        final teachersList = event.snapshot.children
            .map((snapshot) => Teacher.fromSnapshot(snapshot))
            .toList();

        setState(() {
          _teachers = teachersList;
          _isLoading = false;
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        UiHelpers.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  void _showTeacherDialog({Teacher? teacher}) {
    final nameController = TextEditingController(text: teacher?.name);
    final subjectsController =
        TextEditingController(text: teacher?.subjects.join(', '));
    final isEditing = teacher != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Maestro' : 'Añadir Maestro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del Maestro')),
              const SizedBox(height: 12),
              TextField(
                  controller: subjectsController,
                  decoration: const InputDecoration(
                      labelText: 'Materias (separadas por coma)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final subjects = subjectsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .toList();

                if (name.isNotEmpty &&
                    subjects.isNotEmpty &&
                    _teachersRef != null) {
                  final teacherData = {'name': name, 'subjects': subjects};
                  try {
                    if (isEditing) {
                      await _teachersRef!.child(teacher.key).update(teacherData);
                    } else {
                      await _teachersRef!.push().set(teacherData);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      UiHelpers.showSnackBar(context, isEditing ? 'Maestro actualizado.' : 'Maestro añadido.');
                    }
                  } catch (e) {
                    if (mounted) {
                      UiHelpers.showSnackBar(context, 'Error al guardar: ${e.toString()}', isError: true);
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
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Maestros'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _teachersRef == null
                      ? const Center(
                          child: Text(
                              'No se pudo cargar la información del plantel.'))
                      : _buildTeacherList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _teachersRef != null ? () => _showTeacherDialog() : null,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTeacherList() {
    if (_teachers.isEmpty) {
      return const Center(child: Text('No hay maestros registrados.'));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teachers.length,
      itemBuilder: (context, index) {
        final teacher = _teachers[index];
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            elevation: 0,
            color: isDark ? theme.cardTheme.color : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isDark
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(teacher.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: teacher.subjects
                      .map((sub) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(sub,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.secondary)),
                          ))
                      .toList(),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: theme.colorScheme.primary),
                    onPressed: () => _showTeacherDialog(teacher: teacher),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    onPressed: () async {
                      final confirm = await UiHelpers.showConfirmationDialog(
                          context,
                          title: 'Eliminar Maestro',
                          content:
                              '¿Estás seguro de que deseas eliminar a este maestro?',
                          isDestructive: true);
                      if (confirm) {
                        _teachersRef!.child(teacher.key).remove();
                        if (mounted) {
                          UiHelpers.showSnackBar(context, 'Maestro eliminado.');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
