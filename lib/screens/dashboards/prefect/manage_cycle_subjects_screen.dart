import 'dart:async';
import 'package:asystem_cobacam/models/subject_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ManageCycleSubjectsScreen extends StatefulWidget {
  final String campusId;
  final String schoolCycleId;

  const ManageCycleSubjectsScreen({
    super.key,
    required this.campusId,
    required this.schoolCycleId,
  });

  @override
  State<ManageCycleSubjectsScreen> createState() =>
      _ManageCycleSubjectsScreenState();
}

class _ManageCycleSubjectsScreenState extends State<ManageCycleSubjectsScreen> {
  late DatabaseReference _subjectsRef;
  StreamSubscription<DatabaseEvent>? _streamSubscription;
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subjectsRef = FirebaseDatabase.instance.ref(
        'planteles/${widget.campusId}/school_cycles/${widget.schoolCycleId}/subjects');
    _listenToSubjects();
  }

  void _listenToSubjects() {
    _streamSubscription = _subjectsRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final subjectsList = event.snapshot.children
            .map((snapshot) => Subject.fromSnapshot(snapshot))
            .toList();
        setState(() {
          _subjects = subjectsList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _subjects = [];
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UiHelpers.showSnackBar(context, 'Error al cargar materias: $error',
          isError: true);
    });
  }

  void _showSubjectDialog({Subject? subject}) {
    final nameController = TextEditingController(text: subject?.name);
    final codeController = TextEditingController(text: subject?.code);
    final semesterController =
        TextEditingController(text: subject?.semester.toString() ?? '');
    final isEditing = subject != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Materia' : 'Nueva Materia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre de la Materia',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                      labelText: 'Código de la Materia',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: semesterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Semestre', border: OutlineInputBorder()),
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
                final code = codeController.text.trim();
                final semester = int.tryParse(semesterController.text.trim());

                if (name.isNotEmpty && code.isNotEmpty && semester != null) {
                  final newSubject = Subject(
                    id: subject?.id ?? '', // ID is handled by Firebase push key
                    name: name,
                    code: code,
                    semester: semester,
                  );

                  if (isEditing) {
                    _subjectsRef
                        .child(subject.id)
                        .update(newSubject.toFirebaseMap());
                  } else {
                    _subjectsRef.push().set(newSubject.toFirebaseMap());
                  }
                  Navigator.pop(context);
                } else {
                  UiHelpers.showSnackBar(
                      context, 'Por favor, llena todos los campos.',
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
            const Text('Gestionar Materias'),
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
          : _buildSubjectList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubjectList() {
    if (_subjects.isEmpty) {
      return const Center(child: Text('No hay materias registradas para este ciclo.'));
    }
    
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text('${subject.semester}'),
              ),
              title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subject.code),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                    onPressed: () => _showSubjectDialog(subject: subject),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    onPressed: () async {
                      final confirmed = await UiHelpers.showConfirmationDialog(
                        context,
                        title: 'Eliminar Materia',
                        content: '¿Estás seguro de que deseas eliminar "${subject.name}"?',
                      );
                      if (confirmed) {
                        _subjectsRef.child(subject.id).remove();
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