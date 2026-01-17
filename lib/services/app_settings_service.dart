import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle model
import 'package:asystem_cobacam/models/non_attendance_day_model.dart'; // Import NonAttendanceDay model
import 'package:asystem_cobacam/services/hive_service.dart'; // Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // Import ConnectivityService
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class AppSettingsService {
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('school_cycles'); // CORREGIDO: Root

  final HiveService _hiveService;
  final ConnectivityService _connectivityService;

  AppSettingsService(this._hiveService, this._connectivityService);

  Future<String> getCurrentSchoolCycleId() async {
    try {
      final cycles = await getAllSchoolCycles();
      if (cycles.isEmpty) return '2025-A';

      final now = DateTime.now();
      // Normalizar 'now' para comparar solo fechas (sin hora)
      final today = DateTime(now.year, now.month, now.day);

      // 1. Buscar ciclo ACTIVO (hoy dentro del rango)
      try {
        final activeCycle = cycles.firstWhere((c) {
          final start =
              DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
          final end = DateTime(c.endDate.year, c.endDate.month, c.endDate.day);
          return (today.isAfter(start) || today.isAtSameMomentAs(start)) &&
              (today.isBefore(end) || today.isAtSameMomentAs(end));
        });
        return activeCycle.id;
      } catch (e) {
        // No hay ciclo activo hoy (vacaciones/receso)
      }

      // 2. Buscar ciclo PRÓXIMO más cercano
      final upcomingCycles = cycles.where((c) {
        final start =
            DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
        return start.isAfter(today);
      }).toList();

      if (upcomingCycles.isNotEmpty) {
        upcomingCycles.sort((a, b) => a.startDate.compareTo(b.startDate));
        return upcomingCycles.first.id;
      }

      // 3. Buscar el ciclo PASADO más reciente
      final pastCycles = cycles.where((c) {
        final end = DateTime(c.endDate.year, c.endDate.month, c.endDate.day);
        return end.isBefore(today);
      }).toList();

      if (pastCycles.isNotEmpty) {
        pastCycles
            .sort((a, b) => b.endDate.compareTo(a.endDate)); // Descendente
        return pastCycles.first.id;
      }

      // Default si algo falla
      return cycles.first.id;
    } catch (e) {
      debugPrint('Error calculando ciclo escolar: $e');
      return '2025-A';
    }
  }

  // --- SchoolCycle Management ---
  Future<List<SchoolCycle>> getAllSchoolCycles() async {
    final schoolCyclesBox = _hiveService.schoolCyclesBox;
    // Primero, intentar cargar desde la caché local
    final cachedCycles = schoolCyclesBox.values.toList();
    if (cachedCycles.isNotEmpty &&
        await _connectivityService.checkConnectivity() ==
            ConnectivityResult.none) {
      return cachedCycles; // Devolver caché si no hay conexión
    }

    // Si hay conexión o la caché está vacía, intentar Firebase
    try {
      if (await _connectivityService.checkConnectivity() !=
          ConnectivityResult.none) {
        final snapshot = await _schoolCyclesRef.get();
        final List<SchoolCycle> firebaseCycles = [];
        if (snapshot.exists && snapshot.value != null) {
          for (final child in snapshot.children) {
            firebaseCycles.add(SchoolCycle.fromSnapshot(child));
          }
        }
        // Actualizar la caché de Hive con los datos de Firebase
        await schoolCyclesBox.clear();
        for (final cycle in firebaseCycles) {
          await schoolCyclesBox.put(cycle.id, cycle);
        }
        return firebaseCycles;
      }
    } catch (e) {
      debugPrint('Error al obtener SchoolCycles de Firebase: $e');
      // Si falla Firebase y teníamos caché, la devolvemos
      if (cachedCycles.isNotEmpty) return cachedCycles;
    }
    return [];
  }

  Future<void> addSchoolCycle(SchoolCycle cycle) async {
    try {
      await _schoolCyclesRef.child(cycle.id).set(cycle.toFirebaseMap());
      await _hiveService.schoolCyclesBox
          .put(cycle.id, cycle); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSchoolCycle(SchoolCycle cycle) async {
    try {
      await _schoolCyclesRef.child(cycle.id).update(cycle.toFirebaseMap());
      await _hiveService.schoolCyclesBox
          .put(cycle.id, cycle); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSchoolCycle(String cycleId) async {
    try {
      await _schoolCyclesRef.child(cycleId).remove();
      await _hiveService.schoolCyclesBox.delete(cycleId); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }

  // --- NonAttendanceDay Management ---
  DatabaseReference _getNonAttendanceDaysRef(String campusId) {
    return FirebaseDatabase.instance
        .ref('planteles/$campusId/nonAttendanceDays');
  }

  Future<List<NonAttendanceDay>> getAllNonAttendanceDays(
      String campusId) async {
    final nonAttendanceBox = _hiveService.nonAttendanceDaysBox;
    // Primero, intentar cargar desde la caché local
    final cachedDays = nonAttendanceBox.values
        .where((day) => day.campusId == campusId)
        .toList();
    if (cachedDays.isNotEmpty &&
        await _connectivityService.checkConnectivity() ==
            ConnectivityResult.none) {
      return cachedDays; // Devolver caché si no hay conexión
    }

    // Si hay conexión o la caché está vacía, intentar Firebase
    try {
      if (await _connectivityService.checkConnectivity() !=
          ConnectivityResult.none) {
        final snapshot = await _getNonAttendanceDaysRef(campusId).get();
        final List<NonAttendanceDay> firebaseDays = [];
        if (snapshot.exists && snapshot.value != null) {
          for (final child in snapshot.children) {
            firebaseDays.add(NonAttendanceDay.fromSnapshot(child));
          }
        }
        // Actualizar la caché de Hive con los datos de Firebase
        // Podríamos querer borrar solo los de este campus o todos y recargar
        // Por simplicidad, asumimos que la caja es por campus o manejamos por clave
        // Para una caché más eficiente, se podría estructurar Hive por campus.
        // Por ahora, solo actualizaremos si la caja global.
        await nonAttendanceBox.clear(); // Ojo: Esto borra todos los campus.
        for (final day in firebaseDays) {
          await nonAttendanceBox.put(day.id, day);
        }
        return firebaseDays;
      }
    } catch (e) {
      debugPrint('Error al obtener NonAttendanceDays de Firebase: $e');
      if (cachedDays.isNotEmpty) return cachedDays;
    }
    return [];
  }

  Future<void> addNonAttendanceDay(NonAttendanceDay day) async {
    try {
      await _getNonAttendanceDaysRef(day.campusId)
          .child(day.id)
          .set(day.toFirebaseMap());
      await _hiveService.nonAttendanceDaysBox
          .put(day.id, day); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateNonAttendanceDay(NonAttendanceDay day) async {
    try {
      await _getNonAttendanceDaysRef(day.campusId)
          .child(day.id)
          .update(day.toFirebaseMap());
      await _hiveService.nonAttendanceDaysBox
          .put(day.id, day); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteNonAttendanceDay(String campusId, String dayId) async {
    try {
      await _getNonAttendanceDaysRef(campusId).child(dayId).remove();
      await _hiveService.nonAttendanceDaysBox.delete(dayId); // Actualizar caché
    } catch (e) {
      rethrow;
    }
  }
}
