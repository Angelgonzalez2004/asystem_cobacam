# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.2.0: "Resolución Inteligente y Seguridad"

Esta actualización introduce un flujo de trabajo avanzado para la gestión de incidencias, mejoras críticas en la seguridad de la localización y una optimización profunda de los reportes.

### 🌟 Nuevas Funcionalidades (v2.2.0)

#### 🛡️ Gestión de Incidencias "Soft-Resolve"
*   **Resolución sin Eliminación:** Ahora los reportes no se eliminan, sino que se "Resuelven" o "Archivan", manteniendo la evidencia histórica.
*   **Bitácora de Acuerdos:** Al resolver una incidencia, se exige un motivo (ej. "Acuerdo con Tutor", "Conducta Corregida") y detalles opcionales.
*   **Visualización Clara:** Los reportes resueltos aparecen en el historial con fecha de cierre y detalles, diferenciados visualmente (tachados y en verde).

#### 📊 Reportes Excel de Grado Médico
*   **Espejo de Datos:** La exportación a Excel ahora incluye **TODOS** los campos del expediente del alumno, incluyendo información médica desglosada (`Alergias`, `Condiciones`, `Estado de Salud`) en columnas independientes.
*   **Formato Profesional:** Encabezados mejorados, columnas de estatus y resolución, y uso de **Emojis/Íconos** (👥, 📅) dentro del archivo para mejor legibilidad.

#### 📅 Calendario Robusto & Localización
*   **Soporte Regional:** Integración nativa de `flutter_localizations` para calendarios y selectores en Español (MX).
*   **Lógica Anti-Bloqueo:** Sistema inteligente que detecta días inhábiles o fines de semana al abrir el calendario y sugiere automáticamente el siguiente día válido, evitando "pantallas grises" o cierres inesperados.

---

## 🌟 Funcionalidades Clave (Consolidadas)

### 📡 Modo Offline Nativo (Sin Internet)
El sistema opera completamente sin conexión a internet cuando es necesario.
*   **Persistencia Inteligente:** Base de datos local segura (Hive) que almacena registros automáticamente.
*   **Sincronización Automática:** Subida de datos a la nube (Firebase) en cuanto se recupera la conexión.
*   **Inicio de Sesión Offline:** Acceso continuo utilizando credenciales cacheadas.

### 📸 Pase de Lista Profesional 2.0
Módulo de asistencia rediseñado para velocidad y precisión.
*   **Escáner Híbrido:** Soporte para códigos QR y de Barras con control de flash integrado.
*   **Buscador Predictivo:** Búsqueda por nombre/matrícula con foto de respaldo para alumnos sin credencial.
*   **Feedback Sensorial:** Confirmaciones visuales (Verde/Rojo) y hápticas (Vibración) para agilizar el flujo de entrada.

### 🤖 AsystemBot: Inteligencia Artificial Escolar
Asistente virtual potenciado por **Gemini 1.5 Flash**.
*   **Consultas Naturales:** Pregunta "¿Quién faltó hoy?" o "Resumen de incidencias" y recibe respuestas analizadas en tiempo real.
*   **Privacidad:** Procesamiento seguro en la nube a través de Firebase Cloud Functions.

---

## 🏛️ Arquitectura del Sistema

El proyecto está construido sobre una arquitectura **escalable y modular**.

### 📱 Stack Tecnológico
*   **Frontend:** [Flutter](https://flutter.dev) (Dart 3.4+) - Material 3.
*   **Backend & Cloud:** [Firebase](https://firebase.google.com)
    *   **Authentication:** Gestión de usuarios.
    *   **Realtime Database:** Sincronización en milisegundos.
    *   **Cloud Functions (Gen 2):** Backend Node.js.
    *   **Hosting:** Despliegue global.
*   **Librerías Clave:** `hive`, `provider`, `mobile_scanner`, `flutter_markdown_plus`, `pdf`, `excel`, `flutter_localizations`.

---

## 🛠️ Configuración y Despliegue

### Requisitos Previos
*   Flutter SDK 3.4+
*   Cuenta de Firebase configurada y CLI instalado.

### Comandos de Desarrollo

**Instalar dependencias:**
```bash
flutter pub get
```

**Generar Adaptadores de Base de Datos (Hive):**
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Despliegue Web (Producción)

1.  **Construir la aplicación:**
    ```bash
    flutter build web --release
    ```

2.  **Desplegar a Firebase Hosting:**
    ```bash
    firebase deploy --only hosting
    ```

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.