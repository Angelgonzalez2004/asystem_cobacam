import 'dart:async';
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

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      _teachersRef = FirebaseDatabase.instance.ref('planteles/$campus/teachers');

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
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  void _showTeacherDialog({Teacher? teacher}) {
    final nameController = TextEditingController(text: teacher?.name);
    final subjectsController = TextEditingController(text: teacher?.subjects.join(', '));
    final isEditing = teacher != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Maestro' : 'Añadir Maestro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del Maestro')),
              TextField(controller: subjectsController, decoration: const InputDecoration(labelText: 'Materias (separadas por coma)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final subjects = subjectsController.text.split(',').map((s) => s.trim()).toList();
                
                if (name.isNotEmpty && subjects.isNotEmpty && _teachersRef != null) {
                  final teacherData = {'name': name, 'subjects': subjects};
                  try {
                    if (isEditing) {
                      await _teachersRef!.child(teacher.key).update(teacherData);
                    } else {
                      await _teachersRef!.push().set(teacherData);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    _showErrorSnackBar('Error al guardar: ${e.toString()}');
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
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
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
        title: const Text('Gestión de Maestros'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teachersRef == null
              ? const Center(child: Text('No se pudo cargar la información del plantel.'))
              : _buildTeacherList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _teachersRef != null ? () => _showTeacherDialog() : null,
        backgroundColor: _teachersRef != null ? Theme.of(context).colorScheme.primary : Colors.grey,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTeacherList() {
    if (_teachers.isEmpty) {
      return const Center(child: Text('No hay maestros registrados.'));
    }
    return ListView.builder(
      itemCount: _teachers.length,
      itemBuilder: (context, index) {
        final teacher = _teachers[index];
        return ListTile(
          title: Text(teacher.name),
          subtitle: Text(teacher.subjects.join(', ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _showTeacherDialog(teacher: teacher)),
              IconButton(
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                onPressed: () {
                  _teachersRef!.child(teacher.key).remove();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
