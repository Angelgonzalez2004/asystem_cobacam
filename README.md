# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.4.0: "Base de Conocimiento y Consultas Inteligentes"

Esta actualización introduce una robusta base de conocimientos operativa y refina drásticamente las herramientas de consulta de asistencia.

### 🌟 Novedades Destacadas (v2.4.0)

#### 📚 Manual Operativo Digital (FAQ Pro)
*   **Base de Conocimiento Extensa:** Se han integrado **150 preguntas y respuestas** clave, cubriendo todos los roles del sistema:
    *   **Alumnos:** Reglamentos, uniformes, derechos y obligaciones.
    *   **Académica:** Protocolos docentes, exámenes y gestión áulica.
    *   **Administrativo:** Trámites, pagos, becas y mantenimiento.
    *   **Prefectura:** Procedimientos de seguridad, emergencias y bitácoras.
    *   **Sistema:** Soporte técnico, uso de la App y seguridad de datos.
*   **Buscador Inteligente:** Búsqueda en tiempo real con filtrado por categorías y limpieza rápida.

#### 📊 Consulta de Asistencia Avanzada
*   **Selector de Semana Inteligente:** Al seleccionar cualquier día en el calendario, el sistema calcula automáticamente el rango de la semana laboral (Lunes a Viernes).
*   **Lógica de Ciclo Escolar:** Los selectores de fecha ahora respetan estrictamente las fechas de inicio y fin del ciclo escolar activo.
*   **Filtros de Exclusión:** El sistema ignora automáticamente fines de semana (Sábados/Domingos) y días marcados como "No Lectivos" en los cálculos de asistencia y reportes.
*   **Navegación Mejorada:** Las tarjetas de detalle de alumno ahora incluyen un botón de cierre rápido para agilizar la revisión masiva.

#### 🪪 Generador de Credenciales Pro 2.1
*   **Detección de Grupos Robusta:** Detección instantánea de grupos con filtrado local.
*   **Descarga Inteligente (ZIP/PDF):** Maquetación automática de 10 credenciales por hoja para ahorro de papel y descarga masiva en ZIP.

---

## 🛠️ Funcionalidades Base

### 📡 Modo Offline Nativo (Sin Internet)
*   **Persistencia Local:** Uso de **Hive** para almacenar registros de asistencia sin conexión.
*   **Sincronización Automática:** Subida de datos (Color Verde) al recuperar señal de internet.

### 🚑 Sistema de Alerta Médica Crítica
*   **Intervención en Tiempo Real:** Alertas visuales y vibratorias al pasar lista a alumnos con condiciones médicas graves.

### 🤖 AsystemBot: Asistente IA
*   Consultas en lenguaje natural potenciadas por **Gemini 1.5 Flash** para análisis de incidencias y asistencias.

---

## 🏛️ Arquitectura y Tecnologías
*   **Lenguaje:** Dart 3.4+ / Flutter
*   **Base de Datos:** Firebase Realtime Database & Hive (Local).
*   **Hosting:** Firebase Hosting con renderizado CanvasKit para máxima fluidez.
*   **Roles Soportados:** Alumno, Docente, Prefecto, Administrativo de Plantel, Administrador General.

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.