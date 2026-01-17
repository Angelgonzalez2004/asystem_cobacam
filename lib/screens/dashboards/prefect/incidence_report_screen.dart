import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/incidence_excel_exporter.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class IncidenceReportScreen extends StatefulWidget {
  const IncidenceReportScreen({super.key});

  @override
  State<IncidenceReportScreen> createState() => _IncidenceReportScreenState();
}

class _IncidenceReportScreenState extends State<IncidenceReportScreen> {
  final TextEditingController _searchStudentController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _historyFilterController =
      TextEditingController();
  final TextEditingController _otherReasonController = TextEditingController();

  String? _selectedType;
  final List<String> _incidenceTypes = [
    'Uniforme Incompleto',
    'Cabello/Corte no permitido',
    'Uso de Celular sin autorización',
    'Falta de Respeto a Autoridad',
    'Daño a Mobiliario o Instalaciones',
    'Salida del Plantel sin Pase',
    'Retardo injustificado',
    'Incumplimiento de Tareas/Material',
    'Agresión Física o Verbal',
    'Robo o Extorsión',
    'Vandalismo o Grafiti',
    'Consumo de Sustancias Prohibidas',
    'Acoso Escolar (Bullying)',
    'Falsificación de Firmas/Documentos',
    'Interrupción de la Labor Docente',
    'Lenguaje Obsceno o Inapropiado',
    'Consumo de Alimentos en Aula',
    'Desobediencia a Instrucciones',
    'Copia en Examen o Plagio',
    'Riña o Connatos de Violencia',
    'Portación de Objetos Peligrosos',
    'Inasistencia Injustificada (Saltarse clases)',
    'Uso de Gorras o Lentes de Sol en Aula',
    'Otro'
  ];

  final Map<String, IconData> _incidenceIcons = {
    'Uniforme Incompleto': Icons.checkroom,
    'Cabello/Corte no permitido': Icons.face,
    'Uso de Celular sin autorización': Icons.phonelink_ring,
    'Falta de Respeto a Autoridad': Icons.sentiment_very_dissatisfied,
    'Daño a Mobiliario o Instalaciones': Icons.chair,
    'Salida del Plantel sin Pase': Icons.door_back_door,
    'Retardo injustificado': Icons.access_time,
    'Incumplimiento de Tareas/Material': Icons.assignment_late,
    'Agresión Física o Verbal': Icons.back_hand,
    'Robo o Extorsión': Icons.security,
    'Vandalismo o Grafiti': Icons.brush,
    'Consumo de Sustancias Prohibidas': Icons.smoke_free,
    'Acoso Escolar (Bullying)': Icons.groups_outlined,
    'Falsificación de Firmas/Documentos': Icons.description,
    'Interrupción de la Labor Docente': Icons.volume_up,
    'Lenguaje Obsceno o Inapropiado': Icons.record_voice_over,
    'Consumo de Alimentos en Aula': Icons.restaurant,
    'Desobediencia a Instrucciones': Icons.gavel,
    'Copia en Examen o Plagio': Icons.auto_fix_normal,
    'Riña o Connatos de Violencia': Icons.sports_kabaddi,
    'Portación de Objetos Peligrosos': Icons.priority_high,
    'Inasistencia Injustificada (Saltarse clases)': Icons.event_busy,
    'Uso de Gorras o Lentes de Sol en Aula': Icons.accessibility,
    'Otro': Icons.more_horiz,
  };

  Student? _selectedStudent;
  List<Student> _allStudents = [];
  List<Incidence> _allIncidents = [];
  Map<String, List<Incidence>> _groupedIncidents = {};

  List<SchoolCycle> _availableCycles = [];
  List<Group> _dbGroups = [];
  List<NonAttendanceDay> _nonAttendanceDays = [];

  bool _isLoading = false;
  String? _campus;

