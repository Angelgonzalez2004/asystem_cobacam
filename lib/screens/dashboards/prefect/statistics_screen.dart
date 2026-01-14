import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';

enum TimeRange { week, month, cycle }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  String? _campus;
  String? _currentCycle;
  TimeRange _selectedRange = TimeRange.month; // Default to Month
  
  // Data Stats
  int _totalStudents = 0;
  int _totalIncidences = 0;
  double _attendanceRate = 0.0;
  
  Map<String, int> _incidencesByType = {};
  Map<String, int> _incidencesByGroup = {};
  List<FlSpot> _attendanceTrend = [];
  
  // Risk Radar
  List<Map<String, dynamic>> _topRiskStudents = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userSnap.exists) return;
      final userData = Map<String, dynamic>.from(userSnap.value as Map);
      _campus = userData['campus'];

      final appSettings = AppSettingsService(
        Provider.of<HiveService>(context, listen: false), 
        Provider.of<ConnectivityService>(context, listen: false)
      );
      _currentCycle = await appSettings.getCurrentSchoolCycleId();

      if (_campus != null && _currentCycle != null) {
        await _processStats();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case TimeRange.week:
        // Últimos 7 días
        return now.subtract(const Duration(days: 7));
      case TimeRange.month:
        // Inicio de mes
        return DateTime(now.year, now.month, 1);
      case TimeRange.cycle:
        // Fecha muy antigua (el filtro de ciclo se hace por ID string, no por fecha)
        return DateTime(2020); 
    }
  }

  Future<void> _processStats() async {
    if (_campus == null || _currentCycle == null) return;
    
    // Reset Data
    _totalIncidences = 0;
    _incidencesByType = {};
    _incidencesByGroup = {};
    _topRiskStudents = [];
    
    final startDate = _getStartDate();
    final now = DateTime.now();

    // 1. Fetch Students Count (Always Global)
    final studentsRef = FirebaseDatabase.instance.ref('planteles/$_campus/students/$_currentCycle');
    final studentsSnap = await studentsRef.get();
    if (studentsSnap.exists) {
      _totalStudents = studentsSnap.children.where((s) {
        final d = s.value as Map;
        return d['isActive'] == true;
      }).length;
    }

    // 2. Fetch Incidences & Risk Radar
    final incidencesRef = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
    final incidencesSnap = await incidencesRef.get();
    
    final Map<String, int> studentRiskCounter = {};
    final Map<String, String> studentNames = {}; // Cache names
    final Map<String, String> studentGroups = {}; // Cache groups

    if (incidencesSnap.exists) {
      for (var child in incidencesSnap.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        
        // Filter by Cycle
        if (data['schoolCycle'] != _currentCycle) continue;
        
        // Filter by Date (If not Cycle range)
        final dateStr = data['date'];
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _selectedRange != TimeRange.cycle) {
            if (date.isBefore(startDate)) continue;
          }
        }

        _totalIncidences++;
        
        // By Type
        final type = data['type'] ?? 'Otro';
        _incidencesByType[type] = (_incidencesByType[type] ?? 0) + 1;
        
        // By Group
        final group = data['group'] ?? 'Sin Grupo';
        _incidencesByGroup[group] = (_incidencesByGroup[group] ?? 0) + 1;

        // Risk Counter
        final sId = data['studentId'];
        final sName = data['studentName'];
        if (sId != null) {
          studentRiskCounter[sId] = (studentRiskCounter[sId] ?? 0) + 1;
          studentNames[sId] = sName ?? 'Desconocido';
          studentGroups[sId] = group;
        }
      }
    }

    // Process Risk Top 5
    final sortedRisk = studentRiskCounter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Descending
    
    _topRiskStudents = sortedRisk.take(5).map((e) => {
      'id': e.key,
      'name': studentNames[e.key],
      'group': studentGroups[e.key],
      'count': e.value
    }).toList();


    // 3. Attendance Trend (Contextual)
    // If Week: Show last 7 days.
    // If Month: Show last 4 weeks avg? Or just days of month.
    // If Cycle: Show months avg. 
    // To keep it simple and responsive: We always show "Last 7 active days" trend, 
    // but the KPI "Attendance Rate" respects the filter time range AVERAGE.
    
    final attendanceRef = FirebaseDatabase.instance.ref('planteles/$_campus/attendance/$_currentCycle');
    
    // Calculate Average Attendance for the selected period
    // Iterate from Now backwards to StartDate
    int daysCounted = 0;
    double sumRates = 0;
    
    // Trend points (Always last 7 days for visualization)
    List<FlSpot> trend = [];
    int trendDays = 0;

    // Scan last 30 days max to avoid heavy loops, or diff days
    int limitDays = now.difference(startDate).inDays;
    if (_selectedRange == TimeRange.cycle) limitDays = 30; // Sample last 30 days for cycle avg to be fast
    if (limitDays > 30) limitDays = 30; 
    if (limitDays < 1) limitDays = 1;

    for (int i = 0; i <= limitDays; i++) {
      final date = now.subtract(Duration(days: i));
      if (date.weekday >= 6) continue; // Skip weekends
      
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final daySnap = await attendanceRef.child(dateStr).get();
      
      double dailyRate = 0;
      if (daySnap.exists) {
        int present = 0;
        for (var child in daySnap.children) {
          final d = child.value as Map;
          if (d['status'] != 'falta' && d['status'] != 'null') present++;
        }
        if (_totalStudents > 0) dailyRate = (present / _totalStudents) * 100;
        if (dailyRate > 100) dailyRate = 100;
      }

      // Add to Average
      sumRates += dailyRate;
      daysCounted++;

      // Add to Trend Graph (Only first 7 valid days)
      if (trendDays < 7) {
        trend.add(FlSpot((6 - trendDays).toDouble(), dailyRate)); // Reverse X for chart
        trendDays++;
      }
    }
    
    // Sort trend by X
    trend.sort((a, b) => a.x.compareTo(b.x));
    _attendanceTrend = trend;
    
    _attendanceRate = daysCounted > 0 ? sumRates / daysCounted : 0;
  }

  void _onRangeChanged(TimeRange newRange) {
    setState(() {
      _selectedRange = newRange;
      _isLoading = true;
    });
    _processStats().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F6F8),
      body: CustomScrollView(
        slivers: [
          // Header & Filter
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Métricas del Plantel', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(_currentCycle ?? 'Ciclo S/D', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // TIME FILTER
                  Center(
                    child: SegmentedButton<TimeRange>(
                      segments: const [
                        ButtonSegment(value: TimeRange.week, label: Text('Semana'), icon: Icon(Icons.calendar_view_week, size: 16)),
                        ButtonSegment(value: TimeRange.month, label: Text('Mes'), icon: Icon(Icons.calendar_view_month, size: 16)),
                        ButtonSegment(value: TimeRange.cycle, label: Text('Ciclo'), icon: Icon(Icons.timelapse, size: 16)),
                      ],
                      selected: {_selectedRange},
                      onSelectionChanged: (newSelection) => _onRangeChanged(newSelection.first),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? Colors.white : Colors.black12),
                        foregroundColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? theme.primaryColor : Colors.white),
                        side: MaterialStateProperty.all(BorderSide.none),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // KPI Cards
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildKpiCard('Total Incidencias', '$_totalIncidences', Icons.warning_rounded, Colors.redAccent, isWide),
                      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
                      _buildKpiCard('Asistencia Prom.', '${_attendanceRate.toStringAsFixed(1)}%', Icons.show_chart_rounded, _attendanceRate > 85 ? Colors.green : Colors.orange, isWide),
                      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
                      _buildKpiCard('Alumnos Activos', '$_totalStudents', Icons.groups_rounded, Colors.blue, isWide),
                    ],
                  );
                }),
                
                const SizedBox(height: 24),
                
                // RISK RADAR (New Professional Feature)
                if (_topRiskStudents.isNotEmpty) ...[
                  _buildSectionTitle('Radar de Riesgo (Top 5 Incidencias)', Icons.radar_outlined),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(
                      children: _topRiskStudents.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: i == 0 ? Colors.red : (i == 1 ? Colors.orange : Colors.grey.shade300),
                            foregroundColor: i < 2 ? Colors.white : Colors.black87,
                            radius: 14,
                            child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Grupo ${s['group']} • Matrícula: ${s['id']}', style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text('${s['count']} Reportes', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Charts
                LayoutBuilder(builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  return Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: isDesktop ? 4 : 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Distribución por Tipo', Icons.pie_chart_outline),
                            const SizedBox(height: 12),
                            _buildChartContainer(
                              height: 320,
                              child: _incidencesByType.isEmpty 
                                ? const Center(child: Text('Sin datos en este periodo'))
                                : PieChart(
                                    PieChartData(
                                      sectionsSpace: 4,
                                      centerSpaceRadius: 40,
                                      sections: _getPieSections(),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

                      // Bar Chart
                      Expanded(
                        flex: isDesktop ? 6 : 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Grupos Críticos', Icons.bar_chart_rounded),
                            const SizedBox(height: 12),
                            _buildChartContainer(
                              height: 320,
                              child: _incidencesByGroup.isEmpty 
                                ? const Center(child: Text('Sin datos en este periodo'))
                                : BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: _getMaxGroupIncidence() + 1,
                                      barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(getTooltipColor: (group) => Colors.blueGrey, getTooltipItem: (a, b, c, i) => BarTooltipItem('${c.toY.toInt()}', const TextStyle(color: Colors.white)))),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              final groups = _getSortedGroups();
                                              if (value.toInt() < groups.length) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(groups[value.toInt()].key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: const FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      barGroups: _getBarGroups(theme.colorScheme.error),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                
                const SizedBox(height: 24),
                
                // Trend
                _buildSectionTitle('Tendencia Asistencia (7 Días)', Icons.trending_up),
                const SizedBox(height: 12),
                _buildChartContainer(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 25, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _attendanceTrend,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                        ),
                      ],
                      minY: 0,
                      maxY: 105,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildChartContainer({required Widget child, required double height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      flex: isWide ? 1 : 0,
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  if (_selectedRange != TimeRange.cycle && title.contains('Incidencias'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(_selectedRange == TimeRange.week ? 'Esta Sem.' : 'Este Mes', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey : Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // --- CHART DATA HELPERS ---

  List<PieChartSectionData> _getPieSections() {
    final sorted = _incidencesByType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    
    final List<Color> colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.red];
    
    return List.generate(top5.length, (i) {
      final item = top5[i];
      final isLarge = i == 0;
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: item.value.toDouble(),
        title: '${item.value}',
        radius: isLarge ? 70 : 60,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: _Badge(
          item.key,
          size: 40,
          borderColor: colors[i % colors.length],
        ),
        badgePositionPercentageOffset: 1.4,
      );
    });
  }

  List<MapEntry<String, int>> _getSortedGroups() {
    return _incidencesByGroup.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  double _getMaxGroupIncidence() {
    if (_incidencesByGroup.isEmpty) return 10;
    return _incidencesByGroup.values.reduce((a, b) => a > b ? a : b).toDouble();
  }

  List<BarChartGroupData> _getBarGroups(Color color) {
    final groups = _getSortedGroups().take(6).toList();
    return List.generate(groups.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: groups[i].value.toDouble(),
            gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.bottomCenter, end: Alignment.topCenter),
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxGroupIncidence() + 1,
              color: Colors.grey.withOpacity(0.05),
            ),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    });
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.size, required this.borderColor});
  final String text;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size * 3.0, 
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
