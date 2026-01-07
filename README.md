# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Última Actualización: Versión 1.3.0 (Smart Management Update)

Esta versión introduce mejoras críticas en la experiencia de usuario y la lógica de negocio administrativa.

### 🌟 Novedades Destacadas

#### 📸 Gestión de Medios Profesional ("Smart Grid")
- **Visualización Inteligente:** Nuevo motor de renderizado que detecta automáticamente la orientación de las imágenes (vertical/horizontal).
    - **Anti-Recorte:** Las imágenes verticales (como convocatorias o volantes) se muestran completas, centradas y con un fondo desenfocado estético ("Blur Effect"), eliminando cortes indeseados.
    - **Mosaicos Dinámicos:** Si se suben múltiples fotos, se organizan automáticamente en collages tipo red social (1, 2, 3, 4+ elementos).
- **Visor Inmersivo (Lightbox):** Al tocar cualquier imagen, se abre un visor a pantalla completa con soporte para **Zoom** (pellizcar) y deslizamiento fluido.

#### 📥 Sistema Universal de Descargas
- **Compatibilidad Total:** Funciona en **Android, iOS, Windows, macOS y Web**.
- **Descarga Inteligente:**
    - **Individual:** Guarda la foto que estás viendo con un clic.
    - **Masiva:** Opción para "Descargar todas las imágenes" de un aviso en un solo paquete.
- **Nativo:** En móviles guarda directo en la Galería; en escritorio abre el explorador de archivos.

#### 🛡️ Lógica de Gestión "Context-Aware"
- **Separación de Entornos para Admins de Plantel:**
    - **Inicio (Modo Lectura):** Ven avisos de Dirección General + Avisos de su Plantel (Visión completa).
    - **Gestión (Modo Edición):** Solo ven los avisos de SU propio plantel. Los avisos generales se ocultan para mantener el área de trabajo limpia y evitar errores.
- **Colaboración Jerárquica:**
    - Múltiples administrativos de un mismo plantel pueden editar/borrar los avisos de sus colegas del mismo centro (trabajo en equipo).
    - Administradores Generales tienen control total sobre los comunicados de nivel estatal.
    - Estricta segregación: Un plantel nunca puede ver ni tocar los avisos de otro plantel.

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
