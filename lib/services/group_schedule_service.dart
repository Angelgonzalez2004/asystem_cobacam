import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:asystem_cobacam/models/group_schedule_model.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class GroupScheduleService {
  final HiveService _hiveService;
  final ConnectivityService _connectivityService;

  GroupScheduleService(this._hiveService, this._connectivityService);

  // Firebase reference for group schedules - ACTUALIZADO A RUTA REAL
  DatabaseReference _getGroupSchedulesRef(String campusId, String schoolCycleId) {
    return FirebaseDatabase.instance
        .ref('planteles/$campusId/schedules/$schoolCycleId');
  }

  /// Fetches all group schedules for a given campus and school cycle,
  /// prioritizing online data but with a quick fallback to cache.
  Future<List<GroupSchedule>> getAllGroupSchedules(
      String campusId, String schoolCycleId) async {
    if (await _connectivityService.checkConnectivity() != ConnectivityResult.none) {
      try {
        final snapshot = await _getGroupSchedulesRef(campusId, schoolCycleId)
            .get()
            .timeout(const Duration(seconds: 10));

        if (snapshot.exists && snapshot.value != null) {
          final List<GroupSchedule> firebaseSchedules = [];

          for (final child in snapshot.children) {
            firebaseSchedules.add(GroupSchedule.fromSnapshot(child));
          }
          
          debugPrint('GroupScheduleService: Clearing groupSchedulesBox (online).');
          // Clear only schedules for the current campus and cycle from cache
          await _hiveService.groupSchedulesBox.clear(); // NOTE: If Hive stores schedules for multiple campuses/cycles, this clear needs to be more specific. For now, assuming it's managed by the current active campus/cycle for simplicity in caching.
          debugPrint('GroupScheduleService: Adding schedules to groupSchedulesBox (online).');
          await _hiveService.groupSchedulesBox.addAll(firebaseSchedules);
          return firebaseSchedules;
        }
      } catch (e) {
        debugPrint('Error fetching GroupSchedules from Firebase, using cache: $e');
      }
    }
    debugPrint('GroupScheduleService: Accessing groupSchedulesBox (offline fallback).');
    // Filter from Hive to ensure we only get schedules for the requested campus and cycle
    return _hiveService.groupSchedulesBox.values
        .where((s) => s.schoolCycle == schoolCycleId && s.groupId.startsWith(campusId)) // Assuming groupId often starts with campusId
        .toList();
  }

  /// Retrieves a single GroupSchedule by its ID, campus, and school cycle.
  /// Prioritizes online data, falls back to cache.
  Future<GroupSchedule?> getGroupSchedule(
      String groupId, String campusId, String schoolCycleId) async {
    // Try fetching all and then filtering (simpler for now if cache is not granular)
    final allSchedules = await getAllGroupSchedules(campusId, schoolCycleId);
    return allSchedules.firstWhereOrNull((s) => s.groupId == groupId);
  }
}

// Extension to List for firstWhereOrNull, similar to what's available in collection package
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
