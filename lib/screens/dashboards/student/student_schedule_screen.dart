import 'dart:async';
import 'package:asystem_cobacam/models/group_model.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/student_model.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  late final HiveService _hiveService;
  late final ConnectivityService _connectivityService;
  late final AppSettingsService _appSettingsService;

  bool _isLoading = true;
  String? _errorMessage;

  String? _studentId; // Matrícula from users/${uid}
  String? _campus; // Campus (Plantel) from users/${uid}
  String? _studentGroup; // Group name from student enrollment for current cycle
  
  List<SchoolCycle> _schoolCycles = [];
  String? _selectedSchoolCycleId;
  
  GroupSchedule? _groupSchedule;
  bool _isFetchingSchedule = false;

  @override
  void initState() {
    super.initState();
    _hiveService = Provider.of<HiveService>(context, listen: false);
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No hay un usuario autenticado.");

      final userProfileSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (!userProfileSnap.exists) throw Exception("No se encontró tu perfil de usuario.");
      
      final userProfile = Map<String, dynamic>.from(userProfileSnap.value as Map);
      _studentId = userProfile['studentId'];
      _campus = userProfile['campus'];

      if (_studentId == null || _campus == null) {
        throw Exception("Tu perfil no tiene una matrícula o plantel asignado.");
      }

      _schoolCycles = await _appSettingsService.getAllSchoolCycles();
      if (_schoolCycles.isEmpty) {
        throw Exception("No se encontraron ciclos escolares registrados.");
      }

      final currentCycleId = await _appSettingsService.getCurrentSchoolCycleId();
      _selectedSchoolCycleId = currentCycleId;

      await _fetchScheduleForCycle(_selectedSchoolCycleId!);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchScheduleForCycle(String cycleId) async {
    if (_studentId == null || _campus == null) return;

    setState(() {
      _isFetchingSchedule = true;
      _groupSchedule = null;
      _studentGroup = null;
      _errorMessage = null;
    });

    try {
      // 1. Fetch student enrollment for this cycle using studentId
      final studentDbPath = 'planteles/$_campus/students/$cycleId/$_studentId';
      final studentSnap = await FirebaseDatabase.instance.ref(studentDbPath).get();

      if (!studentSnap.exists) {
        setState(() {
          _errorMessage = "No se encontró registro para la matrícula $_studentId en el ciclo escolar $cycleId.";
        });
        return;
      }

      final studentData = Student.fromMap(Map<String, dynamic>.from(studentSnap.value as Map));
      final groupName = studentData.group.trim();
      
      if (groupName.isEmpty) {
        setState(() {
          _errorMessage = "Tu registro de estudiante para este ciclo escolar no tiene un grupo asignado.";
        });
        return;
      }

      setState(() {
        _studentGroup = groupName;
      });

      // 2. Map groupName (e.g. "1A") to its groupId (key) under planteles/campus/groups
      final groupsSnap = await FirebaseDatabase.instance.ref('planteles/$_campus/groups')
          .orderByChild('schoolCycleId')
          .equalTo(cycleId)
          .get();

      String? matchedGroupId;
      if (groupsSnap.exists) {
        for (final child in groupsSnap.children) {
          final g = Group.fromSnapshot(child);
          if (g.name.trim().toLowerCase() == groupName.toLowerCase()) {
            matchedGroupId = g.key;
            break;
          }
        }
      }

      if (matchedGroupId == null) {
        setState(() {
          _errorMessage = "No se pudo encontrar el grupo '$groupName' registrado en el ciclo escolar $cycleId.";
        });
        return;
      }

      // 3. Fetch schedule from planteles/campus/schedules/cycleId/groupId
      final scheduleDbPath = 'planteles/$_campus/schedules/$cycleId/$matchedGroupId';
      final scheduleSnap = await FirebaseDatabase.instance.ref(scheduleDbPath).get();

      if (scheduleSnap.exists) {
        setState(() {
          _groupSchedule = GroupSchedule.fromSnapshot(scheduleSnap);
        });
      } else {
        // Fallback: No custom general schedule is defined, so _groupSchedule is null
        // We will default to 07:00 - 14:00 inside UI with a premium banner
        setState(() {
          _groupSchedule = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error al cargar el horario: ${e.toString()}";
      });
    } finally {
      if (mounted) setState(() => _isFetchingSchedule = false);
    }
  }

  Map<String, String> _getDayHours(String day) {
    if (_groupSchedule != null && _groupSchedule!.dailySchedules.containsKey(day)) {
      final sessions = _groupSchedule!.dailySchedules[day];
      // Find session with subjectId == 'GENERAL'
      final generalSession = sessions?.firstWhere(
        (s) => s.subjectId == 'GENERAL',
        orElse: () => sessions.first,
      );
      if (generalSession != null) {
        return {
          'start': generalSession.startTime,
          'end': generalSession.endTime,
          'isCustom': 'true',
        };
      }
    }
    // Fallback default Matutino
    return {
      'start': '07:00',
      'end': '14:00',
      'isCustom': 'false',
    };
  }

  String _formatTime(String rawTime) {
    try {
      final parts = rawTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final cleanHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final period = hour >= 12 ? 'PM' : 'AM';
      final cleanMin = minute.toString().padLeft(2, '0');
      
      return '$cleanHour:$cleanMin $period';
    } catch (_) {
      return rawTime;
    }
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'Lunes':
        return const Color(0xFF3B82F6); // Blue
      case 'Martes':
        return const Color(0xFF0D9488); // Teal
      case 'Miércoles':
        return const Color(0xFF6366F1); // Indigo
      case 'Jueves':
        return const Color(0xFF8B5CF6); // Violet
      case 'Viernes':
        return const Color(0xFFF97316); // Orange
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Cargando tu información...", style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_errorMessage != null && _schoolCycles.isEmpty) {
      return _buildErrorScreen(_errorMessage!);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cycle selection dropdown
          FadeInDown(
            delay: const Duration(milliseconds: 50),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ciclo Escolar a Consultar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSchoolCycleId,
                    items: _schoolCycles
                        .map((cycle) => DropdownMenuItem(
                              value: cycle.id,
                              child: Text(
                                cycle.id,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSchoolCycleId = value;
                        });
                        _fetchScheduleForCycle(value);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
                      ),
                      prefixIcon: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Schedule details body
          if (_isFetchingSchedule)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Obteniendo horario de grupo...",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            FadeInUp(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.red.withOpacity(0.05) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.red.shade300 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Header card showing student info
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.secondary.withOpacity(0.7)]
                        : [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Mi Horario de Asistencia",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Grupo: ${_studentGroup ?? 'N/A'}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Plantel: ${_campus ?? 'N/A'}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Daily list
            ...['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'].asMap().entries.map((entry) {
              final idx = entry.key;
              final day = entry.value;
              final data = _getDayHours(day);
              final isCustom = data['isCustom'] == 'true';
              final start = data['start']!;
              final end = data['end']!;
              final dayColor = _getDayColor(day);

              return FadeInUp(
                delay: Duration(milliseconds: 100 + idx * 80),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: dayColor.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: dayColor, width: 6),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: dayColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCustom
                                      ? (isDark ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFECFDF5))
                                      : (isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCustom
                                        ? const Color(0xFF10B981).withOpacity(0.2)
                                        : theme.dividerColor.withOpacity(0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isCustom ? "Especial" : "Matutino Estándar",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCustom
                                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                        : (isDark ? Colors.blue.shade300 : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.01) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: theme.dividerColor.withOpacity(0.03)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.login_rounded, size: 16, color: dayColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'LLEGADA REGLAMENTARIA',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatTime(start),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.grey[100] : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.01) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: theme.dividerColor.withOpacity(0.03)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SALIDA OFICIAL',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatTime(end),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.grey[100] : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Bottom descriptive banner
            FadeInUp(
              delay: const Duration(milliseconds: 550),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.primary.withOpacity(0.05) : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Nota importante: Este es tu horario oficial reglamentario para el registro de tu asistencia diaria. Los cambios son gestionados exclusivamente por la Prefectura de tu plantel.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              "Configuración Incompleta",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
