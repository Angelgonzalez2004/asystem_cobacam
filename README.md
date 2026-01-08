# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Última Actualización: Versión 2.0.0 (Production Ready)

Esta versión marca un hito en la madurez del sistema, incorporando módulos críticos para la operación diaria, herramientas de credencialización y una base de datos robusta y escalable.

### 🌟 Nuevos Módulos Implementados

#### 🆔 Generador Universal de Credenciales
Una herramienta potente para la emisión instantánea de identificaciones estudiantiles.
*   **Diseño Profesional:** Plantillas oficiales con colores institucionales (Azul COBACAM), logo y tipografía estandarizada.
*   **Códigos de Barra (Code 128):** Generación automática de códigos escaneables vinculados a la matrícula para agilizar el pase de lista.
*   **Multi-Formato:** Opción de descarga en **PNG** (Alta Calidad) o **JPG** (Comprimido).
*   **Compatibilidad Universal:** Descarga inteligente adaptada al dispositivo:
    *   📱 **Móvil (Android/iOS):** Guarda directo en Galería.
    *   🌐 **Web:** Descarga automática en el navegador.
    *   💻 **Escritorio:** Guarda en la carpeta de Documentos.

#### 📋 Sistema Avanzado de Asistencia
*   **Pase de Lista Masivo:** Registra la entrada o salida de grupos enteros en segundos, ideal para horas pico.
*   **Modo Offline-First:** ¿Sin internet? No hay problema. El sistema guarda los registros localmente (Hive) y sincroniza automáticamente con la nube (Firebase) cuando recupera la conexión.
*   **Lógica de Negocio:** Detección automática de retardos basada en los horarios de clase configurados, con solicitud obligatoria de justificación.

#### 🔍 Consulta de Asistencia en Tiempo Real
*   **Buscador Global:** Encuentra a cualquier alumno por nombre o matrícula al instante.
*   **Tarjetas de Información Completa:** Visualización detallada con estado (Presente/Falta/Retardo), horas exactas de entrada/salida y motivos de incidencias.
*   **Detección de Faltas:** El sistema cruza la lista de inscritos con los registros del día para identificar ausencias automáticamente.

---

## 🏛️ Arquitectura del Sistema

El proyecto está construido sobre una arquitectura **escalable y modular** utilizando las mejores prácticas de ingeniería de software moderno.

### 📂 Estructura del Proyecto
*   **`lib/models`:** Definiciones de datos tipadas y seguras (`Student`, `Group`, `AttendanceRecord`, `SchoolCycle`).
*   **`lib/services`:** Capa de lógica de negocio desacoplada (`AuthService`, `DatabaseService`, `ConnectivityService`).
*   **`lib/screens`:** Interfaces de usuario organizadas por flujo y rol (`Login`, `Dashboards`, `Management`).
*   **`lib/providers`:** Gestión de estado reactiva (ej. `ThemeProvider`).
*   **`lib/utils`:** Herramientas transversales para animaciones, formateo y componentes UI reutilizables.

### 📱 Stack Tecnológico
*   **Frontend:** [Flutter](https://flutter.dev) (Dart)
    *   Diseño **Material 3** adaptable (Tema Claro/Oscuro).
    *   Responsive Design (Móvil, Tablet, Escritorio, Web).
    *   **Librerías Clave:** `barcode_widget` (Credenciales), `mobile_scanner` (QR), `screenshot` (Captura), `hive` (BD Local).
*   **Backend & Cloud:** [Firebase](https://firebase.google.com)
    *   **Authentication:** Gestión de usuarios y roles segura.
    *   **Realtime Database:** Sincronización de datos en milisegundos con soporte multi-plantel.
    *   **Storage:** Almacenamiento optimizado de imágenes y documentos.
    *   **Hosting:** Despliegue global CDN para la versión web.
*   **Base de Datos Maestra:**
    *   Soporte simultáneo para múltiples planteles (**Atasta, Champotón, Hecelchakán, Xpujil**, etc.).
    *   Historial completo de ciclos escolares y asistencias.

---

## 🛠️ Configuración y Despliegue

### Requisitos Previos
*   Flutter SDK 3.x o superior.
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