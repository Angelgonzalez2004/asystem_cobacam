# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.1.1: "Estabilidad y Mantenimiento"

Esta actualización se centra en la robustez técnica del sistema, resolviendo compatibilidades críticas y preparando el terreno para futuras expansiones, manteniendo todas las funcionalidades de la versión "Seguridad y Offline".

### 🛠️ Actualizaciones Técnicas Recientes (v2.1.1)

*   **⚡ Migración de Librerías:** Se reemplazó el paquete obsoleto `flutter_markdown` por **`flutter_markdown_plus`**, asegurando un renderizado de texto enriquecido más estable para el Asistente IA.
*   **🍎 Parche de Estabilidad iOS:** Se corrigieron los permisos en `Info.plist` (añadiendo `NSMicrophoneUsageDescription`) para prevenir cierres inesperados al utilizar la cámara en dispositivos iPhone/iPad.
*   **📦 Optimización de Dependencias:** Se resolvió el "infierno de dependencias" entre los módulos de generación de reportes (`excel`, `pdf`) y procesamiento de imágenes (`image`), logrando una configuración estable y compatible.
*   **🔧 Configuración de Build:** Ajuste de versiones para `build_runner` y `hive_generator` para garantizar una compilación fluida de los adaptadores de base de datos.

---

## 🌟 Funcionalidades Clave (v2.1.0+)

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

### 🛠️ Gestión Administrativa
*   **Incidencias Express:** Reporte de faltas al reglamento en 2 toques.
*   **Generador de Credenciales:** Creación masiva de identificaciones en PDF listas para imprimir.

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
*   **Librerías Clave:** `hive`, `provider`, `mobile_scanner`, `flutter_markdown_plus`, `pdf`, `excel`.

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
    Utilizamos el renderizador `canvaskit` para mejor rendimiento gráfico.
    ```bash
    flutter build web --release --web-renderer canvaskit
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