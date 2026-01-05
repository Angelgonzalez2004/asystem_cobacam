import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchoolCycleManagementScreen extends StatefulWidget {
  const SchoolCycleManagementScreen({super.key});

  @override
  _SchoolCycleManagementScreenState createState() =>
      _SchoolCycleManagementScreenState();
}

class _SchoolCycleManagementScreenState
    extends State<SchoolCycleManagementScreen> {
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('school_cycles');

  List<SchoolCycle> _schoolCycles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchoolCycles();
  }

  void _loadSchoolCycles() {
    _schoolCyclesRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final cycles = <SchoolCycle>[];
        for (final child in event.snapshot.children) {
          cycles.add(SchoolCycle.fromSnapshot(child));
        }
        if (mounted) {
          setState(() {
            _schoolCycles = cycles;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _schoolCycles = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ciclos Escolares'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _schoolCycles.isEmpty
                      ? Center(
                          child: Text('No hay ciclos registrados.',
                              style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _schoolCycles.length,
                          itemBuilder: (context, index) {
                            final cycle = _schoolCycles[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: 50 * index),
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: isDark
                                      ? BorderSide.none
                                      : BorderSide(color: Colors.grey.shade200),
                                ),
                                color: isDark
                                    ? theme.cardTheme.color
                                    : Colors.white,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(Icons.calendar_month_outlined,
                                        color: theme.colorScheme.primary),
                                  ),
                                  title: Text(cycle.id,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.date_range,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${DateFormat('dd/MM/yyyy').format(cycle.startDate)} - ${DateFormat('dd/MM/yyyy').format(cycle.endDate)}',
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodySmall?.color),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text('TIPO ${cycle.type}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.teal.shade700,
                                                  fontWeight: FontWeight.bold)),
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
                                        onPressed: () => _showSchoolCycleDialog(
                                            cycle: cycle),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: theme.colorScheme.error),
                                        onPressed: () async {
                                          final confirm = await UiHelpers
                                              .showConfirmationDialog(context,
                                                  title: 'Eliminar Ciclo',
                                                  content: '¿Estás seguro?',
                                                  isDestructive: true);
                                          if (confirm) {
                                            _deleteSchoolCycle(cycle.id);
                                            if (mounted) {
                                              UiHelpers.showSnackBar(
                                                  context, 'Ciclo eliminado.');
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
                        ),
                ),
              );
            }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSchoolCycleDialog(),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showSchoolCycleDialog({SchoolCycle? cycle}) {
    final idController = TextEditingController(text: cycle?.id ?? '');
    String? selectedType = cycle?.type;
    DateTime startDate = cycle?.startDate ?? DateTime.now();
    DateTime endDate = cycle?.endDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(cycle == null ? 'Nuevo Ciclo' : 'Editar Ciclo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                          labelText: 'ID (ej. 2025-A)',
                          prefixIcon: Icon(Icons.tag)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de Ciclo',
                          prefixIcon: Icon(Icons.category_outlined)),
                      items: ['A', 'B', 'Propedéutico']
                          .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedType = v),
                    ),
                    const SizedBox(height: 20),
                    _buildDatePickerTile('Inicio', startDate,
                        (d) => setState(() => startDate = d)),
                    const SizedBox(height: 12),
                    _buildDatePickerTile(
                        'Fin', endDate, (d) => setState(() => endDate = d)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (idController.text.isNotEmpty && selectedType != null) {
                      final newCycle = SchoolCycle(
                          id: idController.text,
                          type: selectedType!,
                          startDate: startDate,
                          endDate: endDate);
                      if (cycle == null) {
                        _createSchoolCycle(newCycle);
                      } else {
                        _updateSchoolCycle(newCycle);
                      }
                      Navigator.pop(context);
                      UiHelpers.showSnackBar(
                          context, 'Guardado correctamente.');
                    } else {
                      UiHelpers.showSnackBar(
                          context, 'Completa todos los campos.',
                          isError: true);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerTile(
      String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035));
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Fecha $label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(DateFormat('dd/MM/yyyy').format(date),
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _createSchoolCycle(SchoolCycle cycle) =>
      _schoolCyclesRef.child(cycle.id).set(cycle.toFirebaseMap());
  void _updateSchoolCycle(SchoolCycle cycle) =>
      _schoolCyclesRef.child(cycle.id).update(cycle.toFirebaseMap());
  void _deleteSchoolCycle(String id) => _schoolCyclesRef.child(id).remove();
}
