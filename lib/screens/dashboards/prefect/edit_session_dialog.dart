import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/subject_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class EditSessionDialog extends StatefulWidget {
  final ClassSession session;
  final List<Subject> availableSubjects;
  final List<Teacher> availableTeachers;
  final int groupSemester;

  const EditSessionDialog({
    super.key,
    required this.session,
    required this.availableSubjects,
    required this.availableTeachers,
    required this.groupSemester,
  });

  @override
  State<EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<EditSessionDialog> {
  Subject? _selectedSubject;
  Teacher? _selectedTeacher;
  late List<Subject> _filteredSubjects;

  @override
  void initState() {
    super.initState();
    _filteredSubjects = widget.availableSubjects
        .where((s) => s.semester == widget.groupSemester)
        .toList();

    if (widget.session.subjectId != null) {
      try {
        _selectedSubject = _filteredSubjects.firstWhere((s) => s.id == widget.session.subjectId);
      } catch (e) {
        _selectedSubject = null;
      }
    }
    if (widget.session.teacherId != null) {
      try {
        _selectedTeacher = widget.availableTeachers.firstWhere((t) => t.id == widget.session.teacherId);
      } catch (e) {
        _selectedTeacher = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar Bloque Horario'),
              Text(
                '${widget.session.startTime} - ${widget.session.endTime}',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownSearch<Subject>(
            selectedItem: _selectedSubject,
            items: _filteredSubjects,
            itemAsString: (Subject? s) => s?.name ?? 'Sin materia',
            onChanged: (Subject? newValue) {
              setState(() {
                _selectedSubject = newValue;
              });
            },
            dropdownDecoratorProps: const DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Materia',
                border: OutlineInputBorder(),
              ),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              emptyBuilder: (context, search) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No se encontraron datos"),
                ),
              ),
              searchFieldProps: const TextFieldProps(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: "Buscar materia...",
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownSearch<Teacher>(
            selectedItem: _selectedTeacher,
            items: widget.availableTeachers,
            itemAsString: (Teacher? t) => t?.name ?? 'Sin asignar',
            onChanged: (Teacher? newValue) {
              setState(() {
                _selectedTeacher = newValue;
              });
            },
            dropdownDecoratorProps: const DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Maestro (Opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              emptyBuilder: (context, search) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No se encontraron datos"),
                ),
              ),
              searchFieldProps: const TextFieldProps(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: "Buscar maestro...",
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.session.isFree)
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar Eliminación'),
                  content: const Text('¿Estás seguro de que deseas quitar esta materia del horario?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!mounted) return;
                Navigator.of(context).pop(ClassSession(
                  startTime: widget.session.startTime,
                  endTime: widget.session.endTime,
                  subjectId: 'DELETE_SESSION',
                ));
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedSubject != null) {
              final updatedSession = ClassSession(
                startTime: widget.session.startTime,
                endTime: widget.session.endTime,
                subjectId: _selectedSubject!.id,
                subjectName: _selectedSubject!.name,
                teacherId: _selectedTeacher?.id,
                teacherName: _selectedTeacher?.name,
              );
              Navigator.of(context).pop(updatedSession);
            } else {
              // If no subject is selected, it's equivalent to deleting/clearing the slot
              Navigator.of(context).pop(ClassSession(
                startTime: widget.session.startTime,
                endTime: widget.session.endTime,
                subjectId: 'DELETE_SESSION',
              ));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
