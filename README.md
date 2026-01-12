# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.3.1: "Optimización de Credenciales y Estabilidad"

Esta actualización perfecciona el motor de generación masiva de credenciales y asegura la integridad de los datos entre ciclos escolares.

### 🌟 Novedades Destacadas (v2.3.1)

#### 🪪 Generador de Credenciales Pro 2.1
*   **Detección de Grupos Robusta:** Se corrigió la lógica de carga de grupos, ahora el sistema detecta grupos de forma instantánea filtrando localmente, evitando errores de indexación en Firebase.
*   **Limpieza Inteligente:** Al cambiar de grupo, la vista previa se refresca automáticamente, mostrando únicamente a los alumnos del grupo consultado en ese momento.
*   **Descarga Inteligente (ZIP/PDF):** 
    *   **Pack ZIP:** Las imágenes masivas (PNG/JPG) se agrupan automáticamente en archivos comprimidos para facilitar su gestión.
    *   **PDF de Alta Densidad:** Maquetación optimizada para imprimir **10 credenciales por hoja** (5x2), reduciendo el desperdicio de papel.
*   **Control Individual:** Cada credencial cuenta con un botón de descarga directa (⬇️) para obtener la imagen suelta en alta resolución.

#### 🚑 Sistema de Alerta Médica Crítica
*   **Intervención en Tiempo Real:** Activación de alertas manuales para alumnos con condiciones graves. Al pasar lista, el sistema lanza una alerta bloqueante con vibración y datos detallados.
*   **Integración con Excel:** Soporte completo en la importación masiva para activar alertas médicas desde el archivo de origen.

#### 🎨 Experiencia de Usuario Profesional
*   **Rediseño de Dashboards:** Pantallas de Horarios y Días No Lectivos con diseño estilo "Tailwind", más limpio y responsivo.
*   **Seguridad de Fecha:** Bloqueo total de asistencias masivas e individuales en fines de semana y días festivos.

---

## 🛠️ Funcionalidades Base

### 📡 Modo Offline Nativo (Sin Internet)
*   **Persistencia Local:** Uso de **Hive** para almacenar registros de asistencia sin conexión.
*   **Sincronización Automática:** Subida de datos al recuperar señal.

### 🤖 AsystemBot: Asistente IA
*   Consultas en lenguaje natural potenciadas por **Gemini 1.5 Flash** para análisis de incidencias y asistencias.

---

## 🏛️ Arquitectura y Tecnologías
*   **Lenguaje:** Dart 3.4+ / Flutter
*   **Base de Datos:** Firebase Realtime Database & Hive (Local).
*   **Hosting:** Firebase Hosting con renderizado CanvasKit para máxima fluidez.

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.