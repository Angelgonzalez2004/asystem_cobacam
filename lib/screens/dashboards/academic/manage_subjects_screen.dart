import 'dart:async';
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

      final userProfileSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnapshot.exists) throw Exception('No se encontró el perfil del usuario.');
      
      final userData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final campus = userData['campus'];
      if (campus == null) throw Exception('El usuario no tiene un plantel asignado.');

      _subjectsRef = FirebaseDatabase.instance.ref('planteles/$campus/subjects');

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
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
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
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre de la Materia')),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Código de la Materia')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final code = codeController.text;
                
                if (name.isNotEmpty && code.isNotEmpty && _subjectsRef != null) {
                  final subjectData = {'name': name, 'code': code};
                  try {
                    if (isEditing) {
                      await _subjectsRef!.child(subject.key).update(subjectData);
                    } else {
                      await _subjectsRef!.push().set(subjectData);
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
        title: const Text('Gestión de Materias'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjectsRef == null
              ? const Center(child: Text('No se pudo cargar la información del plantel.'))
              : _buildSubjectList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _subjectsRef != null ? () => _showSubjectDialog() : null,
        backgroundColor: _subjectsRef != null ? Theme.of(context).colorScheme.primary : Colors.grey,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubjectList() {
    if (_subjects.isEmpty) {
      return const Center(child: Text('No hay materias registradas.'));
    }
    return ListView.builder(
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return ListTile(
          title: Text(subject.name),
          subtitle: Text('Código: ${subject.code}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _showSubjectDialog(subject: subject)),
              IconButton(
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                onPressed: () {
                  _subjectsRef!.child(subject.key).remove();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
