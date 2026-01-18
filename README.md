# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Funcionalidades Principales

Un vistazo a las capacidades que hacen de Asystem una herramienta indispensable.

### 🌟 Seguridad Avanzada y Acceso Flexible
*   **Bloqueo de Aplicación Local:** Protege la aplicación con un PIN de 4 dígitos o mediante datos biométricos (huella/rostro), permitiendo asegurar la sesión sin necesidad de cerrar la cuenta. Ideal para mantener el acceso offline.
*   **Gestión de Sesiones Activas:** Los usuarios pueden ver y revocar el acceso en otros dispositivos directamente desde los ajustes.
*   **Autenticación por Roles:** Sistema robusto que dirige a cada usuario (Alumno, Prefecto, Administrador) a su panel de control correspondiente.

### 📡 Modo Offline Nativo (Sin Internet)
*   **Asistencia sin Conexión:** Permite registrar la asistencia de los alumnos incluso sin conexión a internet.
*   **Persistencia Local con Hive:** Los registros se guardan de forma segura en el dispositivo usando una base de datos local de alto rendimiento.
*   **Sincronización Automática:** En cuanto se recupera la conexión, todos los datos locales se suben automáticamente al servidor central de Firebase.

### 🧠 Inteligencia Operativa y Asistencia IA
*   **Centro de Inteligencia (Prefectura):** Un dashboard que responde a 50 preguntas clave sobre disciplina, asistencia y operatividad, con un buscador para filtrar insights al instante.
*   **AsystemBot (Gemini 1.5 Flash):** Un asistente de IA integrado que permite realizar consultas en lenguaje natural para obtener información y ejecutar acciones.
*   **Estadísticas en Tiempo Real:** Gráficos y KPIs dinámicos que muestran tendencias y métricas de asistencia.

### 🚑 Sistema de Alerta Médica Crítica
*   **Protocolo de Seguridad:** Al escanear la credencial de un alumno con una condición médica registrada, el sistema emite una alerta visual y vibratoria inmediata para el prefecto, mostrando la información relevante para una posible intervención.

### 🛠️ Gestión y Operaciones
*   **Pase de Lista con QR:** Registro de entradas y salidas mediante el escaneo de credenciales con códigos QR o Code128, incluyendo la gestión de retardos y salidas anticipadas con motivos.
*   **Registro Manual y Masivo:** Opciones para registrar asistencia de forma manual con un buscador predictivo o aplicar registros masivos a grupos completos.
*   **Visualización y Exportación de Horarios:** Los prefectos pueden visualizar horarios detallados de grupos y profesores, con la opción de exportarlos como imágenes o documentos PDF.
*   **Generación de Reportes:** Exportación de listas de asistencia e incidencias a formato Excel.
*   **Generación de Credenciales:** Creación de credenciales en formato PDF listas para imprimir.
*   **Gestión de Incidencias:** Módulo completo para reportar y dar seguimiento a las incidencias de los alumnos.

---

## 🏛️ Arquitectura y Tecnologías

El proyecto está construido con un enfoque moderno, priorizando el rendimiento, la escalabilidad y la mantenibilidad.

*   **Framework Principal:** [Flutter](https://flutter.dev/) 3.38+
*   **Lenguaje:** [Dart](https://dart.dev/) 3.10+
*   **Backend y Base de Datos:**
    *   **Firebase Realtime Database:** Para la sincronización de datos en tiempo real.
    *   **Firebase Authentication:** Para la gestión de usuarios y roles.
    *   **Firebase Hosting:** Para el despliegue de la aplicación web.
    *   **Cloud Functions for Firebase:** Para lógica de backend.
*   **Almacenamiento Local:** [Hive](https://pub.dev/packages/hive) para una persistencia de datos offline rápida y eficiente.
*   **Gestión de Estado:** [Provider](https://pub.dev/packages/provider) para un manejo de estado simple y reactivo.
*   **Inteligencia Artificial:** [Google AI SDK (Gemini)](https://pub.dev/packages/google_generative_ai) para las funcionalidades del Asistente IA.
*   **Seguridad Local:** [local_auth](https://pub.dev/packages/local_auth) y [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) para el bloqueo con PIN/Biometría.
*   **Funcionalidades Adicionales:**
    *   `dropdown_search`: Para selectores con búsqueda en las pantallas de visualización de horarios.
    *   `screenshot`: Para la captura de widgets y exportación a imagen.
    *   `pdf`: Para la generación de documentos PDF.

---

## ⚙️ Primeros Pasos (Para Desarrolladores)

Sigue estos pasos para configurar el entorno de desarrollo y ejecutar el proyecto.

### **1. Prerrequisitos**
*   Tener [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado (versión 3.38 o superior).
*   Un editor de código como [Visual Studio Code](https://code.visualstudio.com/) o [Android Studio](https://developer.android.com/studio).
*   Tener una cuenta de [Firebase](https://firebase.google.com/) y un proyecto creado.

### **2. Configuración**

```bash
# Clona el repositorio
git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git

# Navega al directorio del proyecto
cd asystem_cobacam

# Instala todas las dependencias
flutter pub get
```

### **3. Configuración de Firebase**

Para que el proyecto se conecte a Firebase, necesitas los archivos de configuración correspondientes. **Estos archivos no deben ser subidos al repositorio por seguridad.**

*   **Android:** Coloca tu archivo `google-services.json` en la carpeta `android/app/`.
*   **iOS:** Abre el proyecto de iOS en Xcode y añade tu archivo `GoogleService-Info.plist` a la carpeta `Runner`.
*   **Web:** La configuración de Firebase para la web ya está integrada en el código y se inicializa en `main.dart` utilizando `firebase_options.dart`.

### **4. Ejecutar la Aplicación**

```bash
# Ejecuta la app en el dispositivo o emulador seleccionado
flutter run
```

---

## 🤝 Cómo Contribuir

Las contribuciones son bienvenidas. Si deseas mejorar el proyecto, sigue estos pasos:

1.  **Crea un Fork** del repositorio.
2.  **Crea una nueva rama** para tu funcionalidad (`git checkout -b feature/AmazingFeature`).
3.  **Realiza tus cambios** y haz commit (`git commit -m 'Add some AmazingFeature'`).
4.  **Haz Push** a tu rama (`git push origin feature/AmazingFeature`).
5.  **Abre un Pull Request** para que tus cambios puedan ser revisados.

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.