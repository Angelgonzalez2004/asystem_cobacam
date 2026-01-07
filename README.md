# Asystem Cobacam - Suite de Gestión Académica

**Asystem Cobacam** es una plataforma integral diseñada para el ecosistema COBACAM, optimizada para ofrecer seguridad, transparencia y una gestión académica de vanguardia.

## 🚀 Novedades de la Versión 1.1.0

### 📸 Gestión de Medios Avanzada
- **Publicación Multimage:** Los administradores ahora pueden subir galerías completas de imágenes en un solo comunicado.
- **Visualización Social:** Interfaz estilo red social para visualizar fotos adjuntas con cuadrículas inteligentes.
- **Soporte Web Nativo:** Se ha corregido el error de carga de archivos en navegadores, permitiendo la gestión de contenidos desde cualquier dispositivo.

### 📊 Datos en Tiempo Real (Real-Time Stats)
- **Contadores Dinámicos:** Dashboards con estadísticas reales de alumnos registrados, académicas activas y planteles operativos, eliminando datos ficticios.
- **Filtrado por Plantel:** Los administradores de sede visualizan métricas exclusivas de su centro de trabajo.

### 🛡️ Seguridad y Auditoría
- **Rastreo de Sesiones:** Sistema de geolocalización por IP y detección de hardware para auditoría de accesos.
- **Session Guard:** Expulsión inmediata de sesiones remotas revocadas.
- **Protección de Fuerza Bruta:** Bloqueo inteligente de accesos ante intentos fallidos.

## 🛠️ Stack Tecnológico
- **Frontend:** Flutter 3.4+ (Material 3)
- **Backend:** Firebase (Auth, RTDB, Storage)
- **Caché Local:** Hive
- **Ubicación:** ipapi.co (Secure HTTPS)

## 📥 Guía de Despliegue Web
```bash
flutter build web --release
firebase deploy --only hosting
```

---
© 2026 COBACAM - Innovación para la excelencia educativa.