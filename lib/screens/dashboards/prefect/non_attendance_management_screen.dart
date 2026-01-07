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
  
  List<_SuspensionGroup> _groupedDays = [];
  
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
      
      // Ordenar por fecha
      days.sort((a, b) => a.date.compareTo(b.date));

      // Agrupar rangos
      final List<_SuspensionGroup> groups = [];
      if (days.isNotEmpty) {
        _SuspensionGroup currentGroup = _SuspensionGroup(
          start: days.first.date,
          end: days.first.date,
          reason: days.first.reason ?? 'Sin motivo',
          ids: [days.first.id],
        );

        for (int i = 1; i < days.length; i++) {
          final day = days[i];
          // Verificar si es consecutivo (día siguiente) y misma razón
          final isConsecutive = day.date.difference(currentGroup.end).inHours <= 24; 
          // Check < 25 hours to be safe with DST etc, basically consecutive days
          final isSameReason = (day.reason ?? 'Sin motivo') == currentGroup.reason;

          if (isConsecutive && isSameReason) {
            currentGroup.end = day.date;
            currentGroup.ids.add(day.id);
          } else {
            groups.add(currentGroup);
            currentGroup = _SuspensionGroup(
              start: day.date,
              end: day.date,
              reason: day.reason ?? 'Sin motivo',
              ids: [day.id],
            );
          }
        }
        groups.add(currentGroup);
      }

      setState(() {
        _groupedDays = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al cargar días.', isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNonAttendanceDayFormDialog({_SuspensionGroup? group}) async {
    final formKey = GlobalKey<FormState>();
    DateTime selectedStartDate = group?.start ?? DateTime.now();
    DateTime selectedEndDate = group?.end ?? DateTime.now();
    final reasonController = TextEditingController(text: group?.reason ?? '');
    
    // Si editamos un grupo de más de 1 día, activamos el switch por defecto.
    bool isRangeSelection = group != null ? (group.ids.length > 1) : false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setStateInDialog) {
            return AlertDialog(
              title: Text(group == null ? 'Añadir Suspensión' : 'Editar Suspensión'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            hintText: 'Ej. Vacaciones, Junta, Mal Clima',
                            prefixIcon: Icon(Icons.info_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
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
                      // Si es Edición: Borramos primero los días viejos
                      // Esto maneja cambios de fecha (borra viejos, crea nuevos)
                      // y cambios de nombre.
                      if (group != null) {
                         for (final id in group.ids) {
                            await _appSettingsService.deleteNonAttendanceDay(_campusId!, id);
                         }
                      }

                      List<NonAttendanceDay> daysToSave = [];
                      DateTime current = selectedStartDate;
                      
                      // Asegurar que iteramos correctamente hasta el final inclusive
                      // Normalizamos fechas para evitar errores de hora
                      final end = DateTime(selectedEndDate.year, selectedEndDate.month, selectedEndDate.day, 23, 59, 59);
                      
                      while (current.isBefore(end)) {
                        daysToSave.add(NonAttendanceDay(
                            id: DateFormat('yyyy-MM-dd').format(current),
                            campusId: _campusId!,
                            date: current,
                            reason: reasonController.text));
                        current = current.add(const Duration(days: 1));
                      }
                      
                      for (final d in daysToSave) {
                        await _appSettingsService.addNonAttendanceDay(d);
                      }
                      
                      if (mounted) {
                        UiHelpers.showSnackBar(
                            context, group == null 
                              ? 'Se registraron ${daysToSave.length} días.'
                              : 'Suspensión actualizada.');
                      }
                      Navigator.pop(dialogContext);
                      _loadNonAttendanceDays();
                    } catch (e) {
                      UiHelpers.showSnackBar(context, 'Error al guardar.',
                          isError: true);
                    }
                  },
                  child: Text(group == null ? 'Guardar' : 'Actualizar'),
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
            Text(DateFormat('dd/MMM/yyyy', 'es_MX').format(date).toUpperCase(),
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
                  child: _groupedDays.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 64, color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('No hay suspensiones registradas.',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _groupedDays.length,
                          itemBuilder: (context, index) {
                            final group = _groupedDays[index];
                            final isRange = group.ids.length > 1;
                            
                            return FadeInUp(
                              delay: Duration(milliseconds: 30 * index),
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                                ),
                                color: isDark ? theme.cardTheme.color : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(isRange ? Icons.date_range_rounded : Icons.event_busy, color: Colors.orange.shade800),
                                    ),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            isRange 
                                              ? 'Del ${DateFormat('d MMM', 'es_MX').format(group.start)} al ${DateFormat('d MMM', 'es_MX').format(group.end)}'.toUpperCase()
                                              : DateFormat('EEEE d \nde MMMM', 'es_MX').format(group.start).toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: isRange ? 15 : 14,
                                              color: theme.textTheme.titleMedium?.color
                                            )
                                        ),
                                        if (isRange)
                                          Text(
                                            '${group.ids.length} días hábiles',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          )
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        group.reason,
                                        style: TextStyle(
                                          fontSize: 13, 
                                          color: theme.textTheme.bodyMedium?.color, 
                                          fontStyle: FontStyle.italic
                                        ),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                          onPressed: () => _showNonAttendanceDayFormDialog(group: group),
                                          tooltip: 'Editar suspensión',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                          onPressed: () => _confirmDeleteGroup(group),
                                          tooltip: 'Eliminar suspensión',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNonAttendanceDayFormDialog(),
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Suspensión', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(_SuspensionGroup group) async {
    final confirm = await UiHelpers.showConfirmationDialog(
        context,
        title: 'Eliminar Suspensión',
        content: group.ids.length > 1 
            ? '¿Deseas eliminar este periodo de ${group.ids.length} días?' 
            : '¿Eliminar este día de suspensión?',
        isDestructive: true);
        
    if (confirm && _campusId != null) {
      // Eliminar uno por uno
      for (final id in group.ids) {
         await _appSettingsService.deleteNonAttendanceDay(_campusId!, id);
      }
      _loadNonAttendanceDays();
      if (mounted) UiHelpers.showSnackBar(context, 'Suspensión eliminada.');
    }
  }
}

class _SuspensionGroup {
  DateTime start;
  DateTime end;
  String reason;
  List<String> ids;

  _SuspensionGroup({
    required this.start,
    required this.end,
    required this.reason,
    required this.ids,
  });
}
