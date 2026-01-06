# Asystem Cobacam - Suite de Gestión Académica

**Asystem Cobacam** es una solución integral diseñada para el sistema COBACAM, ofreciendo una experiencia moderna, segura y eficiente para alumnos, docentes y personal administrativo.

## ✨ Novedades de la Versión 1.0.0

### 🛡️ Seguridad Avanzada (Nivel Bancario)
- **Gestión de Sesiones Activas:** Visualiza en tiempo real qué dispositivos tienen acceso a tu cuenta, incluyendo su ubicación (Ciudad, Estado) e IP pública.
- **Revocación Remota (Kill Switch):** Cierra sesiones en otros dispositivos desde tu teléfono. El intruso será expulsado de inmediato gracias al `SessionGuard`.
- **Protección Anti-Fuerza Bruta:** Bloqueo progresivo ante intentos fallidos (10s, 1m, 5m) para prevenir accesos no autorizados.
- **Geolocalización por IP:** Rastreo inteligente de accesos para auditoría de privacidad.

### 🎨 Experiencia de Usuario (UX/UI)
- **Diseño Futurista:** Interfaz responsiva con Material 3, degradados dinámicos y animaciones `FadeInUp`.
- **Header Dinámico:** Saludo personalizado basado en la hora del día (¡Buen día!, ¡Buenas tardes!, ¡Buenas noches!).
- **Multiplataforma:** Optimizado para Android (14+), iOS y Web (HTTPS seguro).

### 🚀 Funcionalidades por Rol
- **Estudiantes:** Credencial digital, horarios y seguimiento de avisos.
- **Prefectura:** Scanner QR de asistencia y reporte de incidencias en tiempo real.
- **Académico:** Gestión de maestros, materias y constructor de horarios automatizado.

## 🛠️ Requisitos Técnicos
- Flutter SDK >= 3.4.0
- Firebase Core & Auth
- Hive para almacenamiento Offline
- Device Info Plus & Http para auditoría de seguridad

## 📥 Despliegue
Para compilar la versión web:
```bash
flutter build web --release
```

---
© 2026 COBACAM - Desarrollado para la excelencia académica y seguridad institucional.
