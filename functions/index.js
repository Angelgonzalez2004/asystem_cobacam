const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const cors = require("cors")({ origin: true });

admin.initializeApp();

// Usamos la API v2 de Firebase Functions (Moderna, Node 22 compatible)
exports.chatWithGemini = onRequest({ cors: true }, async (req, res) => {
  // Manejo manual de CORS por si acaso
  return cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    try {
      // 1. VERIFICACIÓN DE SEGURIDAD
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'No autorizado. Falta token.' });
      }

      const idToken = authHeader.split('Bearer ')[1];
      let decodedToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        return res.status(403).json({ error: 'Token inválido o expirado.' });
      }

      // 2. Obtener datos
      const { question, context } = req.body;
      const userRole = decodedToken.role || "Usuario";

      // 3. Obtener API Key de Variable de Entorno (.env)
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        return res.status(500).json({ error: 'API Key no configurada en servidor.' });
      }

      // 4. Llamar a Gemini
      const genAI = new GoogleGenerativeAI(apiKey);
      // Probamos con Flash nuevamente usando la clave nativa del proyecto
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const prompt = `
Eres "AsystemBot", un asistente administrativo inteligente del sistema escolar COBACAM.
Estás hablando con un usuario autenticado (Rol: ${userRole}).

CONTEXTO DE DATOS DEL PLANTEL (Datos reales en tiempo real):
${context || "No hay contexto disponible."}

PREGUNTA DEL USUARIO:
"${question}"

INSTRUCCIONES:
- Responde de manera profesional, concisa y útil.
- Basa tu respuesta estrictamente en los datos proporcionados arriba si te preguntan por hechos.
- Si no hay datos sobre lo que preguntan, dilo claramente.
    `;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      return res.status(200).json({ 
        success: true, 
        answer: text 
      });

    } catch (error) {
      console.error("Error en chatWithGemini:", error);
      return res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  });
});
