# 🎓 Asystem Cobacam - Plataforma de Gestión Académica Integral

**Asystem Cobacam** es una avanzada plataforma digital en continua evolución, diseñada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su misión es modernizar, centralizar y optimizar los procesos académicos y administrativos, creando un ecosistema seguro y eficiente que conecta a estudiantes, docentes, prefectos y personal directivo.

---

## ✨ Características Principales y Novedades

Asystem Cobacam se enfoca en proporcionar una experiencia integral y eficiente, integrando funcionalidades clave para la gestión educativa moderna.

### 👥 Gestión de Usuarios y Roles (RBAC)
Un robusto sistema de control de acceso basado en roles (`RBAC`) asegura que cada usuario (Alumno, Prefecto, Académico, Administrador de Plantel, Administrador General) acceda a una interfaz y funcionalidades personalizadas, adaptadas a sus necesidades específicas.

### 🎓 Gestión Académica y Ciclos Escolares
*   **Gestión de Ciclos Escolares (Prefectura):** Pantalla dedicada para la creación, edición y eliminación de ciclos escolares, permitiendo un control preciso sobre la estructura académica vigente y futura.

### 🧑‍🎓 Perfil del Alumno y Edición Controlada
*   **Visualización de Perfil:** Los alumnos pueden acceder a su propio perfil para revisar sus datos registrados (personales, de contacto, académicos, médicos).
*   **Edición Condicional:** La capacidad de un alumno para editar sus datos (incluida la matrícula) está habilitada bajo dos condiciones clave:
    1.  **Autorización de Prefectura:** La Prefecta debe otorgar autorización específica para la edición del perfil y, de forma independiente, para la matrícula.
    2.  **Ciclo Escolar Actual:** La edición solo es posible si el alumno está visualizando y operando sobre los datos del ciclo escolar actualmente activo en el sistema. Para ciclos pasados o futuros, la información solo será de consulta.
*   **Selección de Ciclo Escolar (Alumno):** Los alumnos ahora pueden seleccionar un ciclo escolar desde su perfil para visualizar sus datos históricos o futuros, aunque la edición se restringe al ciclo actual autorizado.
*   **Confirmación de Guardado:** Tras modificar y guardar datos, el alumno debe confirmar la exactitud de los cambios. Una vez confirmados, los permisos de edición se restablecen, requiriendo una nueva autorización de la Prefecta para futuras modificaciones.
*   **Foto de Credencial:** La foto de perfil del alumno se utiliza automáticamente en la generación de su credencial escolar. Se advierte al alumno que elija cuidadosamente su foto, ya que solo puede cambiarse un número limitado de veces al mes y es visible en su credencial.

### 👩‍🏫 Gestión de Alumnos por Prefectura
*   **Permisos Granulares:** La Prefecta puede autorizar o desautorizar individualmente a cada alumno para editar su perfil, y de forma independiente, para editar su matrícula.
*   **Autorización por Lotes:** Nueva función que permite a la Prefecta autorizar o desautorizar la edición de perfiles y/o matrículas a *todos los alumnos activos del ciclo escolar actual* de forma masiva, optimizando la administración.
*   **Importación y Exportación de Alumnos (Excel):**
    *   **Descarga de Plantilla:** Nuevo botón para descargar una plantilla de Excel que sirve como formato base para la importación masiva de alumnos. Incluye advertencias para modificar la plantilla con datos reales y correspondientes al ciclo escolar seleccionado, ajustando los grupos según sea necesario.

### 📊 Gestión de Asistencia Avanzada
*   **Pase de Lista Flexible:** Registro de entradas y salidas mediante escaneo de credenciales QR, entrada manual o registro masivo para grupos.
*   **Reporte Detallado de Asistencias (NUEVO):**
    *   Permite generar reportes Excel con información granular de los eventos de asistencia.
    *   El usuario puede elegir exportar únicamente los registros de **"Entradas"** o de **"Salidas"**.
    *   Incluye columnas específicas: `Matrícula`, `Nombre`, `Grupo`, `Fecha`, `Hora Actual`, `Hora Programada`, `Motivo de Incidencia`, `Asistencia`, `Observaciones`.
    *   Las columnas `Motivo de Incidencia` y `Asistencia` se autocompletan con **fórmulas de Excel** inteligentes que detectan si el alumno llegó tarde o salió temprano, proporcionando el motivo correspondiente.
    *   El archivo Excel incluye una hoja adicional llamada "**Tipos de Incidencia**" que sirve como referencia de las categorías de incidentes.
    *   El archivo se descarga con el formato: `FORMATOASISTENCIAS_DD_MM_YYYY.xlsx`.
*   **Importación y Exportación Excel:**
    *   **Descarga de Plantillas:** Genera plantillas de Excel para "Entrada" o "Salida" facilitando la preparación de datos. La plantilla de importación ahora incluye un **menú desplegable de validación de datos** en la columna "Motivo de Incidencia" (Columna H) con opciones predefinidas (retrasos, salidas anticipadas, tipos de incidencia). Las opciones se gestionan desde una hoja oculta en el mismo archivo.
    *   **Importación Masiva:** Permite cargar registros de asistencia desde archivos Excel, agilizando la actualización de la base de datos.
