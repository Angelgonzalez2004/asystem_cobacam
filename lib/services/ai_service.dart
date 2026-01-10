import 'dart:convert';
import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class AIService {
  final String _campus;
  
  // ✅ URL ACTUALIZADA (Cloud Functions Gen 2)
  static const String _functionUrl = 'https://chatwithgemini-twhlu5zwkq-uc.a.run.app';

  AIService(this._campus);

  /// Genera una respuesta llamando a la Cloud Function vía REST (Compatible Web/Mobile)
  Future<String> askAssistant(String question, {String? cycle}) async {
    try {
      // 1. Obtener Token de Seguridad del Usuario (Autenticación)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "⚠️ Error: Usuario no autenticado.";
      final token = await user.getIdToken();

      // 2. Obtener Contexto de Datos
      final contextData = await _getContextData(cycle);

      // 3. Llamada HTTP POST Segura (Formato REST Estándar)
      // Ya no necesitamos el wrapper 'data' porque ahora usamos onRequest y body-parser
      final body = jsonEncode({
        "question": question,
        "context": contextData,
      });

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Autenticación Bearer
        },
        body: body,
      );

      // 4. Procesar Respuesta
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true) {
          return jsonResponse['answer'] ?? "La IA no devolvió texto.";
        }
        return "⚠️ Error en respuesta IA: ${jsonResponse['error']}";
      } else {
        // Manejo de errores HTTP
        return "❌ Error del Servidor (${response.statusCode}): ${response.body}";
      }

    } catch (e) {
      return "❌ Error de Conexión: $e";
    }
  }

  /// Recopila datos clave de Firebase
  Future<String> _getContextData(String? cycle) async {
    if (cycle == null) return "No hay ciclo escolar seleccionado.";

    final sb = StringBuffer();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 1. Asistencia de HOY
      final attendanceRef = FirebaseDatabase.instance.ref('planteles/$_campus/attendance/$cycle/$today');
      final attSnap = await attendanceRef.get();
      
      int totalHoy = 0;
      int retardos = 0;
      
      if (attSnap.exists) {
        totalHoy = attSnap.children.length;
        for (var child in attSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          if (data['status'] == 'tarde') retardos++;
        }
        sb.writeln("- Asistencia HOY ($today): $totalHoy alumnos registrados. $retardos retardos.");
      } else {
        sb.writeln("- Asistencia HOY ($today): Aún no hay registros.");
      }

      // 2. Incidencias Recientes (Últimas 5)
      final incRef = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
      final incQuery = incRef.limitToLast(10); 
      final incSnap = await incQuery.get();

      if (incSnap.exists) {
        sb.writeln("- Incidencias Recientes:");
        final List<Incidence> incidents = [];
        for (var child in incSnap.children) {
           final data = Map<String, dynamic>.from(child.value as Map);
           incidents.add(Incidence.fromFirebaseMap(child.key!, data));
        }
        incidents.sort((a, b) => b.date.compareTo(a.date));

        for (var inc in incidents.take(5)) {
          sb.writeln("  * ${DateFormat('dd/MM').format(inc.date)}: ${inc.studentName} (${inc.type})");
        }
      } else {
        sb.writeln("- No hay incidencias recientes.");
      }

    } catch (e) {
      sb.writeln(" (Error leyendo DB: $e)");
    }

    return sb.toString();
  }
}
