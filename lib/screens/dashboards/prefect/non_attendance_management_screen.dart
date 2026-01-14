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

  // LISTA DE MOTIVOS PREDEFINIDOS (23)
  final List<String> _presetReasons = [
    'Suspensión Oficial (SEP)',
    'Consejo Técnico Escolar (CTE)',
    'Descarga Administrativa',
    'Día Festivo Oficial',
    'Vacaciones de Semana Santa',
    'Vacaciones de Invierno',
    'Vacaciones de Verano',
    'Día del Maestro',
    'Día de las Madres',
    'Día del Estudiante',
    'Aniversario del Sindicato',
    'Aniversario del Colegio',
    'Condiciones Climáticas (Lluvias/Huracán)',
    'Fumigación / Sanitización',
    'Mantenimiento de Instalaciones',
    'Falla de Suministro Eléctrico/Agua',
    'Capacitación Docente',
    'Evento Cívico / Desfile',
    'Evento Cultural / Deportivo',
    'Luto Institucional',
    'Contingencia Sanitaria',
    'Usos y Costumbres Locales',
    'Otro (Especificar)',
  ];

  // MAPEO DE ICONOS PROFESIONALES
  final Map<String, IconData> _reasonIcons = {
    'Suspensión Oficial (SEP)': Icons.gavel_rounded,
    'Consejo Técnico Escolar (CTE)': Icons.groups_rounded,
    'Descarga Administrativa': Icons.receipt_long_rounded,
    'Día Festivo Oficial': Icons.flag_rounded,
    'Vacaciones de Semana Santa': Icons.beach_access_rounded,
    'Vacaciones de Invierno': Icons.ac_unit_rounded,
    'Vacaciones de Verano': Icons.wb_sunny_rounded,
    'Día del Maestro': Icons.school_rounded,
    'Día de las Madres': Icons.favorite_rounded,
    'Día del Estudiante': Icons.celebration_rounded,
    'Aniversario del Sindicato': Icons.badge_rounded,
    'Aniversario del Colegio': Icons.workspace_premium_rounded,
    'Condiciones Climáticas (Lluvias/Huracán)': Icons.thunderstorm_rounded,
    'Fumigación / Sanitización': Icons.clean_hands_rounded,
    'Mantenimiento de Instalaciones': Icons.build_rounded,
    'Falla de Suministro Eléctrico/Agua': Icons.power_off_rounded,
    'Capacitación Docente': Icons.model_training_rounded,
    'Evento Cívico / Desfile': Icons.military_tech_rounded,
    'Evento Cultural / Deportivo': Icons.emoji_events_rounded,
    'Luto Institucional': Icons.church_rounded,
    'Contingencia Sanitaria': Icons.medical_services_rounded,
    'Usos y Costumbres Locales': Icons.theater_comedy_rounded,
    'Otro (Especificar)': Icons.more_horiz_rounded,
  };

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
        UiHelpers.showSnackBar(context, 'Error de conexión: ${e.toString()}',
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
      
      days.sort((a, b) => a.date.compareTo(b.date));

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
          final isConsecutive = day.date.difference(currentGroup.end).inHours <= 25; 
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
        UiHelpers.showSnackBar(context, 'No se pudieron cargar los datos.', isError: true);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNonAttendanceDayFormDialog({_SuspensionGroup? group}) async {
    final formKey = GlobalKey<FormState>();
    DateTime selectedStartDate = group?.start ?? DateTime.now();
    DateTime selectedEndDate = group?.end ?? DateTime.now();
    
    // Determinar valor inicial del dropdown
    String? initialDropdownValue;
    final existingReason = group?.reason;
    if (existingReason != null) {
      if (_presetReasons.contains(existingReason)) {
        initialDropdownValue = existingReason;
      } else {
        initialDropdownValue = 'Otro (Especificar)';
      }
    }

    String? selectedReason = initialDropdownValue;
    final otherReasonController = TextEditingController(
      text: (initialDropdownValue == 'Otro (Especificar)') ? existingReason : ''
    );
    
    bool isRangeSelection = group != null ? (group.ids.length > 1) : false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setStateInDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(group == null ? Icons.add_circle_outline : Icons.edit_calendar_rounded, 
                       color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Text(group == null ? 'Nueva Suspensión' : 'Modificar Evento', style: const TextStyle(fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.1))
                        ),
                        child: SwitchListTile(
                          title: const Text('Periodo de varios días', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Activar para puentes o vacaciones', style: TextStyle(fontSize: 12)),
                          value: isRangeSelection,
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onChanged: (bool value) {
                            setStateInDialog(() {
                              isRangeSelection = value;
                              if (!isRangeSelection) {
                                selectedEndDate = selectedStartDate;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTile(
                              dialogContext, 
                              'Inicio', 
                              selectedStartDate,
                              (d) {
                                setStateInDialog(() {
                                  selectedStartDate = d;
                                  if (!isRangeSelection || selectedEndDate.isBefore(d)) {
                                    selectedEndDate = d;
                                  }
                                });
                              }
                            ),
                          ),
                          if (isRangeSelection) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateTile(
                                dialogContext,
                                'Fin',
                                selectedEndDate,
                                (d) => setStateInDialog(() => selectedEndDate = d),
                                minDate: selectedStartDate
                              ),
                            ),
                          ]
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          labelText: 'Motivo de Suspensión',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        isExpanded: true,
                        items: _presetReasons.map((r) {
                          final icon = _reasonIcons[r] ?? Icons.event_busy_rounded;
                          return DropdownMenuItem(
                            value: r, 
                            child: Row(
                              children: [
                                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 12),
                                Expanded(child: Text(r, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                              ],
                            )
                          );
                        }).toList(),
                        onChanged: (val) => setStateInDialog(() => selectedReason = val),
                        validator: (val) => val == null ? 'Seleccione un motivo' : null,
                      ),

                      if (selectedReason == 'Otro (Especificar)')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextFormField(
                            controller: otherReasonController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Especifique el motivo',
                              hintText: 'Ej. Desfile Conmemorativo',
                              prefixIcon: const Icon(Icons.edit_note_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) => value!.trim().isEmpty ? 'Es necesario especificar' : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (_campusId == null) return;

                    final finalReason = (selectedReason == 'Otro (Especificar)') 
                        ? otherReasonController.text.trim() 
                        : selectedReason!;

                    try {
                      // Feedback Visual de Carga (Overlay básico o bloqueo)
                      // Como es un dialog modal, la operación async bloqueará un poco si no cerramos.
                      // Cerramos y mostramos loading en pantalla principal.
                      Navigator.pop(dialogContext);
                      setState(() => _isLoading = true);

                      // Si es Edición: Borrar anteriores
                      if (group != null) {
                         for (final id in group.ids) {
                            await _appSettingsService.deleteNonAttendanceDay(_campusId!, id);
                         }
                      }

                      List<NonAttendanceDay> daysToSave = [];
                      DateTime current = selectedStartDate;
                      
                      final end = DateTime(selectedEndDate.year, selectedEndDate.month, selectedEndDate.day, 23, 59, 59);
                      
                      while (current.isBefore(end)) {
                        daysToSave.add(NonAttendanceDay(
                            id: DateFormat('yyyy-MM-dd').format(current),
                            campusId: _campusId!,
                            date: current,
                            reason: finalReason));
                        current = current.add(const Duration(days: 1));
                      }
                      
                      for (final d in daysToSave) {
                        await _appSettingsService.addNonAttendanceDay(d);
                      }
                      
                      if (mounted) {
                        UiHelpers.showSnackBar(
                            context, 
                            group == null ? 'Suspensión registrada exitosamente.' : 'Cambios guardados correctamente.',
                            isError: false); // Green snackbar
                      }
                      _loadNonAttendanceDays();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        UiHelpers.showSnackBar(context, 'Error al guardar: intente nuevamente.', isError: true);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                  ),
                  child: Text(group == null ? 'Registrar Evento' : 'Guardar Cambios'),
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
            firstDate: minDate ?? DateTime(2024),
            lastDate: DateTime(2030),
            locale: const Locale('es', 'MX'),
            helpText: 'SELECCIONAR FECHA DE $label');
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MMM/yyyy', 'es_MX').format(date).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNonAttendanceDayFormDialog(),
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Suspensión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // --- HEADER ---
                      FadeInDown(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark 
                                ? [const Color(0xFF424242), const Color(0xFF303030)]
                                : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.event_busy_rounded, color: Colors.deepOrange, size: 32),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calendario de Suspensiones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.deepOrange)),
                                    const SizedBox(height: 4),
                                    Text('Días inhábiles donde el sistema bloqueará automáticamente la toma de asistencia.', 
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.brown)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- LIST ---
                      Expanded(
                        child: _groupedDays.isEmpty
                            ? const Center(
                                child: Opacity(
                                  opacity: 0.6,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
                                      SizedBox(height: 16),
                                      Text('Sin suspensiones activas',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Text('Todos los días son lectivos actualmente.', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _groupedDays.length,
                                itemBuilder: (context, index) {
                                  final group = _groupedDays[index];
                                  final isRange = group.ids.length > 1;
                                  
                                  return FadeInUp(
                                    delay: Duration(milliseconds: 50 * (index > 6 ? 6 : index)),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: isDark ? theme.cardTheme.color : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                        border: Border(left: BorderSide(color: Colors.orange.shade400, width: 6)),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => _showNonAttendanceDayFormDialog(group: group),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            child: Row(
                                              children: [
                                                // FECHA BADGE
                                                Container(
                                                  width: 60,
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        DateFormat('d', 'es_MX').format(group.start),
                                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.orange.shade800, height: 1.0),
                                                      ),
                                                      Text(
                                                        DateFormat('MMM', 'es_MX').format(group.start).toUpperCase(),
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                
                                                // INFO
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(_reasonIcons[group.reason] ?? Icons.event_note_rounded, size: 18, color: Colors.orange.shade800),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              group.reason,
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Icon(isRange ? Icons.date_range : Icons.today, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            isRange 
                                                              ? 'Hasta el ${DateFormat('d ' 'MMMM', 'es_MX').format(group.end)} (${group.ids.length} días)'
                                                              : DateFormat('EEEE', 'es_MX').format(group.start).toUpperCase(),
                                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // ACTIONS
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                                      tooltip: 'Editar',
                                                      onPressed: () => _showNonAttendanceDayFormDialog(group: group),
                                                      color: Colors.blue,
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 20),
                                                      tooltip: 'Eliminar',
                                                      onPressed: () => _confirmDeleteGroup(group),
                                                      color: Colors.red,
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
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
    );
  }

  Future<void> _confirmDeleteGroup(_SuspensionGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Text(
          group.ids.length > 1 
            ? '¿Estás seguro de eliminar este periodo de ${group.ids.length} días? \n\nEsto rehabilitará la toma de asistencia para esas fechas.' 
            : '¿Estás seguro de eliminar este día de suspensión? \n\nLa asistencia se reactivará para esta fecha.',
          style: const TextStyle(fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );
        
    if (confirm == true && _campusId != null) {
      setState(() => _isLoading = true);
      // Eliminar uno por uno
      for (final id in group.ids) {
         await _appSettingsService.deleteNonAttendanceDay(_campusId!, id);
      }
      if (mounted) UiHelpers.showSnackBar(context, 'Suspensión eliminada correctamente.');
      _loadNonAttendanceDays();
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