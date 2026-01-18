import 'dart:async';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ManageCycleTeachersScreen extends StatefulWidget {
  final String campusId;
  final String schoolCycleId;

  const ManageCycleTeachersScreen({
    super.key,
    required this.campusId,
    required this.schoolCycleId,
  });

  @override
  State<ManageCycleTeachersScreen> createState() =>
      _ManageCycleTeachersScreenState();
}

class _ManageCycleTeachersScreenState extends State<ManageCycleTeachersScreen> {
  late DatabaseReference _teachersRef;
  StreamSubscription<DatabaseEvent>? _streamSubscription;
  List<Teacher> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _teachersRef = FirebaseDatabase.instance.ref(
        'planteles/${widget.campusId}/school_cycles/${widget.schoolCycleId}/teachers');
    _listenToTeachers();
  }

  void _listenToTeachers() {
    _streamSubscription = _teachersRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final teachersList = event.snapshot.children
            .map((snapshot) => Teacher.fromSnapshot(snapshot))
            .toList();
        setState(() {
          _teachers = teachersList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _teachers = [];
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UiHelpers.showSnackBar(context, 'Error al cargar maestros: $error',
          isError: true);
    });
  }

  void _showTeacherDialog({Teacher? teacher}) {
    final nameController = TextEditingController(text: teacher?.name);
    final subjectsController = TextEditingController(text: teacher?.subjects.join(', '));
    final isEditing = teacher != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Maestro' : 'Nuevo Maestro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del Maestro',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectsController,
                  decoration: const InputDecoration(
                      labelText: 'Materias (separadas por coma)',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final subjects = subjectsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                if (name.isNotEmpty) {
                  final newTeacher = Teacher(
                    id: teacher?.id ?? '',
                    name: name,
                    subjects: subjects,
                  );

                  if (isEditing) {
                    _teachersRef
                        .child(teacher.id)
                        .update(newTeacher.toFirebaseMap());
                  } else {
                    _teachersRef.push().set(newTeacher.toFirebaseMap());
                  }
                  Navigator.pop(context);
                } else {
                  UiHelpers.showSnackBar(
                      context, 'El nombre es obligatorio.',
                      isError: true);
                }
              },
              child: const Text('Guardar'),
            )
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Gestionar Personal Docente'),
            Text(
              widget.schoolCycleId,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTeacherList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTeacherDialog(),
        tooltip: 'Añadir Maestro',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTeacherList() {
    if (_teachers.isEmpty) {
      return const Center(child: Text('No hay maestros registrados para este ciclo.'));
    }

    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teachers.length,
      itemBuilder: (context, index) {
        final teacher = _teachers[index];
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(teacher.name.isNotEmpty ? teacher.name[0] : '?'),
              ),
              title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: teacher.subjects.isEmpty
                  ? const Text('Sin materias asignadas', style: TextStyle(fontStyle: FontStyle.italic))
                  : Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: teacher.subjects
                          .map((subject) => Chip(
                                label: Text(subject),
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 10),
                              ))
                          .toList(),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                    onPressed: () => _showTeacherDialog(teacher: teacher),
                    tooltip: 'Editar Maestro',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    onPressed: () async {
                      final confirmed = await UiHelpers.showConfirmationDialog(
                        context,
                        title: 'Eliminar Maestro',
                        content: '¿Estás seguro de que deseas eliminar a "${teacher.name}"?',
                      );
                      if (confirmed) {
                        _teachersRef.child(teacher.id).remove();
                      }
                    },
                    tooltip: 'Eliminar Maestro',
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
