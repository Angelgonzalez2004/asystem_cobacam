# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.3.0: "Gestión Masiva y Seguridad Estudiantil"

Esta actualización representa un salto cualitativo en la capacidad de procesamiento administrativo y en la protección proactiva de los estudiantes.

### 🌟 Novedades Destacadas (v2.3.0)

#### 🪪 Generador de Credenciales Pro 2.0
*   **Procesamiento Masivo por Grupo:** Ahora es posible cargar y generar las credenciales de un grupo completo con un solo clic seleccionando el ciclo escolar.
*   **Descarga Inteligente (ZIP/PDF):** 
    *   Implementación de descargas en archivos **.zip** cuando se generan múltiples imágenes (PNG/JPG) para mantener el orden.
    *   **PDF Optimizado:** Nuevo algoritmo de maquetación que ajusta hasta **10 credenciales por hoja** (5x2), optimizando el ahorro de papel.
*   **Control Individual:** Cada credencial en la vista previa cuenta con su propio botón de descarga rápida y opción de eliminación.
*   **Alta Resolución:** Captura de imágenes con `pixelRatio: 3.0` para una impresión nítida y profesional.

#### 🚑 Sistema de Alerta Médica Inteligente
*   **Gatillo de Seguridad Manual:** Se añadió el campo `medicalAlert` al expediente del alumno. Los administradores pueden activar esta bandera solo para casos de gravedad (Diabetes, Epilepsia, etc.).
*   **Intervención en Pase de Lista:** Al escanear a un alumno con la alerta activa, el sistema lanza un **diálogo de emergencia bloqueante** con vibración de alto impacto, mostrando instantáneamente: **Estado General, Condiciones y Alergias**.
*   **Importación Masiva:** El importador de Excel ahora soporta la columna `alerta_medica` (SI/NO) para configurar la seguridad de cientos de alumnos en segundos.

#### 🎨 Rediseño Visual "Dashboard Profesional"
*   **Pantallas Modernizadas:** Se aplicó un rediseño completo a las secciones de **Horarios de Grupo** y **Días No Lectivos** utilizando principios de diseño limpio (estilo Tailwind/Material 3).
*   **UX Responsiva:** Uso de contenedores restringidos y layouts adaptativos que garantizan una experiencia fluida tanto en dispositivos móviles como en pantallas de escritorio.
*   **Semántica de Colores:** Uso de códigos de color consistentes (Teal para entradas, Indigo para salidas, Naranja para suspensiones).

---

## 🛠️ Funcionalidades Base

### 📡 Modo Offline Nativo (Sin Internet)
*   **Persistencia Local:** Uso de **Hive** para almacenar registros de asistencia sin conexión.
*   **Sincronización Automática:** Subida de datos en segundo plano al recuperar señal.

### 📸 Pase de Lista Profesional
*   **Escáner Híbrido:** Soporte para QR y Código de Barras (Code 128).
*   **Validación de Horarios:** El sistema detecta automáticamente retardos y salidas anticipadas basándose en el horario del grupo.
*   **Protección de Fechas:** Bloqueo automático de registros en fines de semana y días no lectivos configurados.

### 🤖 AsystemBot: Asistente IA
*   Consultas en lenguaje natural potenciadas por **Gemini 1.5 Flash**.

---

## 🏛️ Arquitectura y Tecnologías
*   **Lenguaje:** Dart 3.4+ / Flutter
*   **Base de Datos:** Firebase Realtime Database & Hive (Local).
*   **Backend:** Firebase Cloud Functions (Gen 2).
*   **Hosting:** Firebase Hosting con renderizado CanvasKit.

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.