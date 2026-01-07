# Asystem Cobacam - Suite de Gestión Académica

**Asystem Cobacam** es una plataforma integral diseñada para el ecosistema COBACAM, optimizada para ofrecer seguridad, transparencia y una gestión académica de vanguardia.

## 🚀 Novedades de la Versión 1.2.0 (Smart Media Update)

### 📸 Visualización de Medios Profesional
- **Smart Image Grid:** Nuevo sistema de visualización inteligente que adapta automáticamente imágenes verticales y horizontales sin recortes.
- **Efecto Inmersivo:** Las imágenes individuales se presentan con un fondo desenfocado elegante para mantener la estética sin perder información.
- **Visor Lightbox:** Navegación a pantalla completa con soporte para zoom, gestos y transiciones fluidas.

### 📥 Sistema de Descargas Universal
- **Descarga Inteligente:** Posibilidad de guardar una sola imagen o la galería completa de un aviso con un solo clic.
- **Multi-Plataforma:** Soporte nativo para guardar en la Galería (Android/iOS) y en el Sistema de Archivos (Windows/macOS/Web).

### 👥 Gestión Colaborativa de Avisos
- **Permisos Jerárquicos:**
    - **Admin General:** Gestión total de avisos de nivel Dirección General.
    - **Admin Plantel:** Colaboración completa entre administrativos del mismo plantel.
- **Privacidad Estricta:** Filtrado robusto que garantiza que cada nivel vea y gestione estrictamente lo que le corresponde.

## 🚀 Versiones Anteriores (v1.1.0)
- **Publicación Multimage:** Subida de galerías completas.
- **Datos en Tiempo Real:** Contadores dinámicos de alumnos y planteles.
- **Seguridad:** Rastreo de sesiones y protección contra fuerza bruta.

## 🛠️ Stack Tecnológico
- **Frontend:** Flutter 3.4+ (Material 3)
- **Backend:** Firebase (Auth, RTDB, Storage)
- **Caché Local:** Hive
- **Dependencias Clave:** `gal`, `photo_view` (custom impl), `file_picker`.

## 📥 Guía de Despliegue Web
```bash
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

---
© 2026 COBACAM - Innovación para la excelencia educativa.