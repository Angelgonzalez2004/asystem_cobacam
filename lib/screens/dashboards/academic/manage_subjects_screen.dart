import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// Modelo de datos para una Materia, adaptado para Firebase
class Subject {
  String key; // Firebase key
  String name;
  String code;

  Subject({required this.key, required this.name, required this.code});

  factory Subject.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Subject(
      key: snapshot.key!,
      name: data['name'] ?? 'Sin Nombre',
      code: data['code'] ?? 'Sin Código',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
      };
}

class ManageSubjectsScreen extends StatefulWidget {
  const ManageSubjectsScreen({super.key});

  @override
  State<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  DatabaseReference? _subjectsRef;
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _streamSubscription;
  List<Subject> _subjects = [];

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

      _subjectsRef =
          FirebaseDatabase.instance.ref('planteles/$campus/subjects');

      _streamSubscription = _subjectsRef!.onValue.listen((event) {
        if (!event.snapshot.exists) {
          setState(() {
            _subjects = [];
            _isLoading = false;
          });
          return;
        }
        final subjectsList = event.snapshot.children
            .map((snapshot) => Subject.fromSnapshot(snapshot))
            .toList();

        setState(() {
          _subjects = subjectsList;
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

  void _showSubjectDialog({Subject? subject}) {
    final nameController = TextEditingController(text: subject?.name);
    final codeController = TextEditingController(text: subject?.code);
    final isEditing = subject != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Materia' : 'Añadir Materia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre de la Materia')),
              const SizedBox(height: 12),
              TextField(
                  controller: codeController,
                  decoration:
                      const InputDecoration(labelText: 'Código de la Materia')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final code = codeController.text;

                if (name.isNotEmpty &&
                    code.isNotEmpty &&
                    _subjectsRef != null) {
                  final subjectData = {'name': name, 'code': code};
                  try {
                    if (isEditing) {
                      await _subjectsRef!.child(subject.key).update(subjectData);
                    } else {
                      await _subjectsRef!.push().set(subjectData);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (mounted) {
                      UiHelpers.showSnackBar(context, isEditing ? 'Materia actualizada.' : 'Materia añadida.');
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
        title: const Text('Gestión de Materias'),
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
                  : _subjectsRef == null
                      ? const Center(
                          child: Text(
                              'No se pudo cargar la información del plantel.'))
                      : _buildSubjectList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _subjectsRef != null ? () => _showSubjectDialog() : null,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSubjectList() {
    if (_subjects.isEmpty) {
      return const Center(child: Text('No hay materias registradas.'));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
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
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.book, color: Colors.orange.shade600),
              ),
              title: Text(subject.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject.code,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: theme.colorScheme.primary),
                    onPressed: () => _showSubjectDialog(subject: subject),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    onPressed: () async {
                      final confirm = await UiHelpers.showConfirmationDialog(
                          context,
                          title: 'Eliminar Materia',
                          content:
                              '¿Estás seguro de que deseas eliminar esta materia?',
                          isDestructive: true);
                      if (confirm) {
                        _subjectsRef!.child(subject.key).remove();
                        if (mounted) {
                          UiHelpers.showSnackBar(context, 'Materia eliminada.');
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
