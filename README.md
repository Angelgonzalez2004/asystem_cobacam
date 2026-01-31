# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## ✨ Novedades y Mejoras Recientes

*   **Estabilidad y Corrección de Errores:** Se han resuelto varios errores de sintaxis y referencias de métodos, mejorando la robustez general de la aplicación.
*   **Exportación de Horarios Mejorada:** Se ha optimizado la lógica de exportación de horarios individuales y múltiples (tanto para grupos como para maestros) en formatos PDF e imagen (ZIP), asegurando su correcto funcionamiento y la visibilidad de los botones de exportación en todas las condiciones.

---

## 🚀 Funcionalidades Principales

Un vistazo a las capacidades que hacen de Asystem una herramienta indispensable.

### 🌟 Seguridad y Acceso
*   **Bloqueo de Aplicación Local:** Protege la aplicación con PIN o datos biométricos (huella/rostro), asegurando la sesión sin necesidad de cerrar la cuenta.
*   **Gestión de Sesiones Activas:** Permite a los usuarios ver y revocar el acceso en otros dispositivos desde los ajustes.
*   **Autenticación por Roles:** Sistema robusto que dirige a cada usuario a su panel de control personalizado.

### 👤 Roles de Usuario
*   **Alumno:** Consulta su horario y anuncios. Su credencial con código QR es la llave para el registro de asistencia.
*   **Prefecto:** El rol operativo central. Gestiona el pase de lista, registra incidencias, y administra y visualiza todos los horarios.
*   **Administrador de Plantel:** Gestiona los datos académicos de su plantel, como ciclos escolares y grupos.
*   **Administrador General:** Tiene control total sobre la plataforma, incluyendo la gestión de planteles y códigos de acceso.

### 📡 Modo Offline
*   **Asistencia sin Conexión:** Permite registrar la asistencia incluso sin internet. Los datos se guardan localmente y se sincronizan automáticamente al recuperar la conexión.

### 🧠 Inteligencia Operativa y Asistencia IA
*   **Centro de Inteligencia (Prefectura):** Un dashboard que responde a preguntas clave sobre disciplina y asistencia.
*   **AsystemBot (Gemini 1.5 Flash):** Asistente de IA para realizar consultas en lenguaje natural.
*   **Estadísticas en Tiempo Real:** Gráficos y KPIs dinámicos de asistencia.

### 🚑 Sistema de Alerta Médica Crítica
*   Al escanear la credencial de un alumno con una condición médica registrada, el sistema emite una alerta visual y vibratoria inmediata para el prefecto.

### 🗓️ Gestión y Visualización de Horarios
*   **Interfaz de Cuadrícula Profesional:** Se ha rediseñado completamente la visualización de horarios a una **cuadrícula o tabla de estilo tradicional**. Esta vista muestra las horas como filas y los días de la semana como columnas, ofreciendo una lectura mucho más clara e intuitiva.
*   **Gestión Interactiva:** En la pantalla de **gestión de horarios**, los prefectos pueden hacer clic directamente sobre cualquier celda de la cuadrícula para **añadir, editar o eliminar** una sesión de clase, haciendo el proceso más rápido y visual.
*   **Visores Claros y Concisos:** Las pantallas de **"Visor por Grupo"** y **"Visor por Maestro"** utilizan la misma interfaz de cuadrícula en modo de solo lectura para una consulta rápida y sin distracciones.
*   **Exportación Integrada:** Posibilidad de exportar horarios individuales o múltiples a formatos PDF e imagen (ZIP) para facilitar la distribución y archivo.
*   **Lógica de Negocio Respetada:** Todos los cambios son puramente visuales. Se mantiene intacta la lógica de negocio, incluyendo la validación de ciclos cerrados (modo solo lectura) y el manejo de recesos no modificables.
*   **Filtrado y Búsqueda:** Todas las pantallas de horarios permiten filtrar por ciclo escolar y cuentan con una barra de búsqueda para localizar rápidamente el grupo o maestro deseado.

### 🛠️ Operaciones Diarias
*   **Pase de Lista con QR:** Registro de entradas y salidas mediante escaneo de credenciales.
*   **Registro Manual y Masivo:** Opciones para registrar asistencia de forma manual o a grupos completos.
*   **Generación de Reportes:** Exportación de listas de asistencia e incidencias a formato Excel.
*   **Generación de Credenciales:** Creación de credenciales en formato PDF listas para imprimir.

---

## 🏛️ Arquitectura y Tecnologías

*   **Framework Principal:** [Flutter](https://flutter.dev/)
*   **Lenguaje:** [Dart](https://dart.dev/)
*   **Backend y Base de Datos:**
    *   **Firebase Realtime Database:** Para sincronización de datos en tiempo real.
    *   **Firebase Authentication:** Para gestión de usuarios y roles.
    *   **Firebase Hosting:** Para el despliegue web.
    *   **Cloud Functions for Firebase:** Para lógica de backend (Node.js).
*   **Almacenamiento Local:** [Hive](https://pub.dev/packages/hive) para persistencia offline.
*   **Gestión de Estado:** [Provider](https://pub.dev/packages/provider).
*   **Inteligencia Artificial:** [Google AI SDK (Gemini)](https://pub.dev/packages/google_generative_ai).
*   **Seguridad Local:** `local_auth` y `flutter_secure_storage`.

---

## ⚙️ Despliegue y Desarrollo

### 1. Prerrequisitos
*   Tener [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado.
*   Un editor de código como [Visual Studio Code](https://code.visualstudio.com/).
*   Tener una cuenta de [Firebase](https://firebase.google.com/) y el [Firebase CLI](https://firebase.google.com/docs/cli) instalado.

### 2. Configuración
```bash
# Clona el repositorio
git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
cd asystem_cobacam

# Instala dependencias
flutter pub get
```

### 3. Configuración de Firebase
*   **Android/iOS/Web:** Asegúrate de que tu proyecto esté configurado con Firebase. El archivo `lib/firebase_options.dart` es esencial.

### 4. Ejecutar la Aplicación
```bash
flutter run
```

### 5. Compilar y Desplegar en Firebase Hosting
```bash
# Compila la versión de producción para la web
flutter build web

# Despliega la aplicación en Firebase
firebase deploy --only hosting
```

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa. Todos los derechos reservados.