# Asystem Cobacam - Plataforma Integral de Gestión Académica

**Asystem Cobacam** es una aplicación multiplataforma (Android, iOS y Web) diseñada para modernizar y optimizar la gestión escolar de los planteles COBACAM. Enfocada en la seguridad, la eficiencia operativa y una experiencia de usuario de primer nivel.

## 🚀 Características Principales

### 🎨 Diseño y UX
- **Interfaz Futurista:** Diseño limpio con Material 3, gradientes institucionales y animaciones suaves.
- **Responsividad Total:** Se adapta perfectamente a teléfonos móviles, tablets y navegadores web de escritorio.
- **Modo Oscuro/Claro:** Soporte nativo para ambos temas, respetando las preferencias del sistema.
- **Landing Page Informativa:** Pantalla de bienvenida profesional con información detallada por rol.

### 🔐 Seguridad y Privacidad (Core)
- **Anti-Fuerza Bruta:** Sistema de bloqueo inteligente ante múltiples intentos fallidos (10s, 1m, 5m).
- **Gestión de Sesiones:** Auditoría en tiempo real de dispositivos conectados con geolocalización IP.
- **Kill Switch:** Posibilidad de revocar el acceso a dispositivos sospechosos de forma remota.
- **Session Guard:** Expulsión inmediata en tiempo real si la sesión es eliminada desde otro dispositivo.

### 📋 Módulos por Rol
- **Estudiantes:** Consulta de calificaciones, horarios, credencial digital y muro de avisos.
- **Prefectura:** Scanner de asistencia QR, pase de lista digital y reporte de incidencias.
- **Docentes:** Gestión de grupos, materias, maestros y constructor de horarios.
- **Administración:** Estadísticas globales de asistencia y rendimiento, gestión de planteles y comunicados oficiales.

## 🛠️ Tecnologías
- **Framework:** Flutter 3.4+
- **Backend:** Firebase (Auth, Realtime Database, Storage)
- **Base de Datos Local:** Hive (Soporte Offline)
- **Geolocalización:** ipapi.co (HTTPS)
- **Hardware:** Integración con cámara (Scanner QR) y Device Info.

## 📦 Instalación

1. Clona el repositorio.
2. Asegúrate de tener Flutter instalado (`flutter doctor`).
3. Ejecuta `flutter pub get`.
4. Configura tus archivos `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) desde Firebase Console.
5. Ejecuta la app con `flutter run`.

---
© 2026 COBACAM - Desarrollado para la excelencia académica.