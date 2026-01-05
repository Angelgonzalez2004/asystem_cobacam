import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/services/hive_service.dart'; // ADDED: Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // ADDED: Import ConnectivityService
import 'package:provider/provider.dart'; // ADDED: Import Provider

class NonAttendanceManagementScreen extends StatefulWidget {
  const NonAttendanceManagementScreen({super.key});

  @override
  State<NonAttendanceManagementScreen> createState() => _NonAttendanceManagementScreenState();
}

class _NonAttendanceManagementScreenState extends State<NonAttendanceManagementScreen> {
  late final HiveService _hiveService; // ADDED: Declaration
  late final ConnectivityService _connectivityService; // ADDED: Declaration
  late final AppSettingsService _appSettingsService; // MODIFIED: to late final
  List<NonAttendanceDay> _nonAttendanceDays = [];
  bool _isLoading = true;
  String? _campusId;

  @override
  void initState() {
    super.initState();
    // ADDED: Initialize services
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
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

      if (!mounted) return;
      setState(() { _campusId = campus; });

      _loadNonAttendanceDays();

    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNonAttendanceDays() async {
    if (_campusId == null) return;
    setState(() => _isLoading = true);
    try {
      final days = await _appSettingsService.getAllNonAttendanceDays(_campusId!);
      if (!mounted) return;
      setState(() {
        _nonAttendanceDays = days;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Error al cargar días no lectivos: ${e.toString()}');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showNonAttendanceDayFormDialog({NonAttendanceDay? day}) async {
    final formKey = GlobalKey<FormState>();
    DateTime selectedStartDate = day?.date ?? DateTime.now();
    DateTime selectedEndDate = day?.date ?? DateTime.now(); // For range selection
    final reasonController = TextEditingController(text: day?.reason ?? '');
    bool isRangeSelection = false; // Flag to determine if selecting a range

    // If editing an existing day, assume single day selection
    if (day != null) {
      isRangeSelection = false;
      selectedStartDate = day.date;
      selectedEndDate = day.date;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setStateInDialog) {
            return AlertDialog(
              title: Text(day == null ? 'Añadir Día No Lectivo' : 'Editar Día No Lectivo'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (day == null) // Only show range option for new entries
                        SwitchListTile(
                          title: const Text('Seleccionar Rango de Fechas'),
                          value: isRangeSelection,
                          onChanged: (bool value) {
                            setStateInDialog(() {
                              isRangeSelection = value;
                              if (!isRangeSelection) { // Reset end date if switching to single day
                                selectedEndDate = selectedStartDate;
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 10),
                      ListTile(
                        title: Text('Fecha de Inicio: ${DateFormat('dd/MM/yyyy').format(selectedStartDate)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedStartDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setStateInDialog(() {
                              selectedStartDate = pickedDate;
                              if (!isRangeSelection) {
                                selectedEndDate = pickedDate; // Keep end date same as start for single selection
                              } else if (selectedEndDate.isBefore(selectedStartDate)) {
                                selectedEndDate = selectedStartDate; // Adjust end date if it's before new start date
                              }
                            });
                          }
                        },
                      ),
                      if (isRangeSelection)
                        ListTile(
                          title: Text('Fecha de Fin: ${DateFormat('dd/MM/yyyy').format(selectedEndDate)}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedEndDate,
                              firstDate: selectedStartDate, // End date cannot be before start date
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setStateInDialog(() => selectedEndDate = pickedDate);
                            }
                          },
                        ),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: 'Razón (ej. Feriado, Vacaciones, Lluvias Fuertes)'),
                        validator: (value) => value!.isEmpty ? 'La razón es obligatoria' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (_campusId == null) return;
                    if (!dialogContext.mounted) return;

                    try {
                      List<NonAttendanceDay> daysToSave = [];

                      if (day != null) { // Editing existing single day
                        final updatedDay = NonAttendanceDay(
                          id: DateFormat('yyyy-MM-dd').format(selectedStartDate),
                          campusId: _campusId!,
                          date: selectedStartDate,
                          reason: reasonController.text,
                        );
                        daysToSave.add(updatedDay);
                      } else { // Adding new day(s)
                        DateTime currentDate = selectedStartDate;
                        while (currentDate.isBefore(selectedEndDate) || currentDate.isAtSameMomentAs(selectedEndDate)) {
                          daysToSave.add(NonAttendanceDay(
                            id: DateFormat('yyyy-MM-dd').format(currentDate),
                            campusId: _campusId!,
                            date: currentDate,
                            reason: reasonController.text,
                          ));
                          currentDate = currentDate.add(const Duration(days: 1));
                        }
                      }
                      
                      for (final d in daysToSave) {
                        await _appSettingsService.addNonAttendanceDay(d); // add or update if id exists
                      }

                      _showSuccessSnackBar('Día(s) no lectivo(s) guardado(s) exitosamente.');
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      _loadNonAttendanceDays(); // Refresh list
                    } catch (e) {
                      _showErrorSnackBar('Error al guardar día(s) no lectivo(s): ${e.toString()}');
                    }
                  },
                  child: Text(day == null ? 'Añadir' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteNonAttendanceDay(NonAttendanceDay day) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar el día no lectivo del ${DateFormat('dd/MM/yyyy').format(day.date)}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_campusId == null) return;
      try {
        await _appSettingsService.deleteNonAttendanceDay(_campusId!, day.id);
        _showSuccessSnackBar('Día no lectivo eliminado exitosamente.');
        _loadNonAttendanceDays(); // Refresh list
      } catch (e) {
        _showErrorSnackBar('Error al eliminar día no lectivo: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    // _schoolCyclesSubscription?.cancel(); // No subscription currently used in this screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campusId == null
              ? const Center(child: Text('No se pudo determinar el plantel.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _nonAttendanceDays.isEmpty
                        ? Center(child: Text('No hay días no lectivos registrados. Puedes añadir uno.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _nonAttendanceDays.length,
                            itemBuilder: (context, index) {
                              final day = _nonAttendanceDays[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                child: ListTile(
                                  title: Text(DateFormat('dd/MM/yyyy').format(day.date)),
                                  subtitle: Text(day.reason ?? 'Sin razón'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showNonAttendanceDayFormDialog(day: day),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: theme.colorScheme.error),
                                        onPressed: () => _confirmDeleteNonAttendanceDay(day),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNonAttendanceDayFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
