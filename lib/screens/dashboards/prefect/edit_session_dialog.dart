import 'package:asystem_cobacam/models/class_session_model.dart';
import 'package:asystem_cobacam/models/teacher_model.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class EditSessionDialog extends StatefulWidget {

  final ClassSession session;

  final List<Teacher> availableTeachers;



  const EditSessionDialog({

    super.key,

    required this.session,

    required this.availableTeachers,

  });



  @override

  State<EditSessionDialog> createState() => _EditSessionDialogState();

}



class _EditSessionDialogState extends State<EditSessionDialog> {

  Teacher? _selectedTeacher;

  String? _selectedSubject;

  

  List<String> _subjectsForSelectedTeacher = [];



  @override

  void initState() {

    super.initState();

    if (widget.session.teacherId != null) {

      try {

        _selectedTeacher = widget.availableTeachers.firstWhere((t) => t.id == widget.session.teacherId);

        _subjectsForSelectedTeacher = _selectedTeacher?.subjects ?? [];

      } catch (e) {

        _selectedTeacher = null;

      }

    }

    if (widget.session.subjectName.isNotEmpty) {

      _selectedSubject = widget.session.subjectName;

    }

  }



  void _onTeacherChanged(Teacher? teacher) {

    setState(() {

      _selectedTeacher = teacher;

      _selectedSubject = null; // Reset subject when teacher changes

      if (teacher != null) {

        _subjectsForSelectedTeacher = teacher.subjects;

      } else {

        _subjectsForSelectedTeacher = [];

      }

    });

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

          DropdownSearch<Teacher>(

            selectedItem: _selectedTeacher,

            items: widget.availableTeachers,

            itemAsString: (Teacher? t) => t?.name ?? 'Sin asignar',

            onChanged: _onTeacherChanged,

            dropdownDecoratorProps: const DropDownDecoratorProps(

              dropdownSearchDecoration: InputDecoration(

                labelText: 'Maestro',

                border: OutlineInputBorder(),

              ),

            ),

            popupProps: PopupProps.menu(

              showSearchBox: true,

              emptyBuilder: (context, search) => const Center(

                child: Padding(

                  padding: EdgeInsets.all(16.0),

                  child: Text("No se encontraron maestros"),

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

          const SizedBox(height: 16),

          DropdownSearch<String>(

            selectedItem: _selectedSubject,

            items: _subjectsForSelectedTeacher,

            enabled: _selectedTeacher != null,

            onChanged: (String? newValue) {

              setState(() {

                _selectedSubject = newValue;

              });

            },

            dropdownDecoratorProps: DropDownDecoratorProps(

              dropdownSearchDecoration: InputDecoration(

                labelText: 'Materia',

                border: const OutlineInputBorder(),

                enabled: _selectedTeacher != null,

              ),

            ),

            popupProps: PopupProps.menu(

              showSearchBox: true,

              emptyBuilder: (context, search) => const Center(

                child: Padding(

                  padding: EdgeInsets.all(16.0),

                  child: Text("No se encontraron materias para este maestro"),

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

            if (_selectedTeacher != null && _selectedSubject != null) {

              final updatedSession = ClassSession(

                startTime: widget.session.startTime,

                endTime: widget.session.endTime,

                // Although we don't have a subject ID, we use the name as a key for now.

                // A better approach would be to have unique IDs for subjects within a teacher.

                subjectId: _selectedSubject!, 

                subjectName: _selectedSubject!,

                teacherId: _selectedTeacher!.id,

                teacherName: _selectedTeacher!.name,

              );

              Navigator.of(context).pop(updatedSession);

            } else {

              // If no subject/teacher is selected, it's equivalent to clearing the slot

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
