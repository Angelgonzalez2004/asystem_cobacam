import 'package:firebase_database/firebase_database.dart';

class FaqService {
  final DatabaseReference _faqsRef = FirebaseDatabase.instance.ref('faqs');

  // Stream para obtener todas las FAQs en tiempo real
  Stream<List<Map<String, dynamic>>> getFaqsStream() {
    return _faqsRef.onValue.map((event) {
      final List<Map<String, dynamic>> faqs = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final faq = Map<String, dynamic>.from(value as Map);
          faq['key'] = key; // Guardamos la clave única de Firebase
          faqs.add(faq);
        });
      }
      // Opcional: Ordenar por categoría o pregunta
      faqs.sort((a, b) => (a['q'] as String).compareTo(b['q'] as String));
      return faqs;
    });
  }

  // Añadir una nueva pregunta
  Future<void> addFaq(Map<String, dynamic> faqData) async {
    // El 'key' no se debe guardar como un campo en la base de datos, 
    // es el identificador del nodo.
    faqData.remove('key'); 
    await _faqsRef.push().set(faqData);
  }

  // Actualizar una pregunta existente
  Future<void> updateFaq(String key, Map<String, dynamic> faqData) async {
    faqData.remove('key');
    await _faqsRef.child(key).update(faqData);
  }

  // Eliminar una pregunta
  Future<void> deleteFaq(String key) async {
    await _faqsRef.child(key).remove();
  }
}
