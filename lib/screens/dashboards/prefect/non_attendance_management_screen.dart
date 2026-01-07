import 'dart:async';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class NonAttendanceManagementScreen extends StatefulWidget {
  const NonAttendanceManagementScreen({super.key});

  @override
  State<NonAttendanceManagementScreen> createState() =>
      _NonAttendanceManagementScreenState();
}

class _NonAttendanceManagementScreenState
    extends State<NonAttendanceManagementScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;
  List<NonAttendanceDay> _nonAttendanceDays = [];
  bool _isLoading = true;
  String? _campusId;

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService =
        AppSettingsService(_hiveService, _connectivityService);
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

      if (!mounted) return;
      setState(() {
        _campusId = campus;
      });

      _loadNonAttendanceDays();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error: ${e.toString()}',
            isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNonAttendanceDays() async {
    if (_campusId == null) return;
    setState(() => _isLoading = true);
    try {
      final days =
          await _appSettingsService.getAllNonAttendanceDays(_campusId!);
      if (!mounted) return;
      setState(() {
        _nonAttendanceDays = days;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar días.', isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNonAttendanceDayFormDialog({NonAttendanceDay? day}) async {
    final formKey = GlobalKey<FormState>();
    DateTime selectedStartDate = day?.date ?? DateTime.now();
    DateTime selectedEndDate = day?.date ?? DateTime.now();
    final reasonController = TextEditingController(text: day?.reason ?? '');
    bool isRangeSelection = false;

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
              title: Text(day == null ? 'Añadir Suspensión' : 'Editar Día'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (day == null)
                        SwitchListTile(
                          title: const Text('Rango de Fechas',
                              style: TextStyle(fontSize: 14)),
                          value: isRangeSelection,
                          onChanged: (bool value) {
                            setStateInDialog(() {
                              isRangeSelection = value;
                              if (!isRangeSelection) {
                                selectedEndDate = selectedStartDate;
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 10),
                      _buildDateTile(dialogContext, 'Inicio', selectedStartDate,
                          (d) {
                        setStateInDialog(() {
                          selectedStartDate = d;
                          if (!isRangeSelection || selectedEndDate.isBefore(d)) {
                            selectedEndDate = d;
                          }
                        });
                      }),
                      if (isRangeSelection)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildDateTile(
                              dialogContext,
                              'Fin',
                              selectedEndDate,
                              (d) =>
                                  setStateInDialog(() => selectedEndDate = d),
                              minDate: selectedStartDate),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                            labelText: 'Razón / Motivo',
                            prefixIcon: Icon(Icons.info_outline)),
                        validator: (value) =>
                            value!.isEmpty ? 'Requerido' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (_campusId == null) return;

                    try {
                      List<NonAttendanceDay> daysToSave = [];
                      if (day != null) {
                        daysToSave.add(NonAttendanceDay(
                            id: DateFormat('yyyy-MM-dd')
                                .format(selectedStartDate),
                            campusId: _campusId!,
                            date: selectedStartDate,
                            reason: reasonController.text));
                      } else {
                        DateTime current = selectedStartDate;
                        while (current.isBefore(selectedEndDate) ||
                            current.isAtSameMomentAs(selectedEndDate)) {
                          daysToSave.add(NonAttendanceDay(
                              id: DateFormat('yyyy-MM-dd').format(current),
                              campusId: _campusId!,
                              date: current,
                              reason: reasonController.text));
                          current = current.add(const Duration(days: 1));
                        }
                      }
                      for (final d in daysToSave) {
                        await _appSettingsService.addNonAttendanceDay(d);
                      }
                      if (mounted) {
                        UiHelpers.showSnackBar(
                            context, 'Días guardados correctamente.');
                      }
                      Navigator.pop(dialogContext);
                      _loadNonAttendanceDays();
                    } catch (e) {
                      UiHelpers.showSnackBar(context, 'Error al guardar.',
                          isError: true);
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

  Widget _buildDateTile(BuildContext context, String label, DateTime date,
      Function(DateTime) onPicked,
      {DateTime? minDate}) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: minDate ?? DateTime(2020),
            lastDate: DateTime(2100));
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
            Text('$label:',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // AppBar eliminado
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _nonAttendanceDays.isEmpty
                      ? Center(
                          child: Text('No hay días no lectivos registrados.',
                              style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _nonAttendanceDays.length,
                          itemBuilder: (context, index) {
                            final day = _nonAttendanceDays[index];
                            // Detectar si es parte de un rango (lógica simple visual)
                            // Para visualización ideal, deberíamos agrupar rangos, pero mostraremos día por día limpio.
                            
                            return FadeInUp(
                              delay: Duration(milliseconds: 50 * index),
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.red.withOpacity(0.1)),
                                ),
                                color: isDark ? theme.cardTheme.color : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.event_busy_rounded, color: Colors.red),
                                    ),
                                    title: Text(
                                        DateFormat('EEEE d \nde MMMM', 'es_MX').format(day.date).toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6)
                                            ),
                                            child: Text(
                                              day.reason ?? 'Suspensión',
                                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => _showNonAttendanceDayFormDialog(day: day),
                                            tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                                          onPressed: () async {
                                            final confirm = await UiHelpers.showConfirmationDialog(
                                                context,
                                                title: 'Eliminar',
                                                content: '¿Eliminar este día de suspensión?',
                                                isDestructive: true);
                                            if (confirm && _campusId != null) {
                                              await _appSettingsService.deleteNonAttendanceDay(_campusId!, day.id);
                                              _loadNonAttendanceDays();
                                              if (mounted) UiHelpers.showSnackBar(context, 'Eliminado.');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
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
        onPressed: () => _showNonAttendanceDayFormDialog(),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