  String? _selectedCycle;
  String? _selectedGroupFilter = 'Todos';
  DateTime? _selectedDate;
  bool _showAllCycleHistory = false; // Toggle para ver todo el historial

  Incidence? _editingIncidence;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap =
            await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (snap.exists) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          _campus = data['campus'];
        }
      }

      final appSettings = AppSettingsService(
          Provider.of<HiveService>(context, listen: false),
          Provider.of<ConnectivityService>(context, listen: false));

      _availableCycles = await appSettings.getAllSchoolCycles();
      final currentCycle = await appSettings.getCurrentSchoolCycleId();
      _selectedCycle = currentCycle;

      if (_campus != null) {
        _nonAttendanceDays =
            await appSettings.getAllNonAttendanceDays(_campus!);
        await _loadGroups();
        await _loadStudents();
        _loadIncidentsHistory();
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    if (_selectedCycle == null || _campus == null) return;
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    final snap = await ref.get();
    if (snap.exists) {
      final List<Group> fetched = [];
      for (var child in snap.children) {
        final g = Group.fromSnapshot(child);
        if (g.schoolCycleId == _selectedCycle) fetched.add(g);
      }
      fetched.sort((a, b) => a.name.compareTo(b.name));
      setState(() => _dbGroups = fetched);
    } else {
      setState(() => _dbGroups = []);
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedCycle == null || _campus == null) return;
    final ref = FirebaseDatabase.instance
        .ref('planteles/$_campus/students/$_selectedCycle');
    final snap = await ref.get();
    if (snap.exists) {
      final List<Student> loaded = [];
      for (var child in snap.children) {
        final s = Student.fromSnapshot(child);
        if (s.isActive) loaded.add(s);
      }
      setState(() => _allStudents = loaded);
    } else {
      setState(() => _allStudents = []);
    }
  }

  void _loadIncidentsHistory() {
    if (_campus == null) return;
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
    ref.onValue.listen((event) {
      if (mounted) {
        final List<Incidence> loaded = [];
        if (event.snapshot.exists) {
          for (var child in event.snapshot.children) {
            final data = Map<String, dynamic>.from(child.value as Map);
            loaded.add(Incidence.fromFirebaseMap(child.key!, data));
          }
        }
        loaded.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _allIncidents = loaded;
          _filterAndGroupIncidents();
        });
      }
    });
  }

  void _filterAndGroupIncidents() {
    if (_selectedCycle == null) {
      setState(() => _groupedIncidents = {});
      return;
    }

    var temp = _allIncidents;
    // 1. Filtro Ciclo
    temp = temp.where((i) => i.schoolCycle == _selectedCycle).toList();

    // 2. Filtro Fecha (Solo si NO se ve todo el historial)
    if (!_showAllCycleHistory && _selectedDate != null) {
      temp = temp
          .where((i) =>
              i.date.year == _selectedDate!.year &&
              i.date.month == _selectedDate!.month &&
              i.date.day == _selectedDate!.day)
          .toList();
    }

    // 3. Filtro Búsqueda Texto
    final query = _historyFilterController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      temp = temp.where((i) {
        return i.studentName.toLowerCase().contains(query) ||
            i.studentId.contains(query);
      }).toList();
    } else {
      // 4. Filtro Grupo (Solo si no hay búsqueda por texto)
      if (_selectedGroupFilter != null && _selectedGroupFilter != 'Todos') {
        temp = temp.where((i) => i.group == _selectedGroupFilter).toList();
      }
    }

    final Map<String, List<Incidence>> grouped = {};
    for (var inc in temp) {
      if (!grouped.containsKey(inc.studentId)) {
        grouped[inc.studentId] = [];
      }
      grouped[inc.studentId]!.add(inc);
    }

    setState(() => _groupedIncidents = grouped);
  }

  void _prepareEdit(Incidence incidence) {
    setState(() {
      _editingIncidence = incidence;
      _descriptionController.text = incidence.description;
      if (incidence.type.startsWith('Otro:')) {
        _selectedType = 'Otro';
        _otherReasonController.text = incidence.type.substring(6).trim();
      } else {
        _selectedType = incidence.type;
        _otherReasonController.clear();
      }
      try {
        _selectedStudent =
            _allStudents.firstWhere((s) => s.studentId == incidence.studentId);
      } catch (_) {
        _selectedStudent = Student(
            id: incidence.studentId,
            fullName: incidence.studentName,
            guardianFullName: '',
            age: 0,
            guardianPhone: '',
            gender: '',
            placeOfResidence: '',
            schoolCycle: incidence.schoolCycle,
            group: incidence.group,
            institutionalEmail: '',
            studentId: incidence.studentId);
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIncidence = null;
      _selectedStudent = null;
      _selectedType = null;
      _searchStudentController.clear();
      _descriptionController.clear();
      _otherReasonController.clear();
    });
  }

  Future<void> _resolveIncidence(
      Incidence incidence, String reason, String details) async {
    setState(() => _isLoading = true);
    try {
      final updatedIncidence = Incidence(
        id: incidence.id,
        studentId: incidence.studentId,
        studentName: incidence.studentName,
        group: incidence.group,
        type: incidence.type,
        description: incidence.description,
        date: incidence.date,
        campusId: incidence.campusId,
        schoolCycle: incidence.schoolCycle,
        status: 'Solucionado',
        resolutionReason: reason,
        resolutionDetails: details,
        resolutionDate: DateTime.now(),
        isSynced: true,
      );

      await FirebaseDatabase.instance
          .ref('planteles/$_campus/incidents/${incidence.id}')
          .update(updatedIncidence.toFirebaseMap());

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Reporte marcado como solucionado.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al actualizar: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResolutionDialog(Incidence incidence) async {
    String selectedReason = 'Acuerdo con Tutor';
    final detailsCtrl = TextEditingController();
    final customReasonCtrl = TextEditingController();

    final reasons = [
      'Acuerdo con Tutor',
      'Justificado',
      'Error de Captura',
      'Conducta Corregida',
      'Carta Compromiso Firmada',
      'Suspensión Cumplida',
      'Servicio Comunitario',
      'Amonestación Verbal',
      'Otro'
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.green),
              SizedBox(width: 10),
              Text('Resolver Reporte')
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Este reporte pasará a estatus "Solucionado" y se archivará como evidencia.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                      labelText: 'Motivo de Resolución',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category)),
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v!),
                ),
                if (selectedReason == 'Otro') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Especifique el motivo...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note)),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Detalles / Acuerdos (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                String finalReason = selectedReason;
                if (selectedReason == 'Otro') {
                  if (customReasonCtrl.text.trim().isEmpty) {
                    UiHelpers.showSnackBar(
                        context, 'Especifique el motivo personalizado.',
                        isError: true);
                    return;
                  }
                  finalReason = "Otro: ${customReasonCtrl.text.trim()}";
                }

                Navigator.pop(context);
                _resolveIncidence(
                    incidence, finalReason, detailsCtrl.text.trim());
              },
              child: const Text('Confirmar Resolución'),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _deleteIncidence... REMOVED
  // Future<void> _confirmDelete... REMOVED

  Future<void> _exportExcel() async {
    String exportCycle = _selectedCycle ?? _availableCycles.first.id;
    String exportGroup = _selectedGroupFilter ?? 'Todos';
    DateTime exportDate = _selectedDate ?? DateTime.now();
    bool exportAllHistory = _showAllCycleHistory;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.file_download, color: Colors.blue),
            SizedBox(width: 10),
            Text('Exportar Reporte')
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: exportCycle,
                  decoration: const InputDecoration(
                      labelText: 'Ciclo', border: OutlineInputBorder()),
                  items: _availableCycles
                      .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 10),
                            Text(c.id)
                          ])))
                      .toList(),
                  onChanged: (val) => setStateDialog(() => exportCycle = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: exportGroup,
                  decoration: const InputDecoration(
                      labelText: 'Grupo', border: OutlineInputBorder()),
                  items: ['Todos', ..._dbGroups.map((g) => g.name)]
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setStateDialog(() => exportGroup = val!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Exportar todo el ciclo',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'Ignora la fecha y descarga el historial completo.',
                      style: TextStyle(fontSize: 11)),
                  value: exportAllHistory,
                  onChanged: (val) =>
                      setStateDialog(() => exportAllHistory = val),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!exportAllHistory) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final cObj = _availableCycles
                          .firstWhere((c) => c.id == exportCycle);

                      final start = DateTime(cObj.startDate.year,
                          cObj.startDate.month, cObj.startDate.day);
                      final end = DateTime(cObj.endDate.year,
                          cObj.endDate.month, cObj.endDate.day);

                      // Normalizar y buscar día válido inicial
                      DateTime initial = DateTime(
                          exportDate.year, exportDate.month, exportDate.day);
                      if (initial.isBefore(start)) initial = start;
                      if (initial.isAfter(end)) initial = end;

                      // Evitar crash si 'initial' cae en fin de semana/festivo
                      initial = _findNextValidDate(initial, end);

                      if (!_isDaySelectable(initial)) {
                        // Fallback extremo
                        initial = _findNextValidDate(start, end);
                      }

                      if (!_isDaySelectable(initial)) {
                        if (context.mounted) {
                          UiHelpers.showSnackBar(context,
                              'No hay días hábiles disponibles para seleccionar.',
                              isError: true);
                        }
                        return;
                      }

                      try {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: start,
                          lastDate: end,
                          locale: const Locale('es', 'MX'),
                          selectableDayPredicate: _isDaySelectable,
                        );
                        if (p != null) setStateDialog(() => exportDate = p);
                      } catch (e) {
                        // Fallback silencioso
                      }
                    },
                    child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha del Reporte',
                            border: OutlineInputBorder(),
                            isDense: true),
                        child:
                            Text(DateFormat('dd/MM/yyyy').format(exportDate))),
                  ),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar')),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processExport(
                      exportCycle, exportGroup, exportDate, exportAllHistory);
                },
                child: const Text('Exportar'))
          ],
        ),
      ),
    );
  }

  Future<void> _processExport(
      String cycle, String group, DateTime date, bool allHistory) async {
    if (mounted) UiHelpers.showSnackBar(context, 'Generando archivo...');

    List<Incidence> data = _allIncidents.where((i) {
      bool matchCycle = i.schoolCycle == cycle;
      bool matchGroup = group == 'Todos' || i.group == group;
      bool matchDate = allHistory
          ? true
          : (i.date.year == date.year &&
              i.date.month == date.month &&
              i.date.day == date.day);
      return matchCycle && matchGroup && matchDate;
    }).toList();

    List<String>? allGroups = (group == 'Todos' && cycle == _selectedCycle)
        ? _dbGroups.map((g) => g.name).toList()
        : null;

    String desc = allHistory
        ? 'Historial Completo - $cycle'
        : '$cycle - ${DateFormat('dd/MM/yyyy').format(date)}';

    try {
      await IncidenceExcelExporter.exportToExcel(
          incidents: data,
          students: _allStudents,
          campus: _campus ?? 'COBACAM',
          filterDescription: desc,
          specificGroupName: group == 'Todos' ? null : group,
          forceAllGroups: allGroups);
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  // Predicado centralizado para validar días (Usado por el calendario y la lógica)
  bool _isDaySelectable(DateTime day) {
    // 1. Bloquear fines de semana
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }
    // 2. Bloquear días inhábiles
    // Normalizar para comparar solo fechas sin hora
    return !_nonAttendanceDays.any((d) =>
        d.date.year == day.year &&
        d.date.month == day.month &&
        d.date.day == day.day);
  }

  // Busca el siguiente día hábil disponible a partir de una fecha
  DateTime _findNextValidDate(DateTime startDate, DateTime limitDate) {
    DateTime candidate = startDate;
    // Intentar hasta encontrar un día válido o llegar al límite
    while (candidate.isBefore(limitDate) ||
        candidate.isAtSameMomentAs(limitDate)) {
      if (_isDaySelectable(candidate)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    // Si no encuentra nada (raro), devuelve la original aunque falle, o la límite
    return startDate;
  }

  Future<void> _pickDate() async {
    SchoolCycle? cycle;
    try {
      cycle = _availableCycles.firstWhere((c) => c.id == _selectedCycle);
    } catch (_) {
      UiHelpers.showSnackBar(context, 'Selecciona un ciclo escolar primero.',
          isError: true);
      return;
    }

    // 1. Definir rango normalizado
    final start = DateTime(
        cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final end =
        DateTime(cycle.endDate.year, cycle.endDate.month, cycle.endDate.day);

    // 2. Definir candidata inicial (Hoy o Start)
    DateTime initial = _selectedDate != null
        ? DateTime(
            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day)
        : DateTime.now();
    initial = DateTime(initial.year, initial.month, initial.day); // Normalizar

    // 3. Clamping Básico (Rango)
    if (initial.isBefore(start)) initial = start;
    if (initial.isAfter(end)) initial = end;

    // 4. CORRECCIÓN CRÍTICA: Buscar siguiente día hábil
    // Si 'initial' cae en sábado/domingo/festivo, el calendario truena.
    // Avanzamos hasta encontrar un día válido.
    initial = _findNextValidDate(initial, end);

    // Si después de buscar, initial se salió del rango (ej. el ciclo termina en domingo y hoy es domingo),
    // retrocedemos buscando un día hábil hacia atrás.
    if (!_isDaySelectable(initial)) {
      // Fallback extremo: Si no hay días hábiles futuros, buscar el primer día hábil del ciclo desde el inicio
      initial = _findNextValidDate(start, end);
    }

    if (!_isDaySelectable(initial)) {
      if (mounted) {
        UiHelpers.showSnackBar(
            context, 'No hay días hábiles disponibles en este ciclo.',
            isError: true);
      }
      return;
    }

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: start,
        lastDate: end,
        locale: const Locale('es', 'MX'),
        helpText: 'SELECCIONAR FECHA HÁBIL',
        selectableDayPredicate: _isDaySelectable, // Usar el predicado robusto
      );

      if (picked != null) {
        setState(() => _selectedDate = picked);
        _filterAndGroupIncidents();
      }
    } catch (e) {
      debugPrint("Calendar Error: $e");
      // Si falla por localización o algo interno
      UiHelpers.showSnackBar(context,
          'No se pudo abrir el calendario. Verifica la configuración regional.',
          isError: true);
    }
  }

  // Actualizar también la validación simple
  bool _isDateValid(DateTime date) {
    return _isDaySelectable(date);
  }

  Future<void> _saveOrUpdateIncidence() async {
    if (_selectedCycle == null || _selectedDate == null) {
      UiHelpers.showSnackBar(context, 'Configura Ciclo y Fecha.',
          isError: true);
      return;
    }
    if (_selectedStudent == null && _editingIncidence == null) {
      UiHelpers.showSnackBar(context, 'Selecciona un alumno.', isError: true);
      return;
    }
    if (_selectedType == null) {
      UiHelpers.showSnackBar(context, 'Selecciona tipo de falta.',
          isError: true);
      return;
    }
    if (_selectedType == 'Otro' && _otherReasonController.text.isEmpty) {
      UiHelpers.showSnackBar(context, 'Especifique motivo.', isError: true);
      return;
    }

    final dateToSave = _editingIncidence?.date ?? _selectedDate!;
    final dateTimeToSave = DateTime(dateToSave.year, dateToSave.month,
        dateToSave.day, DateTime.now().hour, DateTime.now().minute);
    if (_editingIncidence == null && !_isDateValid(dateTimeToSave)) return;

    setState(() => _isLoading = true);
    try {
      final DatabaseReference ref;
      String id;
      final sId = _selectedStudent?.studentId ?? _editingIncidence!.studentId;
      final sName =
          _selectedStudent?.fullName ?? _editingIncidence!.studentName;
      final sGroup = _selectedStudent?.group ?? _editingIncidence!.group;
      String fType = _selectedType == 'Otro'
          ? 'Otro: ${_otherReasonController.text.trim()}'
          : _selectedType!;
      if (_editingIncidence != null) {
        id = _editingIncidence!.id;
        ref = FirebaseDatabase.instance.ref('planteles/$_campus/incidents/$id');
      } else {
        ref = FirebaseDatabase.instance
            .ref('planteles/$_campus/incidents')
            .push();
        id = ref.key!;
      }
      final incidence = Incidence(
          id: id,
          studentId: sId,
          studentName: sName,
          group: sGroup,
          schoolCycle: _selectedCycle!,
          type: fType,
          description: _descriptionController.text.trim(),
          date: dateTimeToSave,
          campusId: _campus!,
          isSynced: true);
      if (_editingIncidence != null) {
        await ref.update(incidence.toFirebaseMap());
      } else {
        await ref.set(incidence.toFirebaseMap());
      }
      UiHelpers.showSnackBar(context, 'Guardado con éxito.');
      _cancelEdit();
    } catch (e) {
      UiHelpers.showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isContextReady = _selectedCycle != null && _selectedDate != null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.settings_input_component,
                            size: 18, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('CONFIGURACIÓN DE REPORTE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))
                      ]),
                      if (isContextReady)
                        IconButton.filledTonal(
                            icon: const Icon(Icons.file_download_outlined,
                                size: 20),
                            onPressed: _exportExcel,
                            tooltip: 'Exportar Excel'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: _selectedCycle,
                            decoration: const InputDecoration(
                                labelText: 'Ciclo',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_month)),
                            items: _availableCycles
                                .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.id,
                                        style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCycle = val;
                                _selectedGroupFilter = 'Todos';
                                _loadGroups();
                                _loadStudents();
                              });
                            })),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: _selectedGroupFilter,
                            decoration: const InputDecoration(
                                labelText: 'Grupo',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.groups)),
                            items: [
                              const DropdownMenuItem(
                                  value: 'Todos', child: Text('Todos')),
                              ..._dbGroups.map((g) => DropdownMenuItem(
                                  value: g.name,
                                  child: Text(g.name,
                                      style: const TextStyle(fontSize: 12))))
                            ],
                            onChanged: (val) {
                              setState(() => _selectedGroupFilter = val);
                              _filterAndGroupIncidents();
                            })),
                    const SizedBox(width: 8),
                    Expanded(
                        child: InkWell(
                            onTap: _showAllCycleHistory ? null : _pickDate,
                            child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: _showAllCycleHistory
                                        ? 'Fecha (Ignorada)'
                                        : 'Fecha',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    fillColor: _showAllCycleHistory
                                        ? Colors.grey.shade200
                                        : null,
                                    filled: _showAllCycleHistory,
                                    prefixIcon: const Icon(Icons.today)),
                                child: Text(
                                    _selectedDate != null
                                        ? DateFormat('dd/MM')
                                            .format(_selectedDate!)
                                        : '-',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _showAllCycleHistory
                                            ? Colors.grey
                                            : null))))),
                  ]),
                  Row(children: [
                    Checkbox(
                        value: _showAllCycleHistory,
                        onChanged: (v) => setState(() {
                              _showAllCycleHistory = v!;
                              _filterAndGroupIncidents();
                            })),
                    const Text('Ver historial completo del ciclo',
                        style: TextStyle(fontSize: 12))
                  ])
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isContextReady)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Selecciona Ciclo y Fecha para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey))
                ]))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FadeInDown(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              if (_editingIncidence != null)
                                Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                        'Editando a: ${_editingIncidence!.studentName}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange))),
                              Autocomplete<Student>(
                                displayStringForOption: (s) =>
                                    '${s.fullName} (${s.group})',
                                optionsBuilder: (text) {
                                  if (text.text.isEmpty) {
                                    return const Iterable<Student>.empty();
                                  }
                                  return _allStudents.where((s) =>
                                      s.fullName
                                          .toLowerCase()
                                          .contains(text.text.toLowerCase()) ||
                                      s.studentId.contains(text.text));
                                },
                                onSelected: (s) =>
                                    setState(() => _selectedStudent = s),
                                fieldViewBuilder: (ctx, ctrl, node, onComp) =>
                                    TextField(
                                  controller: ctrl,
                                  focusNode: node,
                                  decoration: InputDecoration(
                                      labelText:
                                          'Buscar Alumno (Nombre o Matrícula)',
                                      prefixIcon:
                                          const Icon(Icons.person_search),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      hintText:
                                          'Detecta grupo automáticamente'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _selectedType,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: 'Falta',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    prefixIcon:
                                        const Icon(Icons.warning_amber)),
                                items: _incidenceTypes
                                    .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Row(children: [
                                          Icon(
                                              _incidenceIcons[t] ??
                                                  Icons.warning,
                                              size: 18,
                                              color: theme.primaryColor),
                                          const SizedBox(width: 8),
                                          Text(t,
                                              style:
                                                  const TextStyle(fontSize: 13))
                                        ])))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedType = v),
                              ),
                              if (_selectedType == 'Otro') ...[
                                const SizedBox(height: 12),
                                TextField(
                                    controller: _otherReasonController,
                                    decoration: const InputDecoration(
                                        labelText: 'Especifique motivo',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.edit)))
                              ],
                              const SizedBox(height: 12),
                              TextField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                      labelText: 'Observaciones (Recomendado)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.comment))),
                              const SizedBox(height: 16),
                              SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _saveOrUpdateIncidence,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _editingIncidence != null
                                                  ? Colors.orange
                                                  : theme.primaryColor,
                                          foregroundColor: Colors.white),
                                      child: Text(_editingIncidence != null
                                          ? 'Guardar Cambios'
                                          : 'Registrar Incidencia'))),
                              if (_editingIncidence != null)
                                TextButton(
                                    onPressed: _cancelEdit,
                                    child: const Text('Cancelar'))
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                        controller: _historyFilterController,
                        decoration: InputDecoration(
                            hintText:
                                'Filtrar historial (Nombre o Matrícula)...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none)),
                        onChanged: (_) => _filterAndGroupIncidents()),
                    const SizedBox(height: 16),
                    if (_groupedIncidents.isEmpty)
                      const Text('No hay resultados para esta consulta.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _groupedIncidents.length,
                        itemBuilder: (ctx, i) {
                          final id = _groupedIncidents.keys.elementAt(i);
                          final incs = _groupedIncidents[id]!;
                          Student? s;
                          try {
                            s = _allStudents
                                .firstWhere((st) => st.studentId == id);
                          } catch (_) {}
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(incs.first.studentName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Matrícula: $id • Grupo ${incs.first.group} • ${incs.length} reportes'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _infoRow('NSS:', s?.nss ?? '-'),
                                      Row(children: [
                                        Expanded(
                                            child: _infoRow(
                                                'Edad:', '${s?.age ?? 0}')),
                                        Expanded(
                                            child: _infoRow(
                                                'Género:', s?.gender ?? '-'))
                                      ]),
                                      _infoRow('Domicilio:',
                                          s?.placeOfResidence ?? '-'),
                                      _infoRow('Correo:',
                                          s?.institutionalEmail ?? '-'),
                                      const SizedBox(height: 4),
                                      _infoRow(
                                          'Tutor:', s?.guardianFullName ?? '-'),
                                      Row(children: [
                                        Expanded(
                                            child: _infoRow('Tel. Tutor:',
                                                s?.guardianPhone ?? '-')),
                                        Expanded(
                                            child: _infoRow('Tel. Alumno:',
                                                s?.studentPhone ?? '-'))
                                      ]),
                                      const Divider(height: 24),
                                      const Text('INFORMACIÓN MÉDICA',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                              color: Colors.blueGrey)),
                                      const SizedBox(height: 4),
                                      Builder(builder: (context) {
                                        final allergies = s?.allergies;
                                        if (allergies != null &&
                                            allergies.isNotEmpty) {
                                          return Row(children: [
                                            const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                                child: _infoRow(
                                                    'Alergias:', allergies))
                                          ]);
                                        }
                                        return _infoRow('Alergias:', 'Ninguna');
                                      }),
                                      Builder(builder: (context) {
                                        final conditions = s?.healthConditions;
                                        if (conditions != null &&
                                            conditions.isNotEmpty) {
                                          return Row(children: [
                                            const Icon(Icons.health_and_safety,
                                                color: Colors.blue, size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                                child: _infoRow(
                                                    'Condiciones:', conditions))
                                          ]);
                                        }
                                        return _infoRow(
                                            'Condiciones:', 'Ninguna');
                                      }),
                                      _infoRow('Estado General:',
                                          s?.generalHealthStatus ?? 'Sano'),
                                      const Divider(),
                                      ...incs.map((inc) {
                                        final isSolved =
                                            inc.status == 'Solucionado';
                                        final dateResolvedStr =
                                            inc.resolutionDate != null
                                                ? DateFormat('dd/MM HH:mm')
                                                    .format(inc.resolutionDate!)
                                                : '';
                                        return ListTile(
                                          title: Row(
                                            children: [
                                              Expanded(
                                                  child: Text(inc.type,
                                                      style: TextStyle(
                                                          decoration: isSolved
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                          color: isSolved
                                                              ? Colors.grey
                                                              : null))),
                                              if (isSolved)
                                                const Chip(
                                                    label: Text('Solucionado',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                Colors.white)),
                                                    backgroundColor:
                                                        Colors.green,
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity.compact),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(DateFormat('dd/MM HH:mm')
                                                  .format(inc.date)),
                                              if (inc.description.isNotEmpty)
                                                Text(inc.description,
                                                    style: const TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        fontSize: 12)),
                                              if (isSolved)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 4),
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                          color: Colors
                                                              .green.shade200)),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          '✅ ${inc.resolutionReason}',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .green)),
                                                      if (inc.resolutionDetails !=
                                                              null &&
                                                          inc.resolutionDetails!
                                                              .isNotEmpty)
                                                        Text(
                                                            '📝 ${inc.resolutionDetails}',
                                                            style: const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .black87)),
                                                      Text(
                                                          '📅 $dateResolvedStr',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .grey)),
                                                    ],
                                                  ),
                                                )
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!isSolved)
                                                IconButton(
                                                    icon: const Icon(Icons.edit,
                                                        size: 18),
                                                    onPressed: () =>
                                                        _prepareEdit(inc)),
                                              IconButton(
                                                icon: Icon(
                                                    isSolved
                                                        ? Icons.lock_outline
                                                        : Icons.delete_forever,
                                                    size: 18,
                                                    color: isSolved
                                                        ? Colors.grey
                                                        : Colors.red),
                                                tooltip: isSolved
                                                    ? 'Reporte cerrado'
                                                    : 'Resolver / Archivar',
                                                onPressed: isSolved
                                                    ? null
                                                    : () =>
                                                        _showResolutionDialog(
                                                            inc),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Row(children: [
        Text('$l ',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11)),
        Text(v, style: const TextStyle(fontSize: 11))
      ]);
}
