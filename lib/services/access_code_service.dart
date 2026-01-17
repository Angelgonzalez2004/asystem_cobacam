import 'package:firebase_database/firebase_database.dart';

class AccessCodeService {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('access_codes');

  // Obtener todos los códigos (Para Admin General)
  Stream<Map<dynamic, dynamic>> getAllCodesStream() {
    return _dbRef.onValue.map((event) {
      return (event.snapshot.value as Map<dynamic, dynamic>?) ?? {};
    });
  }

  // Obtener códigos de un plantel específico (Para Admin Plantel)
  Stream<Map<dynamic, dynamic>> getCampusCodesStream(String campusId) {
    return _dbRef.child(campusId).onValue.map((event) {
      return (event.snapshot.value as Map<dynamic, dynamic>?) ?? {};
    });
  }

  // Actualizar un código específico
  Future<void> updateCode(String campusId, String role, String newCode) async {
    await _dbRef.child(campusId).update({
      role: newCode,
    });
  }

  // Inicializar códigos (Si la base está vacía, subir los locales una vez)
  Future<void> initializeCodes(
      Map<String, Map<String, String>> initialData) async {
    final snapshot = await _dbRef.get();
    if (!snapshot.exists) {
      await _dbRef.set(initialData);
    }
  }
}
