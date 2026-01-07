# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Última Actualización: Versión 1.4.0 (Prefect Suite Pro)

Esta actualización transforma radicalmente la experiencia del rol de Prefectura, automatizando procesos complejos y mejorando la organización de datos.

### 🌟 Novedades Destacadas

#### 📅 Ciclos Escolares Inteligentes ("Auto-Pilot")
- **Detección Automática:** El sistema ya no requiere activación manual. Calcula automáticamente cuál es el **Ciclo Actual** basándose en la fecha del servidor/dispositivo y los rangos definidos.
- **Estados Visuales:**
    - 🟢 **EN CURSO (ACTUAL):** Ciclo vigente hoy.
    - 🟠 **PRÓXIMO:** Ciclos futuros programados.
    - 🔴 **FINALIZADO:** Ciclos históricos cerrados.
- **Seguridad:** Elimina el error humano de olvidar cambiar el ciclo, garantizando que los nuevos registros siempre caigan en el periodo correcto.

#### 🗂️ Directorio de Alumnos Jerárquico
- **Organización por Grupos:** La lista plana de alumnos ha evolucionado a un **Árbol de Grupos Expandible**.
    - Ahora ves tarjetas por grupo (ej. "301-B - 25 Alumnos").
    - Al tocar, se despliega la lista detallada de estudiantes.
- **Filtro Histórico:** Selector de Ciclo Escolar para consultar padrones de semestres anteriores sin mezclar datos.
- **Gestión Dual:** Pestañas separadas para "Alumnos Activos" y "Bajas", manteniendo el historial limpio pero accesible.

#### 📊 Importación Masiva Blindada
- **Excel Inteligente:**
    - **Selector de Destino:** Ahora eliges explícitamente a qué Ciclo Escolar vas a importar los datos.
    - **Validación Estricta:** El sistema verifica que las hojas de tu Excel coincidan con los grupos creados en el sistema.
    - **Prevención de Errores:** Si intentas subir un grupo que no existe (ej. "101" cuando solo creaste "101-A"), el sistema bloquea la importación y te avisa para corregirlo.

---

## 🏛️ Arquitectura del Sistema

El proyecto está construido sobre una arquitectura **escalable y modular** utilizando las mejores prácticas de ingeniería de software moderno.

### 📱 Stack Tecnológico
*   **Frontend:** [Flutter](https://flutter.dev) 3.4+ (Dart)
    *   Diseño **Material 3** adaptable (Tema Claro/Oscuro).
    *   Responsive Design (Móvil, Tablet, Escritorio, Web).
*   **Backend & Cloud:** [Firebase](https://firebase.google.com)
    *   **Authentication:** Gestión de usuarios y roles segura.
    *   **Realtime Database:** Sincronización de datos en milisegundos.
    *   **Storage:** Almacenamiento optimizado de imágenes y documentos.
    *   **Hosting:** Despliegue global CDN para la versión web.
*   **Almacenamiento Local:** [Hive](https://docs.hivedb.dev/)
    *   Base de datos NoSQL ultrarrápida para funcionamiento **Offline-First**.
*   **Seguridad:**
    *   **Session Guard:** Monitoreo activo de sesiones concurrentes.
    *   **Auditoría:** Registro de IPs y dispositivos de acceso.

### 👥 Roles y Funcionalidades
1.  **Alumno:** Consulta de calificaciones, horarios, credencial digital y muro de avisos.
2.  **Prefecto:** Pase de lista digital, gestión de incidencias, justificaciones y reportes de asistencia.
3.  **Académica:** Gestión de cargas horarias, asignación docente y control curricular.
4.  **Administrativo Plantel:** Control total de la operación del campus específico.
5.  **Administración General:** Supervisión macro, estadísticas globales y comunicación estatal.

---

## 🛠️ Configuración y Despliegue

### Requisitos Previos
*   Flutter SDK 3.4.0 o superior.
*   Cuenta de Firebase configurada.

### Comandos Útiles

**Instalar dependencias:**
```bash
flutter pub get
```

**Ejecutar en modo desarrollo:**
```bash
flutter run
```

**Analizar código (Linting):**
```bash
flutter analyze
```

**Construir para Web (Producción):**
```bash
flutter build web --release --web-renderer canvaskit
```

**Desplegar a Firebase:**
```bash
firebase deploy --only hosting
```

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa.
Todos los derechos reservados.