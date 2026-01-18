import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class GroupManagementScreen extends StatefulWidget {
  final Function(String route)? onNavigate;
  const GroupManagementScreen({super.key, this.onNavigate});

  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  DatabaseReference? _groupsRef;



  StreamSubscription<DatabaseEvent>? _groupsSubscription;

  List<Group> _groups = [];
  final List<SchoolCycle> _schoolCycles = [];
  SchoolCycle? _selectedSchoolCycle;
  String? _campusId;
  final bool _isLoading = true;
//...
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              int crossAxisCount = 1;
              if (constraints.maxWidth > 600) crossAxisCount = 2;
              if (constraints.maxWidth > 900) crossAxisCount = 3;
              if (constraints.maxWidth > 1200) crossAxisCount = 4;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            if (widget.onNavigate != null)
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => widget.onNavigate!('home'),
                                tooltip: 'Volver a Inicio',
                              ),
                            Expanded(
                              child: Text(
                                'Gestión de Grupos',
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Spacer for alignment if back button exists
                            if (widget.onNavigate != null) const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      if (_campusId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8),
                          child: Text('PLANTEL $_campusId',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<SchoolCycle>(
                                value: _selectedSchoolCycle,
                                hint: const Text("Selecciona un ciclo"),
                                isExpanded: true,
                                icon: const Icon(Icons.filter_list_rounded),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedSchoolCycle = newValue;
                                      _loadGroups();
                                    });
                                  }
                                },
                                items: _schoolCycles
                                    .map((cycle) => DropdownMenuItem(
                                        value: cycle,
                                        child: Text(
                                            'Ciclo Escolar: ${cycle.id} (${cycle.type})',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _groups.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.class_outlined,
                                        size: 64,
                                        color:
                                            Colors.grey.withValues(alpha: 0.3)),
                                    const SizedBox(height: 16),
                                    Text("No hay grupos registrados",
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 16)),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.5,
                                ),
                                itemCount: _groups.length,
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  // Colores pastel dinámicos según semestre
                                  Color semesterColor;
                                  switch (group.semester) {
                                    case 1:
                                      semesterColor = Colors.blue.shade100;
                                      break;
                                    case 2:
                                      semesterColor = Colors.indigo.shade100;
                                      break;
                                    case 3:
                                      semesterColor = Colors.green.shade100;
                                      break;
                                    case 4:
                                      semesterColor = Colors.teal.shade100;
                                      break;
                                    case 5:
                                      semesterColor = Colors.orange.shade100;
                                      break;
                                    case 6:
                                      semesterColor =
                                          Colors.deepOrange.shade100;
                                      break;
                                    default:
                                      semesterColor = Colors.grey.shade200;
                                  }
                                  Color textColor =
                                      HSLColor.fromColor(semesterColor)
                                          .withLightness(0.3)
                                          .toColor();

                                  return FadeInUp(
                                    delay: Duration(milliseconds: 30 * index),
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          side: BorderSide(
                                              color: semesterColor, width: 1)),
                                      color: isDark
                                          ? theme.cardTheme.color
                                          : Colors.white,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () =>
                                            _showGroupDialog(group: group),
                                        child: Stack(
                                          children: [
                                            // Fondo decorativo suave
                                            Positioned(
                                              right: -20,
                                              top: -20,
                                              child: CircleAvatar(
                                                  radius: 50,
                                                  backgroundColor: semesterColor
                                                      .withOpacity(0.3)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration: BoxDecoration(
                                                            color:
                                                                semesterColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8)),
                                                        child: Text(
                                                            '${group.semester}º Semestre',
                                                            style: TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12)),
                                                      ),
                                                      Icon(Icons.more_horiz,
                                                          color: Colors
                                                              .grey.shade400),
                                                    ],
                                                  ),
                                                  Center(
                                                    child: Text(
                                                      group.name,
                                                      style: TextStyle(
                                                          fontSize: 32,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person_outline,
                                                          size: 16,
                                                          color: Colors
                                                              .grey.shade600),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                          '${group.studentCount} Alumnos',
                                                          style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontSize: 13)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Botón eliminar discreto
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: IconButton(
                                                icon: Icon(Icons.delete_outline,
                                                    size: 20,
                                                    color: theme
                                                        .colorScheme.error
                                                        .withOpacity(0.6)),
                                                onPressed: () =>
                                                    _confirmDelete(group),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(),
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('Nuevos Grupos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _confirmDelete(Group group) async {
    final confirm = await UiHelpers.showConfirmationDialog(context,
        title: 'Eliminar Grupo',
        content: '¿Estás seguro?',
        isDestructive: true);
    if (confirm && _groupsRef != null) {
      _groupsRef!.child(group.key).remove();
      if (mounted) UiHelpers.showSnackBar(context, 'Grupo eliminado.');
    }
  }



  void _loadGroups() {
    if (_selectedSchoolCycle == null || _groupsRef == null) return;
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupsRef!
        .orderByChild('schoolCycleId')
        .equalTo(_selectedSchoolCycle!.id)
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final groups = <Group>[];
        for (final child in event.snapshot.children) {
          groups.add(Group.fromSnapshot(child));
        }
        setState(() => _groups = groups);
      } else {
        setState(() => _groups = []);
      }
    });
  }

  void _showGroupDialog({Group? group}) {
    // Si editamos, solo permitimos uno a la vez. Si es nuevo, permitimos múltiples.
    final isEditing = group != null;
    final controller = TextEditingController(text: group?.name ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Grupo' : 'Crear Grupos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: isEditing
                      ? 'Identificador'
                      : 'Identificadores (separados por coma)',
                  hintText: isEditing ? '101' : 'Ej: 101, 102, 103',
                  helperText: isEditing ? null : 'Crea varios grupos a la vez.',
                  prefixIcon: const Icon(Icons.groups),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.text, // Permitir comas
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final input = controller.text.trim();
                if (input.isEmpty) return;

                if (_selectedSchoolCycle == null) {
                  UiHelpers.showSnackBar(
                      context, 'Error: No hay ciclo seleccionado.',
                      isError: true);
                  return;
                }

                // Procesar entrada
                final List<String> inputs = isEditing
                    ? [input]
                    : input
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                int createdCount = 0;
                String? firstError;

                for (final groupIdentifier in inputs) {
                  if (groupIdentifier.length < 3) continue; // Skip invalid

                  final int semester =
                      int.tryParse(groupIdentifier.substring(0, 1)) ?? 0;
                  if (semester == 0) continue;

                  // Validación
                  final String cycleType = _selectedSchoolCycle!.type;
                  bool isValid = false;

                  if (cycleType == 'A') {
                    if (semester % 2 == 0) isValid = true;
                  } else if (cycleType == 'B') {
                    if (semester % 2 != 0) isValid = true;
                  } else if (cycleType == 'Propedéutico') {
                    isValid = true;
                  }

                  if (!isValid) {
                    firstError ??=
                        'Grupo $groupIdentifier no válido para ciclo $cycleType';
                    continue;
                  }

                  if (group != null) {
                    _updateGroup(group.key, groupIdentifier, semester);
                    createdCount++;
                  } else {
                    _createGroup(groupIdentifier, semester);
                    createdCount++;
                  }
                }

                Navigator.pop(context);

                if (createdCount > 0) {
                  UiHelpers.showSnackBar(
                      context,
                      isEditing
                          ? 'Grupo actualizado.'
                          : '$createdCount grupos creados exitosamente.');
                } else if (firstError != null) {
                  UiHelpers.showSnackBar(context, firstError, isError: true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _createGroup(String name, int semester) {
    if (_groupsRef == null) return;
    _groupsRef!.push().set({
      'name': name,
      'semester': semester,
      'studentCount': 0,
      'schoolCycleId': _selectedSchoolCycle!.id,
    });
  }

  void _updateGroup(String key, String name, int semester) {
    if (_groupsRef == null) return;
    _groupsRef!.child(key).update({'name': name, 'semester': semester});
  }
}
