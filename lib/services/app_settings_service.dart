import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart'; // Import SchoolCycle model
import 'package:asystem_cobacam/models/non_attendance_day_model.dart'; // Import NonAttendanceDay model
import 'package:asystem_cobacam/services/hive_service.dart'; // Import HiveService
import 'package:asystem_cobacam/services/connectivity_service.dart'; // Import ConnectivityService
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class AppSettingsService {
  final DatabaseReference _appSettingsRef =
      FirebaseDatabase.instance.ref('appSettings');
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('appSettings/schoolCycles');

  final HiveService _hiveService;
  final ConnectivityService _connectivityService;

  AppSettingsService(this._hiveService, this._connectivityService);

  Future<String> getCurrentSchoolCycleId() async {
    // Esto es un dato pequeño y crítico, siempre intentamos Firebase primero,
    // pero si falla, podríamos tener un valor cacheado o un default.
    try {
      if (await _connectivityService.checkConnectivity() !=
          ConnectivityResult.none) {
        final snapshot =
            await _appSettingsRef.child('currentSchoolCycle').get();
        if (snapshot.exists && snapshot.value != null) {
          final cycleId = snapshot.value.toString();
          // Podríamos cachear esto en SharedPreferences para acceso rápido
          return cycleId;
        }
      }
    } catch (e) {
      // Manejar el error, quizás loggearlo
      debugPrint('Error al obtener currentSchoolCycle de Firebase: $e');
    }
    // Fallback a un valor por defecto o cacheado (si se implementa)
    return '2025-B'; // Default o fallback
  }

  Future<void> setCurrentSchoolCycleId(String cycleId) async {
    try {
      await _appSettingsRef.child('currentSchoolCycle').set(cycleId);
    } catch (e) {
      rethrow;
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
