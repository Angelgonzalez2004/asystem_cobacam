const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const cors = require("cors")({ origin: true });

admin.initializeApp();

exports.chatWithGemini = onRequest({ cors: true }, async (req, res) => {
  return cors(req, res, async () => {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    try {
      // 1. Auth
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ success: false, error: "No autorizado." });
      }
      const idToken = authHeader.split("Bearer ")[1];
      let decodedToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        return res.status(403).json({ success: false, error: "Token inválido." });
      }

      const { question, context } = req.body;
      const userRole = decodedToken.role || "Usuario";
      
      // USAMOS LA API KEY DE AI STUDIO (La ...Deno que configuraste en .env)
      const apiKey = process.env.GEMINI_API_KEY;

      if (!apiKey) {
        return res.status(500).json({ success: false, error: "Falta API Key." });
      }

      // 2. Inicializar API Pública
      const genAI = new GoogleGenerativeAI(apiKey);
      
      // Probamos gemini-1.5-flash-latest que es el alias más seguro hoy en día
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash-latest" });

      const prompt = `
Eres "AsystemBot", asistente escolar del COBACAM.
Rol usuario: ${userRole}.
Datos del plantel: ${context || "Sin datos."}
Pregunta: "${question}"
INSTRUCCIONES: Responde profesional y breve.
`;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      return res.status(200).json({ success: true, answer: text });

    } catch (error) {
      console.error("Gemini Error:", error);
      // Capturamos el error para verlo claro
      return res.status(500).json({ 
        success: false, 
        error: `Error de IA: ${error.message}` 
      });
    }
  });
});
