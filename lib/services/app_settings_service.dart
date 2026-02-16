import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/school_cycle_model.dart';
import 'package:asystem_cobacam/models/non_attendance_day_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class AppSettingsService {
  final DatabaseReference _schoolCyclesRef =
      FirebaseDatabase.instance.ref('school_cycles');

  final HiveService _hiveService;
  final ConnectivityService _connectivityService;

  AppSettingsService(this._hiveService, this._connectivityService) {
    debugPrint('AppSettingsService: Constructor iniciado.');
  }

  /// Returns the active school cycle ID purely from the local cache.
  /// This method is synchronous and safe to call on app startup.
  String getActiveSchoolCycleIdFromCache() {
    try {
      debugPrint('AppSettingsService: Accediendo a schoolCyclesBox (cache).');
      final cycles = _hiveService.schoolCyclesBox.values.toList();
      return _calculateCurrentCycle(cycles);
    } catch (e) {
      debugPrint('Error getting cycle from cache: $e');
      // Fallback to a sensible default if cache is empty or fails.
      return '${DateTime.now().year}-${DateTime.now().month > 7 ? 'B' : 'A'}';
    }
  }

  /// Calculates the current school cycle ID from a given list of cycles.
  String _calculateCurrentCycle(List<SchoolCycle> cycles) {
    if (cycles.isEmpty) {
      throw Exception(
          'No school cycles available to calculate the current one.');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Find active cycle
    final activeCycle = cycles.where((c) {
      final start =
          DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
      final end = DateTime(c.endDate.year, c.endDate.month, c.endDate.day);
      return !today.isBefore(start) && !today.isAfter(end);
    });

    if (activeCycle.isNotEmpty) {
      return activeCycle.first.id;
    }

    // 2. Find nearest upcoming cycle
    final upcomingCycles =
        cycles.where((c) => c.startDate.isAfter(today)).toList();
    if (upcomingCycles.isNotEmpty) {
      upcomingCycles.sort((a, b) => a.startDate.compareTo(b.startDate));
      return upcomingCycles.first.id;
    }

    // 3. Find most recent past cycle
    final pastCycles = cycles.where((c) => c.endDate.isBefore(today)).toList();
    if (pastCycles.isNotEmpty) {
      pastCycles.sort((a, b) => b.endDate.compareTo(a.endDate));
      return pastCycles.first.id;
    }

    // 4. Default fallback
    return cycles.first.id;
  }

  /// Fetches all school cycles, prioritizing online data but with a quick fallback to cache.
  Future<List<SchoolCycle>> getAllSchoolCycles() async {
    if (await _connectivityService.checkConnectivity() !=
        ConnectivityResult.none) {
      try {
        final snapshot =
            await _schoolCyclesRef.get().timeout(const Duration(seconds: 5));
        if (snapshot.exists && snapshot.value != null) {
          final firebaseCycles = snapshot.children
              .map((child) => SchoolCycle.fromSnapshot(child))
              .toList();
          debugPrint('AppSettingsService: Limpiando schoolCyclesBox (online).');
          await _hiveService.schoolCyclesBox.clear();
          debugPrint('AppSettingsService: Agregando ciclos a schoolCyclesBox (online).');
          await _hiveService.schoolCyclesBox.addAll(firebaseCycles);
          return firebaseCycles;
        }
      } catch (e) {
        debugPrint(
            'Error fetching SchoolCycles from Firebase, using cache: $e');
      }
    }
    debugPrint('AppSettingsService: Accediendo a schoolCyclesBox (offline fallback).');
    return _hiveService.schoolCyclesBox.values.toList();
  }

  /// Fetches all non-attendance days for a campus, prioritizing online data with a quick fallback.
  Future<List<NonAttendanceDay>> getAllNonAttendanceDays(
      String campusId) async {
    if (await _connectivityService.checkConnectivity() !=
        ConnectivityResult.none) {
      try {
        final snapshot = await _getNonAttendanceDaysRef(campusId)
            .get()
            .timeout(const Duration(seconds: 5));
        if (snapshot.exists && snapshot.value != null) {
          final firebaseDays = snapshot.children
              .map((child) => NonAttendanceDay.fromSnapshot(child))
              .toList();
          debugPrint('AppSettingsService: Accediendo a nonAttendanceDaysBox (online).');
          final allCachedDays =
              _hiveService.nonAttendanceDaysBox.values.toList();
          final otherCampusDays =
              allCachedDays.where((day) => day.campusId != campusId);
          debugPrint('AppSettingsService: Limpiando nonAttendanceDaysBox (online).');
          await _hiveService.nonAttendanceDaysBox.clear();
          debugPrint('AppSettingsService: Agregando días a nonAttendanceDaysBox (online).');
          await _hiveService.nonAttendanceDaysBox
              .addAll([...otherCampusDays, ...firebaseDays]);
          return firebaseDays;
        }
      } catch (e) {
        debugPrint(
            'Error fetching NonAttendanceDays from Firebase, using cache: $e');
      }
    }
    debugPrint('AppSettingsService: Accediendo a nonAttendanceDaysBox (offline fallback).');
    return _hiveService.nonAttendanceDaysBox.values
        .where((day) => day.campusId == campusId)
        .toList();
  }

  Future<String> getCurrentSchoolCycleId() async {
    try {
      final cycles = await getAllSchoolCycles();
      return _calculateCurrentCycle(cycles);
    } catch (e) {
      debugPrint('Error calculating school cycle: $e');
      return '${DateTime.now().year}-${DateTime.now().month > 7 ? 'B' : 'A'}';
    }
  }

  Future<void> addSchoolCycle(SchoolCycle cycle) async {
    await _schoolCyclesRef.child(cycle.id).set(cycle.toFirebaseMap());
    debugPrint('AppSettingsService: Agregando ciclo a schoolCyclesBox.');
    await _hiveService.schoolCyclesBox.put(cycle.id, cycle);
  }

  Future<void> updateSchoolCycle(SchoolCycle cycle) async {
    await _schoolCyclesRef.child(cycle.id).update(cycle.toFirebaseMap());
    debugPrint('AppSettingsService: Actualizando ciclo en schoolCyclesBox.');
    await _hiveService.schoolCyclesBox.put(cycle.id, cycle);
  }

  Future<void> deleteSchoolCycle(String cycleId) async {
    await _schoolCyclesRef.child(cycleId).remove();
    debugPrint('AppSettingsService: Eliminando ciclo de schoolCyclesBox.');
    await _hiveService.schoolCyclesBox.delete(cycleId);
  }

  DatabaseReference _getNonAttendanceDaysRef(String campusId) {
    return FirebaseDatabase.instance
        .ref('planteles/$campusId/nonAttendanceDays');
  }

  Future<void> addNonAttendanceDay(NonAttendanceDay day) async {
    await _getNonAttendanceDaysRef(day.campusId)
        .child(day.id)
        .set(day.toFirebaseMap());
    debugPrint('AppSettingsService: Agregando día a nonAttendanceDaysBox.');
    await _hiveService.nonAttendanceDaysBox.put(day.id, day);
  }

  Future<void> updateNonAttendanceDay(NonAttendanceDay day) async {
    await _getNonAttendanceDaysRef(day.campusId)
        .child(day.id)
        .update(day.toFirebaseMap());
    debugPrint('AppSettingsService: Actualizando día en nonAttendanceDaysBox.');
    await _hiveService.nonAttendanceDaysBox.put(day.id, day);
  }

  Future<void> deleteNonAttendanceDay(String campusId, String dayId) async {
    await _getNonAttendanceDaysRef(campusId).child(dayId).remove();
    debugPrint('AppSettingsService: Eliminando día de nonAttendanceDaysBox.');
    await _hiveService.nonAttendanceDaysBox.delete(dayId);
  }
}
