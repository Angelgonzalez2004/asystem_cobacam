const { onValueCreated } = require("firebase-functions/v2/database");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const cors = require("cors")({ origin: true });

admin.initializeApp();

/**
 * Función que se dispara cuando se crea un registro de asistencia en cualquier plantel.
 * Ruta: /planteles/{campusId}/attendance/{cycleId}/{studentId}/{dateId}
 */
exports.sendAttendanceNotification = onValueCreated(
  "/planteles/{campusId}/attendance/{cycleId}/{studentId}/{dateId}",
  async (event) => {
    const { campusId, studentId, cycleId } = event.params;
    const attendanceData = event.data.val();

    try {
      // 1. Obtener datos del alumno para saber el género y nombre
      const studentSnap = await admin.database()
        .ref(`planteles/${campusId}/students/${cycleId}/${studentId}`)
        .get();

      if (!studentSnap.exists()) {
        console.log(`Alumno ${studentId} no encontrado.`);
        return;
      }

      const student = studentSnap.val();
      const isFemenino = (student.gender || "").toLowerCase() === "femenino";
      const labelAlumno = isFemenino ? "La alumna" : "El alumno";
      const studentName = student.fullName || "Estudiante";

      // 2. Determinar si es Entrada o Salida
      let actionType = "ingresar al";
      if (attendanceData.exitTime && !attendanceData.entryTime) {
        actionType = "salir del";
      } else if (attendanceData.exitTime && attendanceData.entryTime) {
        actionType = "salir del";
      }

      const messageTitle = "Aviso de Asistencia";
      const messageBody = `${labelAlumno} ${studentName} acaba de ${actionType} plantel.`;

      // 3. Obtener los IDs de los tutores vinculados
      const guardianUserIds = student.guardianUserIds || [];
      if (guardianUserIds.length === 0) {
        console.log("No hay tutores vinculados a este alumno.");
        return;
      }

      // 4. Buscar tokens FCM de cada tutor
      const tokens = [];
      for (const tutorId of guardianUserIds) {
        const userSnap = await admin.database().ref(`users/${tutorId}`).get();
        if (userSnap.exists()) {
          const userData = userSnap.val();
          if (userData.fcmTokens) {
            Object.values(userData.fcmTokens).forEach(token => {
              if (token) tokens.push(token);
            });
          }
        }
      }

      if (tokens.length === 0) {
        console.log("No se encontraron dispositivos registrados para los tutores.");
        return;
      }

      // 5. Enviar las notificaciones
      const payload = {
        notification: {
          title: messageTitle,
          body: messageBody,
        },
        data: {
          studentId: studentId,
          type: "attendance",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      };

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data
      });

      console.log(`Notificaciones enviadas: ${response.successCount}. Errores: ${response.failureCount}`);

    } catch (error) {
      console.error("Error enviando notificación:", error);
    }
  }
);

/**
 * Función para chatear con Gemini (AsystemBot)
 */
exports.chatWithGemini = onRequest({ cors: true }, async (req, res) => {
  return cors(req, res, async () => {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    try {
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
      const apiKey = process.env.GEMINI_API_KEY;

      if (!apiKey) {
        return res.status(500).json({ success: false, error: "Falta API Key en el servidor." });
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash-latest" });

      const prompt = `
Eres "AsystemBot", asistente escolar del COBACAM.
Rol usuario: ${userRole}.
Datos del plantel: ${context || "Sin datos."}
Pregunta: "${question}"
INSTRUCCIONES: Responde de forma profesional, amable y breve.
`;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      return res.status(200).json({ success: true, answer: text });

    } catch (error) {
      console.error("Gemini Error:", error);
      return res.status(500).json({ 
        success: false, 
        error: `Error de IA: ${error.message}` 
      });
    }
  });
});
