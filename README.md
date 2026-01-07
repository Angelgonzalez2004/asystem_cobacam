# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Última Actualización: Versión 1.5.0 (Optimization & Stability)

Esta versión se centra en la estabilidad del código, la optimización del rendimiento y la mejora de la calidad del software mediante un análisis estático riguroso.

### ✅ Mejoras de Calidad de Código
*   **Limpieza Profunda (Linting):** Se han resuelto todas las advertencias y errores detectados por `flutter analyze`.
*   **Optimización de Constantes:** Uso extensivo de constructores `const` para reducir la reconstrucción de widgets y mejorar el rendimiento de la UI.
*   **Refactorización de Lógica:** Eliminación de verificaciones nulas redundantes y código muerto en los módulos de gestión de grupos y horarios.

### 🌟 Funcionalidades Clave

#### 📅 Gestión Académica y Horarios
- **Ciclos Escolares:** Administración flexible de semestres (A/B) y periodos propedéuticos.
- **Gestión de Grupos:** Creación y edición intuitiva de grupos, con validación de lógica de semestres (par/impar).
- **Editor de Horarios:** Interfaz visual para asignar horas de entrada y salida por día de la semana, con validaciones para evitar errores lógicos (entrada > salida).
- **Protección de Datos:** Modo "Solo Lectura" automático para ciclos escolares cerrados, garantizando la integridad histórica de la información.

#### 🛡️ Seguridad y Control de Acceso
- **Autenticación Robusta:** Integración segura con Firebase Auth.
- **Roles y Permisos:** Lógica segregada por roles (Alumno, Prefecto, Administrador).
- **Gestión de Sesiones:** Monitoreo activo para prevenir accesos no autorizados y sesiones concurrentes indebidas.

#### 📊 Dashboard Responsivo
- **Diseño Adaptativo:** Interfaces que escalan inteligentemente desde móviles hasta pantallas de escritorio.
- **Grillas Dinámicas:** Visualización optimizada de listados de grupos y alumnos según el espacio disponible.

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
*   **Backend & Cloud:** [Firebase](https://firebase.google.com)
    *   **Authentication:** Gestión de usuarios y roles segura.
    *   **Realtime Database:** Sincronización de datos en milisegundos.
    *   **Storage:** Almacenamiento optimizado de imágenes y documentos.
    *   **Hosting:** Despliegue global CDN para la versión web.
*   **Almacenamiento Local:** [Hive](https://docs.hivedb.dev/)
    *   Base de datos NoSQL ultrarrápida para persistencia de configuraciones y funcionamiento **Offline-First**.

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
