# 🎓 ASYSTEM COBACAM - Plataforma de Excelencia Académica

**ASYSTEM COBACAM** es la evolución digital del **Colegio de Bachilleres del Estado de Campeche**. Una plataforma integral de alto nivel diseñada para centralizar, automatizar y asegurar el control escolar mediante una experiencia de usuario premium, moderna y ultra-profesional.

---

## ✨ Novedad: Visor de Horarios Generales para Alumnos (100% Solo Lectura)

Hemos incorporado un módulo de consulta de horarios sumamente intuitivo y seguro, adaptado especialmente para el rol de **Alumno**:

*   **Acceso Centralizado**: Disponible directamente desde el menú lateral (`AppDrawer`) en la sección *INFORMACIÓN ESCOLAR*, y a través de una tarjeta de acceso rápido con diseño dinámico en el Dashboard principal.
*   **Lógica Inteligente de Contingencia (Fallback)**:
    *   Si el área académica o prefectura aún no ha registrado un horario personalizado para el grupo del alumno, la aplicación activa un respaldo automático mostrando el **Horario Matutino Estándar (07:00 AM - 02:00 PM)**.
    *   Evita pantallas vacías o fallos técnicos, informando claramente al alumno a través de una etiqueta azul que indica **"Matutino Estándar"** y una tarjeta de advertencia oficial en la parte inferior.
*   **Gestión de Horarios Especiales**: Cuando el plantel registra un horario específico, el sistema lo mapea automáticamente en tiempo real usando la ruta de Firebase `planteles/${campusId}/schedules/${cycleId}/${groupId}`, mostrando etiquetas en verde esmeralda que indican **"Especial"**.
*   **Consultas Históricas Multi-Ciclo**: Integra un selector dinámico de Ciclos Escolares que permite al alumno revisar con retroactividad sus horarios de grupos en periodos escolares anteriores.
*   **Diseño Premium con Micro-Animaciones**: Cada día de la semana (Lunes a Viernes) tiene una coloración institucional curada y una presentación secuencial animada mediante efectos `FadeInUp` para brindar una sensación de fluidez y modernidad.
*   **Seguridad Inquebrantable**: El panel es completamente de **Solo Lectura** (Read-Only). No contiene botones de alteración, formularios de guardado, ni selectores editables, garantizando la inmutabilidad de los datos por parte de los estudiantes.

---

## ✨ Herramienta de Digitalización Masiva para Prefectura

Diseñada para cerrar la brecha entre el papel y lo digital, esta herramienta permite digitalizar hojas de asistencia físicas en cuestión de segundos:

*   **Digitalización de Listas Físicas**: Ideal para cuando se lleva un control en papel con "puntos" de asistencia. Permite marcar o desmarcar alumnos individualmente tras un filtro rápido.
*   **Asignación de Horarios Inteligente**: 
    *   **Modo Automático**: La app consulta el horario oficial del grupo y asigna automáticamente la hora de la primera clase (entrada) o última clase (salida) según el día de la semana seleccionado.
    *   **Modo Manual**: Permite elegir una hora fija para todos los alumnos seleccionados.
*   **Calendario Histórico**: Soporte para registrar asistencias en fechas pasadas dentro del rango del ciclo escolar seleccionado.
*   **Buscador Dual**: Filtrado instantáneo por **Nombre** o **Matrícula** del alumno.
*   **Zona de Peligro (Reset)**: Función protegida con doble confirmación para limpiar la base de datos de asistencias de un ciclo completo durante fases de prueba.

---

## ⚡ Robustez Offline-First (Resistencia a cortes de Internet)

La aplicación implementa una arquitectura altamente tolerante a fallos de conectividad, ideal para planteles con señal de red inestable o nula:
*   **Persistencia Local Inmediata**: En caso de pérdida de internet o datos móviles durante el pase de lista (QR o manual), los eventos se resguardan de manera segura en la base de datos local cifrada del dispositivo a través de `Hive`.
*   **Sincronización Transparente**: Una vez detectada la restauración de la red por el `ConnectivityService`, la aplicación sincroniza en segundo plano las asistencias locales pendientes hacia Firebase Realtime Database sin interrumpir la operación del prefecto.

---

## 🚀 Funcionalidades Críticas de la Plataforma

### 🔔 Notificaciones en Tiempo Real (FCM)
*   **Alerta Inmediata**: Notificación push automática al dispositivo del tutor al momento del registro.
*   **Seguridad Estudiantil**: Informa exactamente el tipo de movimiento (Entrada/Salida) y la hora registrada.
*   **Multiplataforma**: Soporte nativo en Android, iOS y PWA.

### 👨‍👩‍👦 Control Total para Tutores
*   **Vinculación Automática**: Asociación inmediata tutor-alumno mediante validación de matrícula.
*   **Dashboard de Asistencia**: Estadísticas mensuales, conteo de inasistencias y banners de estado académico en tiempo real.
*   **Alertas Médicas**: Visualización de condiciones de salud críticas para seguimiento preventivo.

### 📊 Gestión de Prefectura y Administración
*   **Pase de Lista QR**: Escaneo de alta velocidad con motor de sincronización Offline-First.
*   **Gestor de Ciclos y Horarios**: Control total sobre periodos escolares, materias y personal docente.
*   **Generador de Credenciales**: Exportación de identificaciones en alta resolución con vinculación de datos dinámica.

---

## 🛠️ Arquitectura Tecnológica

*   **Flutter 3.22+**: Framework principal multiplataforma para Web, Android e iOS.
*   **Firebase Ecosystem**: Realtime Database para datos vivos, FCM para notificaciones, Firebase Hosting para despliegue web y Functions (V2) para lógica de backend.
*   **Hive DB**: Base de datos local ultra-rápida para persistencia offline y caché de configuraciones.
*   **Gemini 1.5 Flash (IA)**: Asistente bot integrado para soporte y consultas reglamentarias.

---

## ⚙️ Implementación y Despliegue

### 1. Preparación de Entorno
```bash
git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
cd asystem_cobacam
flutter pub get
```

### 2. Compilación para Producción (Web)
```bash
# Genera la versión final optimizada para despliegue
flutter build web --release
```

### 3. Lanzamiento al Hosting
```bash
# Despliegue en Firebase Hosting
firebase deploy --only hosting
```

---

## 📄 Licencia e Identidad
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.  
*Gestión Escolar Inteligente, Excelencia Educativa.*  
Desarrollado para la innovación y el control total de la comunidad académica.
