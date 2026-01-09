import 'package:asystem_cobacam/models/incidence_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AIService {
  // ⚠️ API KEY CONFIGURADA CORRECTAMENTE
  static const String _apiKey = 'AIzaSyArEj-ceTieqVUzibtV1u7YeFdHP4xltmE'; 

  late final GenerativeModel _model;
  final String _campus;

  AIService(this._campus) {
    if (_apiKey.isEmpty) {
      // Manejo seguro si no hay key
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7, // Creatividad equilibrada
      )
    );
  }

  bool get hasKey => _apiKey.isNotEmpty;

  /// Genera una respuesta basada en la pregunta del usuario y los datos del plantel
  Future<String> askAssistant(String question, {String? cycle}) async {
    if (!hasKey) {
      return "⚠️ Error de Configuración: No se ha detectado la API Key de Gemini. Por favor, configura la clave en el código fuente (lib/services/ai_service.dart) para usar el asistente.";
    }

    try {
      // 1. Recopilar contexto breve (Datos recientes)
      final contextData = await _getContextData(cycle);
      
      // 2. Construir el Prompt
      final prompt = '''
Eres "AsystemBot", un asistente administrativo escolar útil y profesional del COBACAM (Plantel $_campus).
Tu trabajo es ayudar a la Prefecta a analizar datos de asistencia y conducta.

DATOS ACTUALES DEL SISTEMA (Contexto):
$contextData

PREGUNTA DEL USUARIO:
"$question"

INSTRUCCIONES:
- Responde de forma concisa y directa.
- Usa formato Markdown para negritas (**texto**) y listas.
- Si te piden un reporte, sugiere que pueden usar el botón de exportar.
- Si no sabes la respuesta basándote en los datos, di que no tienes esa información.
- Analiza tendencias si te lo piden (ej. "quién falta más").
''';

      // 3. Enviar a Gemini
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? "Lo siento, no pude generar una respuesta.";
    } catch (e) {
      return "Error conectando con la IA: $e";
    }
  }

  /// Recopila datos clave de Firebase para dar contexto a la IA
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

      // 2. Incidencias Recientes (Últimas 10)
      final incRef = FirebaseDatabase.instance.ref('planteles/$_campus/incidents');
      // Traemos las últimas 20 para no saturar
      final incQuery = incRef.limitToLast(20); 
      final incSnap = await incQuery.get();

      if (incSnap.exists) {
        sb.writeln("- Incidencias Recientes:");
        final List<Incidence> incidents = [];
        for (var child in incSnap.children) {
           final data = Map<String, dynamic>.from(child.value as Map);
           incidents.add(Incidence.fromFirebaseMap(child.key!, data));
        }
        
        // Ordenar recientes primero
        incidents.sort((a, b) => b.date.compareTo(a.date));

        for (var inc in incidents.take(10)) {
          sb.writeln("  * ${DateFormat('dd/MM').format(inc.date)}: ${inc.studentName} (${inc.group}) - ${inc.type}");
        }
      } else {
        sb.writeln("- No hay incidencias recientes reportadas.");
      }

    } catch (e) {
      sb.writeln("Error leyendo datos: $e");
    }

    return sb.toString();
  }
}
