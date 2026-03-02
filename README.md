# 🎓 ASYSTEM COBACAM - Plataforma de Excelencia Académica

**ASYSTEM COBACAM** es la evolución digital del **Colegio de Bachilleres del Estado de Campeche**. Una plataforma integral de alto nivel diseñada para centralizar, automatizar y asegurar el control escolar mediante una experiencia de usuario premium, moderna y ultra-profesional.

---

## ✨ Novedad: Herramienta de Digitalización Masiva (Beta de Pruebas)

Hemos desarrollado un módulo especializado para la **Prefectura**, diseñado para cerrar la brecha entre el papel y lo digital. Esta herramienta permite digitalizar hojas de asistencia físicas en cuestión de segundos:

*   **Digitalización de Listas Físicas**: Ideal para cuando se tiene un control en papel con "puntos" de asistencia. Permite marcar o desmarcar alumnos individualmente tras un filtro rápido.
*   **Asignación de Horarios Inteligente**: 
    *   **Modo Automático**: La app consulta el horario oficial del grupo y asigna automáticamente la hora de la primera clase (entrada) o última clase (salida) según el día de la semana seleccionado.
    *   **Modo Manual**: Permite elegir una hora fija para todos los alumnos seleccionados.
*   **Calendario Histórico**: Soporte para registrar asistencias en fechas pasadas dentro del rango del ciclo escolar seleccionado.
*   **Buscador Dual**: Filtrado instantáneo por **Nombre** o **Matrícula** del alumno.
*   **Zona de Peligro (Reset)**: Función protegida con doble confirmación para limpiar la base de datos de asistencias de un ciclo completo durante fases de prueba.

---

## ✨ Experiencia de Usuario Premium

Hemos elevado la estética del sistema a un nivel institucional superior, adoptando una filosofía de diseño **Premium Glassmorphism**:

*   **Interfaz Glassmorphism Refinada**: Pantallas de acceso con efectos de cristal esmerilado sobre gradientes institucionales.
*   **Fondo Institucional Dinámico**: Uso de gradientes profundos (Deep Slate & Royal Blue) con iluminación ambiental.
*   **Visibilidad de Alto Contraste**: Tipografía blanca sólida (`FontWeight.w900`) para una legibilidad perfecta.
*   **Totalmente Responsiva**: Adaptación inteligente a monitores 4K, laptops, tablets y móviles.

---

## 🚀 Funcionalidades Críticas

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

*   **Flutter 3.22+**: Framework principal multiplataforma.
*   **Firebase Ecosystem**: Realtime Database para datos vivos, FCM para notificaciones y Functions (V2) para lógica de backend.
*   **Hive DB**: Base de datos local ultra-rápida para persistencia offline.
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
