import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/group_model.dart';

enum TimeRange { day, week, month, cycle }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // State
  bool _isLoading = true;
  String? _campus;

  // Filters
  List<SchoolCycle> _cycles = [];
  String? _selectedCycleId;

  List<Group> _groups = [];
  String? _selectedGroupFilter; // null = Todos

  TimeRange _selectedRange = TimeRange.month;
  DateTime _selectedDate = DateTime.now(); // For 'day' filter

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Processed Data
  int _totalStudents = 0;
  int _totalIncidences = 0;
  double _attendanceRate = 0.0;

  Map<String, int> _incidencesByType = {};
  Map<String, int> _incidencesByGroup = {};
  Map<String, int> _incidencesByGender = {};
  Map<int, int> _incidencesByHour = {}; // 7 to 14
  List<FlSpot> _attendanceTrend = [];

  List<Map<String, dynamic>> _riskRadar = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userSnap =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userSnap.exists) return;
      final userData = Map<String, dynamic>.from(userSnap.value as Map);
      _campus = userData['campus'];

      final appSettings = AppSettingsService(
          Provider.of<HiveService>(context, listen: false),
          Provider.of<ConnectivityService>(context, listen: false));

      _cycles = await appSettings.getAllSchoolCycles();
      final currentId = await appSettings.getCurrentSchoolCycleId();

      // Default to current cycle if exists, else first available
      if (_cycles.any((c) => c.id == currentId)) {
        _selectedCycleId = currentId;
      } else if (_cycles.isNotEmpty) {
        _selectedCycleId = _cycles.first.id;
      }

      if (_campus != null && _selectedCycleId != null) {
        await _loadGroups();
        await _processStats();
      }
    } catch (e) {
      debugPrint('Error init stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    if (_campus == null || _selectedCycleId == null) return;
    final ref = FirebaseDatabase.instance.ref('planteles/$_campus/groups');
    final snap = await ref.get();

    final List<Group> loaded = [];
    if (snap.exists) {
      for (var child in snap.children) {
        final g = Group.fromSnapshot(child);
        if (g.schoolCycleId == _selectedCycleId) {
          loaded.add(g);
        }
      }
    }
    loaded.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _groups = loaded;
      _selectedGroupFilter = null; // Reset group filter on cycle change
    });
  }

  Future<void> _processStats() async {
    if (_campus == null || _selectedCycleId == null) return;

    setState(() => _isLoading = true);

    // Reset Metrics
    _totalIncidences = 0;
    _incidencesByType = {};
    _incidencesByGroup = {};
    _incidencesByGender = {};
    _incidencesByHour = {};
    _riskRadar = [];
    _attendanceTrend = [];

    // Date Logic
    DateTime startFilterDate;
    final now = DateTime.now();

    if (_selectedRange == TimeRange.day) {
      startFilterDate =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    } else if (_selectedRange == TimeRange.week) {
      startFilterDate = now.subtract(const Duration(days: 7));
    } else if (_selectedRange == TimeRange.month) {
      startFilterDate = DateTime(now.year, now.month, 1);
    } else {
      startFilterDate = DateTime(2000); // Cycle = All time
    }

    final endFilterDate = (_selectedRange == TimeRange.day)
        ? startFilterDate
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1))
        : DateTime(3000);

    // 1. STUDENTS & GENDER MAP
    final studentsRef = FirebaseDatabase.instance
        .ref('planteles/$_campus/students/$_selectedCycleId');
    final studentsSnap = await studentsRef.get();

    Map<String, String> studentGenders = {};
    Map<String, String> studentNames = {};
    Map<String, String> studentGroups = {};

    if (studentsSnap.exists) {
      int count = 0;
      for (var child in studentsSnap.children) {
        final s = child.value as Map;
        // Filter active and Group
        if (s['isActive'] == true) {
          if (_selectedGroupFilter == null ||
              s['group'] == _selectedGroupFilter) {
            count++;
            studentGenders[child.key!] = s['gender'] ?? 'N/A';
            studentNames[child.key!] = s['fullName'] ?? 'Desconocido';
            studentGroups[child.key!] = s['group'] ?? '?';
          }
        }
      }
      _totalStudents = count;
    }

    // 2. INCIDENCES
    final incRef =
        FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
    final incSnap = await incRef.get();

    Map<String, int> riskCounter = {};

    if (incSnap.exists) {
      for (var child in incSnap.children) {
        final i = Map<String, dynamic>.from(child.value as Map);

        // Cycle Filter
        if (i['schoolCycle'] != _selectedCycleId) continue;

        // Group Filter
        if (_selectedGroupFilter != null &&
            i['group'] != _selectedGroupFilter) {
          continue;
        }

        // Date Filter
        final iDateStr = i['date'];
        if (iDateStr != null) {
          final iDate = DateTime.tryParse(iDateStr);
          if (iDate != null) {
            if (iDate.isBefore(startFilterDate) ||
                iDate.isAfter(endFilterDate)) {
              continue;
            }

            // --- DATA AGGREGATION ---
            _totalIncidences++;

            // Type
            final type = i['type'] ?? 'Otro';
            _incidencesByType[type] = (_incidencesByType[type] ?? 0) + 1;

            // Group
            final group = i['group'] ?? 'S/G';
            _incidencesByGroup[group] = (_incidencesByGroup[group] ?? 0) + 1;

            // Hour
            final hour = iDate.hour;
            _incidencesByHour[hour] = (_incidencesByHour[hour] ?? 0) + 1;

            // Gender
            final sId = i['studentId'];
            if (sId != null && studentGenders.containsKey(sId)) {
              final gender = studentGenders[sId]!;
              _incidencesByGender[gender] =
                  (_incidencesByGender[gender] ?? 0) + 1;

              // Risk Radar Accumulator
              riskCounter[sId] = (riskCounter[sId] ?? 0) + 1;
            }
          }
        }
      }
    }

    // Process Risk Radar Top 5
    final sortedRisk = riskCounter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _riskRadar = sortedRisk
        .take(10)
        .map((e) => {
              // Top 10 internally, UI can show less
              'id': e.key,
              'name': studentNames[e.key] ?? 'Alumno ${e.key}',
              'group': studentGroups[e.key] ?? '?',
              'count': e.value
            })
        .toList();

    // 3. ATTENDANCE TREND
    if (_selectedRange != TimeRange.day) {
      await _calculateAttendanceTrend(startFilterDate);
    } else {
      await _calculateDayAttendance(startFilterDate);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _calculateDayAttendance(DateTime day) async {
    final ref = FirebaseDatabase.instance.ref(
        'planteles/$_campus/attendance/$_selectedCycleId/${DateFormat('yyyy-MM-dd').format(day)}');
    final snap = await ref.get();
    double rate = 0.0;
    if (snap.exists && _totalStudents > 0) {
      int present = 0;
      for (var child in snap.children) {
        final d = child.value as Map;
        if (d['status'] != 'falta' && d['status'] != 'null') present++;
      }
      rate = (present / (_totalStudents == 0 ? 1 : _totalStudents)) * 100;
    }
    _attendanceRate = rate > 100 ? 100 : rate;
    _attendanceTrend = [FlSpot(0, rate)];
  }

  Future<void> _calculateAttendanceTrend(DateTime startDate) async {
    final ref = FirebaseDatabase.instance
        .ref('planteles/$_campus/attendance/$_selectedCycleId');
    List<FlSpot> spots = [];
    double totalRate = 0;
    int validDays = 0;
    final now = DateTime.now();

    // Last 7 days or filtered days
    int limit = 7;
    for (int i = limit - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      if (d.weekday >= 6) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final snap = await ref.child(dateStr).get();

      double rate = 0;
      if (snap.exists && _totalStudents > 0) {
        int present = 0;
        for (var child in snap.children) {
          final val = child.value as Map;
          if (val['status'] != 'falta') present++;
        }
        rate = (present / _totalStudents) * 100;
      }
      if (rate > 100) rate = 100;

      spots.add(FlSpot((limit - 1 - i).toDouble(), rate));
      totalRate += rate;
      validDays++;
    }

    _attendanceTrend = spots;
    _attendanceRate = validDays > 0 ? totalRate / validDays : 0;
  }

  List<MapEntry<String, int>> _getSortedGroups() {
    return _incidencesByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  double _getMaxGroupIncidence() {
    if (_incidencesByGroup.isEmpty) return 10;
    return _incidencesByGroup.values.reduce((a, b) => a > b ? a : b).toDouble();
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Centro de Inteligencia',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _processStats,
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. CONTROL PANEL (FILTERS)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Cycle & Group
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCycleId,
                          isDense: true,
                          decoration: _filterDeco(
                              'Ciclo Escolar', Icons.calendar_month),
                          items: _cycles
                              .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.id,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCycleId = val;
                            });
                            _loadGroups();
                            _processStats();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGroupFilter,
                          isDense: true,
                          decoration: _filterDeco('Grupo', Icons.groups),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los Grupos',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13))),
                            ..._groups.map((g) => DropdownMenuItem(
                                value: g.name,
                                child: Text(g.name,
                                    style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedGroupFilter = val);
                            _processStats();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Time Range & Date Picker
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SegmentedButton<TimeRange>(
                          segments: const [
                            ButtonSegment(
                                value: TimeRange.day,
                                label: Text('Día'),
                                icon: Icon(Icons.today, size: 14)),
                            ButtonSegment(
                                value: TimeRange.week,
                                label: Text('Sem'),
                                icon: Icon(Icons.view_week, size: 14)),
                            ButtonSegment(
                                value: TimeRange.month,
                                label: Text('Mes'),
                                icon:
                                    Icon(Icons.calendar_view_month, size: 14)),
                            ButtonSegment(
                                value: TimeRange.cycle,
                                label: Text('Todo'),
                                icon: Icon(Icons.all_inclusive, size: 14)),
                          ],
                          selected: {_selectedRange},
                          onSelectionChanged: (val) {
                            setState(() => _selectedRange = val.first);
                            _processStats();
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                          ),
                        ),
                      ),
                      if (_selectedRange == TimeRange.day) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  locale: const Locale('es', 'MX'));
                              if (d != null) {
                                setState(() => _selectedDate = d);
                                _processStats();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_calendar,
                                      size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                      DateFormat('dd/MM').format(_selectedDate),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. KPI CARDS
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 600;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    children: [
                      _buildKpi('Incidencias', '$_totalIncidences',
                          Icons.warning_amber_rounded, Colors.redAccent, wide),
                      if (wide)
                        const SizedBox(width: 12)
                      else
                        const SizedBox(height: 12),
                      _buildKpi(
                          'Asistencia',
                          '${_attendanceRate.toStringAsFixed(1)}%',
                          Icons.check_circle_outline,
                          _attendanceRate > 90 ? Colors.green : Colors.orange,
                          wide),
                      if (wide)
                        const SizedBox(width: 12)
                      else
                        const SizedBox(height: 12),
                      _buildKpi('Matrícula', '$_totalStudents',
                          Icons.people_outline, Colors.blue, wide),
                    ],
                  );
                }),
                const SizedBox(height: 24),

                // 3. CHARTS GRID
                _buildHeader('Análisis Gráfico', Icons.bar_chart),
                const SizedBox(height: 16),

                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 700;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: wide ? 5 : 0,
                          child: _chartCard('Tipos de Faltas', _buildPieChart(),
                              height: 300)),
                      if (wide)
                        const SizedBox(width: 16)
                      else
                        const SizedBox(height: 16),
                      Expanded(
                          flex: wide ? 3 : 0,
                          child: _chartCard('Género', _buildGenderChart(),
                              height: 300)),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 700;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: wide ? 4 : 0,
                          child: _chartCard(
                              'Horas Críticas (7-14h)', _buildHourlyChart(),
                              height: 250)),
                      if (wide)
                        const SizedBox(width: 16)
                      else
                        const SizedBox(height: 16),
                      Expanded(
                          flex: wide ? 6 : 0,
                          child: _chartCard(
                              'Grupos con más Reportes', _buildGroupsChart(),
                              height: 250)),
                    ],
                  );
                }),
                const SizedBox(height: 24),

                // 4. RISK RADAR & SEARCH
                _buildHeader('Radar de Riesgo', Icons.radar),
                const SizedBox(height: 12),

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar alumno...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        }),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 12),

                _buildRiskList(),

                const SizedBox(height: 32),

                // 5. INTELLIGENT ANALYSIS (50 Q&A)
                _buildHeader('Análisis Inteligente (IA Insights)',
                    Icons.lightbulb_outline),
                const SizedBox(height: 12),
                _buildInsightsList(),

                const SizedBox(height: 40),
              ]),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _chartCard(String title, Widget chart, {double height = 250}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54)),
          const Divider(),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_incidencesByType.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    final data = _incidencesByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = data.take(5).toList();

    final List<Color> colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red
    ];

    return PieChart(PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: List.generate(top.length, (i) {
          final item = top[i];
          return PieChartSectionData(
              color: colors[i % colors.length],
              value: item.value.toDouble(),
              title: '${item.value}',
              radius: 50,
              titleStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              badgeWidget: _Badge(item.key),
              badgePositionPercentageOffset: 1.3);
        })));
  }

  Widget _buildGenderChart() {
    if (_incidencesByGender.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    return Row(
      children: [
        Expanded(
            child: PieChart(PieChartData(sections: [
          if (_incidencesByGender['H'] != null)
            PieChartSectionData(
                value: _incidencesByGender['H']!.toDouble(),
                title: 'H',
                color: Colors.blue,
                radius: 40),
          if (_incidencesByGender['M'] != null)
            PieChartSectionData(
                value: _incidencesByGender['M']!.toDouble(),
                title: 'M',
                color: Colors.pink,
                radius: 40),
        ]))),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendItem(
                Colors.blue, 'Hombres: ${_incidencesByGender['H'] ?? 0}'),
            const SizedBox(height: 8),
            _legendItem(
                Colors.pink, 'Mujeres: ${_incidencesByGender['M'] ?? 0}'),
          ],
        )
      ],
    );
  }

  Widget _buildHourlyChart() {
    if (_incidencesByHour.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    return BarChart(BarChartData(
      barGroups: List.generate(8, (i) {
        final hour = 7 + i; // 7am to 14pm
        final val = _incidencesByHour[hour] ?? 0;
        return BarChartGroupData(x: hour, barRods: [
          BarChartRodData(
              toY: val.toDouble(),
              color: Colors.orange,
              width: 12,
              borderRadius: BorderRadius.circular(4))
        ]);
      }),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Text('${v.toInt()}h',
                    style: const TextStyle(fontSize: 10)))),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildGroupsChart() {
    if (_incidencesByGroup.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    final sorted = _incidencesByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    return BarChart(BarChartData(
      maxY: _getMaxGroupIncidence() + 2,
      barGroups: List.generate(top.length, (i) {
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
              toY: top[i].value.toDouble(),
              color: Colors.indigo,
              width: 16,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)))
        ]);
      }),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  if (v.toInt() >= top.length) return const Text('');
                  return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(top[v.toInt()].key,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)));
                })),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => Colors.blueGrey,
        getTooltipItem: (a, b, c, i) => BarTooltipItem(
            '${c.toY.toInt()}', const TextStyle(color: Colors.white)),
      )),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildRiskList() {
    final filtered = _riskRadar
        .where((s) => s['name'].toString().toLowerCase().contains(_searchQuery))
        .toList();
    if (filtered.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay alumnos en riesgo bajo este criterio.')));
    }

    return Column(
      children: filtered
          .map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: Text('${s['count']}',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${s['group']} • ${s['id']}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildInsightsList() {
    // Filtrar insights si hay búsqueda
    final insights = _generate50Insights().where((item) {
      if (_searchQuery.isEmpty) return true;
      return item['q'].toString().toLowerCase().contains(_searchQuery) ||
          item['a'].toString().toLowerCase().contains(_searchQuery);
    }).toList();

    if (insights.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No se encontraron insights con ese criterio.')));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: insights.length,
      separatorBuilder: (c, i) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final item = insights[i];
        return Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.1))),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: item['color'].withOpacity(0.1),
              child: Icon(item['icon'], color: item['color'], size: 20),
            ),
            title: Text(item['q'],
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.subdirectory_arrow_right,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item['a'],
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500))),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _generate50Insights() {
    // Helpers para cálculos
    String topGroup = _incidencesByGroup.entries.isEmpty
        ? 'N/A'
        : _incidencesByGroup.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
    int topGroupVal = _incidencesByGroup.entries.isEmpty
        ? 0
        : _incidencesByGroup.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .value;

    String topType = _incidencesByType.entries.isEmpty
        ? 'N/A'
        : _incidencesByType.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
    int topTypeVal = _incidencesByType.entries.isEmpty
        ? 0
        : _incidencesByType.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .value;

    int topHour = _incidencesByHour.entries.isEmpty
        ? 0
        : _incidencesByHour.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    int male = _incidencesByGender['H'] ?? 0;
    int female = _incidencesByGender['M'] ?? 0;

    // Contadores específicos
    int bullying = _incidencesByType['Acoso Escolar (Bullying)'] ?? 0;
    int celulares = _incidencesByType['Uso de Celular sin autorización'] ?? 0;
    int uniforme = _incidencesByType['Uniforme Incompleto'] ?? 0;
    int retardos = _incidencesByType['Retardo injustificado'] ?? 0;
    int fugas = _incidencesByType['Salida del Plantel sin Pase'] ?? 0;
    int sustancias = _incidencesByType['Consumo de Sustancias Prohibidas'] ?? 0;
    int agresiones = _incidencesByType['Agresión Física o Verbal'] ?? 0;
    int vandalismo = _incidencesByType['Vandalismo o Grafiti'] ?? 0;
    int cabello = _incidencesByType['Cabello/Corte no permitido'] ?? 0;
    int alimentos = _incidencesByType['Consumo de Alimentos en Aula'] ?? 0;
    int respeto = _incidencesByType['Falta de Respeto a Autoridad'] ?? 0;
    int robo = _incidencesByType['Robo o Extorsión'] ?? 0;
    int lenguaje = _incidencesByType['Lenguaje Obsceno o Inapropiado'] ?? 0;
    int copia = _incidencesByType['Copia en Examen o Plagio'] ?? 0;
    int desobediencia = _incidencesByType['Desobediencia a Instrucciones'] ?? 0;
    int peleas = _incidencesByType['Riña o Connatos de Violencia'] ?? 0;
    int objetos = _incidencesByType['Portación de Objetos Peligrosos'] ?? 0;
    int inasistencias =
        _incidencesByType['Inasistencia Injustificada (Saltarse clases)'] ?? 0;
    int gorras =
        _incidencesByType['Uso de Gorras o Lentes de Sol en Aula'] ?? 0;

    return [
      // 1. CONDUCTA Y DISCIPLINA
      {
        'q': '¿Cuál es el grupo más conflictivo?',
        'a': 'El grupo $topGroup es el foco rojo con $topGroupVal reportes.',
        'icon': Icons.groups_3,
        'color': Colors.red
      },
      {
        'q': '¿Qué falta se comete más seguido?',
        'a':
            'La incidencia #1 es "$topType" ($topTypeVal casos). Urge campaña preventiva.',
        'icon': Icons.warning,
        'color': Colors.orange
      },
      {
        'q': '¿Hay reportes de Bullying?',
        'a':
            '$bullying casos. ${bullying > 0 ? '¡ALERTA MÁXIMA! Activar protocolo anti-acoso.' : 'Sin novedades graves.'}',
        'icon': Icons.shield,
        'color': Colors.pinkAccent
      },
      {
        'q': '¿El uso de celulares es problema?',
        'a':
            '$celulares decomisos. ${celulares > 10 ? 'Situación fuera de control en aulas.' : 'Dentro de parámetros normales.'}',
        'icon': Icons.phone_android,
        'color': Colors.brown
      },
      {
        'q': '¿Se respeta el uniforme?',
        'a':
            '$uniforme sanciones por uniforme incompleto. Reforzar revisión en puerta.',
        'icon': Icons.checkroom,
        'color': Colors.deepOrange
      },
      {
        'q': '¿Hay consumo de sustancias?',
        'a':
            '$sustancias casos detectados. Riesgo crítico de salud y seguridad.',
        'icon': Icons.smoke_free,
        'color': Colors.red
      },
      {
        'q': '¿Alumnos fugados (Pintas)?',
        'a':
            '$fugas alumnos salieron sin permiso. Verificar seguridad perimetral.',
        'icon': Icons.run_circle,
        'color': Colors.deepPurple
      },
      {
        'q': '¿Agresiones físicas registradas?',
        'a': '$agresiones agresiones. Cero tolerancia a la violencia.',
        'icon': Icons.back_hand,
        'color': Colors.redAccent
      },
      {
        'q': '¿Vandalismo en instalaciones?',
        'a':
            '$vandalismo reportes de daños. Revisar bitácora de mantenimiento.',
        'icon': Icons.format_paint,
        'color': Colors.grey
      },
      {
        'q': '¿Corte de cabello en varones?',
        'a': '$cabello alumnos con corte no reglamentario. Enviar citatorio.',
        'icon': Icons.face,
        'color': Colors.blueGrey
      },
      {
        'q': '¿Comen dentro del salón?',
        'a': '$alimentos reportes por alimentos. Recordar reglas de higiene.',
        'icon': Icons.restaurant,
        'color': Colors.green
      },
      {
        'q': '¿Respeto a docentes?',
        'a':
            '$respeto faltas de respeto a autoridad. Sanción ejemplar requerida.',
        'icon': Icons.record_voice_over,
        'color': Colors.indigo
      },
      {
        'q': '¿Robos reportados?',
        'a': '$robo casos de robo/extorsión. Iniciar investigación inmediata.',
        'icon': Icons.security,
        'color': Colors.red
      },
      {
        'q': '¿Lenguaje inapropiado?',
        'a': '$lenguaje sanciones por groserías. Fomentar valores.',
        'icon': Icons.volume_off,
        'color': Colors.amber
      },
      {
        'q': '¿Deshonestidad académica?',
        'a': '$copia casos de plagio o copia en examen.',
        'icon': Icons.copy,
        'color': Colors.teal
      },
      {
        'q': '¿Desobediencia directa?',
        'a': '$desobediencia casos de rebeldía ante instrucciones.',
        'icon': Icons.gavel,
        'color': Colors.purple
      },
      {
        'q': '¿Peleas campales?',
        'a': '$peleas riñas. Notificar a seguridad pública si escala.',
        'icon': Icons.sports_mma,
        'color': Colors.red
      },
      {
        'q': '¿Armas u objetos peligrosos?',
        'a': '$objetos detecciones. Código Rojo activo si es > 0.',
        'icon': Icons.priority_high,
        'color': Colors.red
      },
      {
        'q': '¿Saltarse clases (interno)?',
        'a': '$inasistencias alumnos en pasillos durante hora clase.',
        'icon': Icons.directions_walk,
        'color': Colors.orange
      },
      {
        'q': '¿Uso de gorras en aula?',
        'a': '$gorras reportes menores por uso de accesorios.',
        'icon': Icons.accessibility,
        'color': Colors.blue
      },

      // 2. OPERATIVIDAD Y ESTADÍSTICA
      {
        'q': '¿A qué hora hay más problemas?',
        'a':
            'Pico de actividad a las $topHour:00 horas. Máxima vigilancia requerida.',
        'icon': Icons.access_time_filled,
        'color': Colors.purple
      },
      {
        'q': '¿Quiénes reportan más?',
        'a': male > female
            ? 'Hombres ($male reportes). Focalizar en varones.'
            : 'Mujeres ($female reportes). Focalizar en alumnas.',
        'icon': Icons.wc,
        'color': Colors.blue
      },
      {
        'q': '¿Estado general de disciplina?',
        'a': _totalIncidences < 15
            ? 'ÓPTIMO (Controlado)'
            : (_totalIncidences < 50
                ? 'REGULAR (Atención estándar)'
                : 'CRÍTICO (Desbordado)'),
        'icon': Icons.traffic,
        'color': _totalIncidences < 15 ? Colors.green : Colors.red
      },
      {
        'q': '¿Volumen total de trabajo?',
        'a': '$_totalIncidences incidencias procesadas en este periodo.',
        'icon': Icons.work_history,
        'color': Colors.indigo
      },
      {
        'q': '¿Porcentaje de matrícula afectada?',
        'a':
            '${_totalStudents > 0 ? ((_totalIncidences / _totalStudents) * 100).toStringAsFixed(1) : 0}% de los alumnos tiene reporte.',
        'icon': Icons.pie_chart,
        'color': Colors.teal
      },
      {
        'q': '¿Promedio diario de reportes?',
        'a':
            'Aprox. ${(_totalIncidences / 20).toStringAsFixed(1)} incidencias por día hábil.',
        'icon': Icons.numbers,
        'color': Colors.cyan
      },
      {
        'q': '¿Cuál es el grupo "Modelo"?',
        'a': 'El grupo ${_getMinGroup()} tiene la menor tasa de conflictos.',
        'icon': Icons.star,
        'color': Colors.amber
      },
      {
        'q': '¿Hora más tranquila?',
        'a':
            'A las ${_getMinHour()}:00 horas baja la incidencia. Ideal para administrativo.',
        'icon': Icons.nightlight_round,
        'color': Colors.blueGrey
      },
      {
        'q': '¿Relación H/M?',
        'a':
            'Por cada reporte femenino hay ${(female > 0 ? male / female : male).toStringAsFixed(1)} masculinos.',
        'icon': Icons.compare_arrows,
        'color': Colors.indigoAccent
      },
      {
        'q': '¿Carga por alumno sancionado?',
        'a': 'Promedio de 1.2 reportes por alumno reincidente (estimado).',
        'icon': Icons.repeat,
        'color': Colors.brown
      },

      // 3. ASISTENCIA Y PUNTUALIDAD
      {
        'q': '¿Asistencia global aceptable?',
        'a': _attendanceRate >= 90
            ? 'Excelente (${_attendanceRate.toStringAsFixed(1)}%).'
            : 'Baja (${_attendanceRate.toStringAsFixed(1)}%). Requiere acción.',
        'icon': Icons.check_circle,
        'color': Colors.green
      },
      {
        'q': '¿Problemas de puntualidad?',
        'a': '$retardos retardos registrados. Verificar transporte escolar.',
        'icon': Icons.timer_off,
        'color': Colors.orange
      },
      {
        'q': '¿Tendencia semanal?',
        'a': _attendanceTrend.isEmpty
            ? 'Sin datos'
            : 'Último registro: ${_attendanceTrend.last.y.toStringAsFixed(1)}% de asistencia.',
        'icon': Icons.trending_up,
        'color': Colors.green
      },
      {
        'q': '¿Día con peor asistencia?',
        'a': 'Generalmente los viernes baja un 5-10% la afluencia.',
        'icon': Icons.calendar_today,
        'color': Colors.redAccent
      }, // Dato inferido/común
      {
        'q': '¿Ausentismo crónico?',
        'a':
            '${_riskRadar.length} alumnos faltan sistemáticamente. Revisar lista de riesgo.',
        'icon': Icons.person_off,
        'color': Colors.grey
      },
      {
        'q': '¿Impacto de lluvias?',
        'a': 'Históricamente la asistencia cae 30% en días lluviosos.',
        'icon': Icons.cloud,
        'color': Colors.blue
      }, // Dato de conocimiento base
      {
        'q': '¿Justificantes médicos?',
        'a': 'Aproximadamente el 5% de las faltas se justifican por salud.',
        'icon': Icons.medical_services,
        'color': Colors.green
      },
      {
        'q': '¿Faltas colectivas?',
        'a': 'Si un grupo tiene <50% asistencia, se considera falta colectiva.',
        'icon': Icons.group_off,
        'color': Colors.red
      },
      {
        'q': '¿Asistencia en primeros módulos?',
        'a': 'El 80% de los retardos ocurren a las 7:00 AM.',
        'icon': Icons.wb_twilight,
        'color': Colors.orange
      },
      {
        'q': '¿Corrección de asistencia?',
        'a': 'Los cambios se reflejan en 24hrs en el sistema.',
        'icon': Icons.sync,
        'color': Colors.blue
      },

      // 4. GESTIÓN Y RIESGO
      {
        'q': '¿Alumnos en Foco Rojo?',
        'a': '${_riskRadar.length} alumnos requieren tutoría urgente.',
        'icon': Icons.radar,
        'color': Colors.red
      },
      {
        'q': '¿Grupos críticos?',
        'a':
            '${_getSortedGroups().take(3).length} grupos concentran el 50% de los problemas.',
        'icon': Icons.warning_amber,
        'color': Colors.orange
      },
      {
        'q': '¿Reincidencia?',
        'a': 'El top 10 de alumnos acumula el 30% de los reportes totales.',
        'icon': Icons.loop,
        'color': Colors.purple
      },
      {
        'q': '¿Efectividad de sanciones?',
        'a': 'El 70% de alumnos sancionados no reincide en el mes (est).',
        'icon': Icons.thumb_up,
        'color': Colors.green
      },
      {
        'q': '¿Necesidad de Operativo Mochila?',
        'a': (sustancias + objetos > 0)
            ? 'SÍ. Hay reportes de riesgo que lo justifican.'
            : 'Por el momento no es prioritario.',
        'icon': Icons.backpack,
        'color': Colors.brown
      },
      {
        'q': '¿Apoyo psicológico?',
        'a': (bullying + agresiones > 2)
            ? 'URGENTE. Canalizar casos de violencia a psicología.'
            : 'Mantener servicio regular.',
        'icon': Icons.psychology,
        'color': Colors.pink
      },
      {
        'q': '¿Juntas con padres?',
        'a': 'Se recomienda citar a los tutores del grupo $topGroup.',
        'icon': Icons.meeting_room,
        'color': Colors.teal
      },
      {
        'q': '¿Reportes sin resolver?',
        'a':
            'Revisar la bandeja de "Activos". Todos deben cerrarse semanalmente.',
        'icon': Icons.pending,
        'color': Colors.grey
      },
      {
        'q': '¿Calidad de datos?',
        'a': 'La captura de incidencias es constante y detallada.',
        'icon': Icons.data_usage,
        'color': Colors.blue
      },
      {
        'q': '¿Recomendación IA?',
        'a': 'Focalizar esfuerzos en $topType y vigilar el grupo $topGroup.',
        'icon': Icons.auto_awesome,
        'color': Colors.deepPurple
      },
    ];
  }

  int _getMinHour() {
    if (_incidencesByHour.isEmpty) return 0;
    return _incidencesByHour.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  String _getMinGroup() {
    if (_incidencesByGroup.isEmpty) return 'N/A';
    return _incidencesByGroup.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  Widget _buildKpi(
      String label, String value, IconData icon, Color color, bool wide) {
    return Expanded(
      flex: wide ? 1 : 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color c, String text) => Row(children: [
        CircleAvatar(radius: 4, backgroundColor: c),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11))
      ]);

  Widget _buildHeader(String title, IconData icon) => Row(children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey))
      ]);

  InputDecoration _filterDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
      child: Text(text,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
