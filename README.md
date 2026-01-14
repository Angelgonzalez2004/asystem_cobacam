# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.4.1: "Ajuste de Calendarios y Estabilidad"

Esta actualización menor refina la lógica de selección de fechas en el módulo de Consultas.

### 🌟 Novedades Destacadas (v2.4.1)

#### 📅 Calendario Inteligente (Corrección)
*   **Bloqueo Total de Días No Lectivos:** Se corrigió el selector de "Semana" en Consultas de Asistencia. Ahora, los días marcados como "No Lectivos" aparecen visualmente bloqueados (gris) y no son seleccionables, igualando el comportamiento del selector diario para evitar errores operativos.

#### 📚 Manual Operativo Digital (FAQ Pro)
*   **Base de Conocimiento Extensa:** Se han integrado **150 preguntas y respuestas** clave, cubriendo todos los roles del sistema.
*   **Buscador Inteligente:** Búsqueda en tiempo real con filtrado por categorías y limpieza rápida.

#### 📊 Consulta de Asistencia Avanzada
*   **Selector de Semana Inteligente:** Cálculo automático del rango semanal (Lunes-Viernes).
*   **Exclusión Automática:** El sistema ignora días inhábiles en el cálculo de estadísticas de faltas.

---

## 🛠️ Funcionalidades Base

### 📡 Modo Offline Nativo (Sin Internet)
*   **Persistencia Local:** Uso de **Hive** para almacenar registros de asistencia sin conexión.
*   **Sincronización Automática:** Subida de datos (Color Verde) al recuperar señal de internet.

### 🚑 Sistema de Alerta Médica Crítica
*   **Intervención en Tiempo Real:** Alertas visuales y vibratorias al pasar lista a alumnos con condiciones médicas graves.

### 🤖 AsystemBot: Asistente IA
*   Consultas en lenguaje natural potenciadas por **Gemini 1.5 Flash**.

---

## 🏛️ Arquitectura y Tecnologías
*   **Lenguaje:** Dart 3.4+ / Flutter
*   **Base de Datos:** Firebase Realtime Database & Hive (Local).
*   **Hosting:** Firebase Hosting con renderizado CanvasKit.
*   **Roles Soportados:** Alumno, Docente, Prefecto, Administrativo de Plantel, Administrador General.

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.