*   **Modo Offline-First:** La asistencia puede registrarse **sin conexión a internet**. Los datos se guardan localmente (usando Hive) y se sincronizan automáticamente con Firebase al recuperar la conexión, garantizando la continuidad operativa.

### 🧠 Inteligencia Operativa y Asistencia con IA
*   **AsystemBot (Gemini 1.5 Flash):** Un asistente de inteligencia artificial que proporciona respuestas y ayuda contextual a los usuarios en lenguaje natural, integrado de forma segura a través de Cloud Functions.
*   **Centro de Inteligencia (Prefectura):** Dashboard con estadísticas y KPIs dinámicos sobre disciplina y asistencia.

### 🛡️ Seguridad y Control
*   **Bloqueo de Aplicación Local:** Protege la sesión con PIN o datos biométricos.
*   **Gestión de Sesiones Activas:** Permite visualizar y revocar el acceso desde otros dispositivos.
*   **Alerta Médica Crítica:** Emite una alerta visual y vibratoria instantánea al escanear credenciales de alumnos con condiciones médicas registradas.

### 🗓️ Gestión y Visualización de Horarios
*   **Interfaz de Cuadrícula Profesional:** Rediseño completo de la visualización de horarios a un formato de cuadrícula intuitivo (horas como filas, días como columnas).
*   **Gestión Interactiva:** Edición directa de sesiones de clase haciendo clic en las celdas de la cuadrícula.
*   **Visores Claros y Concisos:** Vistas de solo lectura para horarios por grupo y maestro.
*   **Exportación Integrada:** Exporta horarios individuales o múltiples a PDF e imagen (ZIP), con orientación vertical optimizada.
*   **Filtrado y Búsqueda:** Búsqueda avanzada por materia, maestro o grupo.

### 🛠️ Operaciones Diarias Adicionales
*   **Generación de Reportes:** Exportación de listas de asistencia e incidencias a formato Excel.
*   **Generación de Credenciales:** Creación de credenciales en formato PDF listas para imprimir.

---

## 🏛️ Arquitectura y Tecnologías Clave

*   **Framework Frontend:** [Flutter](https://flutter.dev/) para una experiencia multiplataforma nativa.
*   **Lenguaje:** [Dart](https://dart.dev/).
*   **Backend y Servicios en la Nube:**
    *   **Firebase Realtime Database:** Base de datos NoSQL en tiempo real para sincronización y persistencia.
    *   **Firebase Authentication:** Gestión robusta de usuarios y autenticación segura.
    *   **Firebase Hosting:** Despliegue rápido y escalable de la aplicación web.
    *   **Cloud Functions for Firebase (Node.js):** Lógica de backend sin servidor, utilizada para la interacción segura con la API de Gemini (protegiendo claves y personalizando prompts).
*   **Almacenamiento Local Offline:** [Hive](https://pub.dev/packages/hive) para una persistencia de datos local rápida y eficiente.
*   **Gestión de Estado:** [Provider](https://pub.dev/packages/provider) para una gestión reactiva y escalable del estado de la aplicación.
*   **Inteligencia Artificial:** [Google AI SDK (Gemini)](https://pub.dev/packages/google_generative_ai) para capacidades de IA.
*   **Otras Librerías:**
    *   `file_picker` y `excel`: Para la manipulación de archivos Excel.
    *   `mobile_scanner`: Para el escaneo de códigos QR.
    *   `local_auth` y `flutter_secure_storage`: Para seguridad local y almacenamiento seguro.
    *   `path_provider`: Para acceso a directorios del sistema de archivos.

---

## ⚙️ Despliegue y Desarrollo

### 1. Prerrequisitos
*   Tener [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado.
*   Un editor de código como [Visual Studio Code](https://code.visualstudio.com/).
*   Tener una cuenta de [Firebase](https://firebase.google.com/) y el [Firebase CLI](https://firebase.google.com/docs/cli) instalado y configurado.

### 2. Configuración del Proyecto
```bash
# Clona el repositorio
git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
cd asystem_cobacam

# Instala las dependencias de Flutter
flutter pub get

# Genera los archivos necesarios (ej. para Hive, json_serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Asegúrate de que tu proyecto Firebase esté correctamente configurado.
# El archivo `lib/firebase_options.dart` es crucial para la conexión de la app con tu proyecto Firebase.
```

### 3. Ejecutar la Aplicación en Desarrollo
```bash
# Para ejecutar en un dispositivo o emulador
flutter run
```

### 4. Compilar y Desplegar en Firebase Hosting
```bash
# Compila la versión de producción para la web
flutter build web

# Despliega la aplicación web en Firebase Hosting
# Asegúrate de haber configurado tu proyecto Firebase con `firebase init` y de estar autenticado con `firebase login`.
firebase deploy --only hosting
```

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa. Todos los derechos reservados.