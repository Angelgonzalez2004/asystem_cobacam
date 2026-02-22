# 🎓 Asystem Cobacam - Plataforma de Gestión Académica Integral

**Asystem Cobacam** es una avanzada plataforma digital en continua evolución, diseñada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su misión es modernizar, centralizar y optimizar los procesos académicos y administrativos, creando un ecosistema seguro y eficiente que conecta a estudiantes, docentes, prefectos y personal directivo.

---

## ✨ Características Principales y Novedades

Asystem Cobacam se enfoca en proporcionar una experiencia integral y eficiente, integrando funcionalidades clave para la gestión educativa moderna y en constante mejora.

### 👥 Gestión de Usuarios y Roles (RBAC)
Un robusto sistema de control de acceso basado en roles (`RBAC`) asegura que cada usuario (Alumno, Prefecto, Académico, Administrador de Plantel, Administrador General) acceda a una interfaz y funcionalidades personalizadas, adaptadas a sus necesidades específicas.

### 🚀 Últimas Actualizaciones (Febrero 2026)

#### 🔐 Seguridad y Autenticación Biométrica
*   **Desbloqueo por Huella/Rostro:** Implementación de autenticación biométrica nativa.
*   **Gestión de Sesiones:** Control de sesiones activas y cierre remoto.

#### 👨‍👩‍👦 Rol de Tutor: Supervisión Integral (Nuevo)
*   **Vinculación Dinámica:** Acceso inmediato a la información del alumno mediante matrícula vinculada.
*   **Seguimiento de Asistencia:** Panel exclusivo para consultar el historial de asistencias, retardos e incidencias en tiempo real.
*   **Consulta por Ciclos:** Selector de ciclos escolares para visualizar datos históricos y credenciales de periodos anteriores.
*   **Interfaz Adaptada:** Dashboard optimizado para el seguimiento académico y comunicación de avisos institucionales.

#### 🪪 Credencialización Digital Inteligente
*   **Generador de Alta Resolución:** Módulo de credencialización capaz de generar identificaciones digitales (1030x666 px).
*   **Sincronización Automática:** Foto de perfil y datos académicos actualizados al instante.
*   **Descarga Controlada:** Límite de seguridad de **3 descargas por mes** para alumnos.
*   **Visor de Tutor:** Los tutores pueden visualizar la credencial del alumno para cualquier ciclo escolar registrado.

#### 🧑‍🎓 Perfil del Alumno: Control y Autonomía
*   **Edición Condicional:** Actualización de datos bajo permiso expreso de Prefectura.
*   **Campo NSS Unificado:** Estandarización de información médica crítica.
*   **Gestión de Foto:** Límite de 3 cambios mensuales para mantener la integridad de la identificación.

#### 👩‍🏫 Herramientas para Prefectura
*   **Autorización por Lotes:** Gestión masiva de permisos de edición de perfil.
*   **Visor de Ciclos:** Administración completa de grupos, horarios y personal docente.

### 📊 Gestión de Asistencia Avanzada
*   **Pase de Lista Flexible:** Registro mediante escaneo de credenciales QR, entrada manual o registro masivo.
*   **Reportes en Excel:** Exportación detallada de asistencias e incidencias con fórmulas automáticas para el cálculo de retardos y justificaciones.
*   **Modo Offline-First:** Funcionalidad completa sin conexión a internet, sincronizando los datos con Firebase cuando la conexión se restablece.

### 🧠 Asistencia con IA (AsystemBot)
Integración con **Gemini 1.5 Flash** para proporcionar asistencia contextual y respuestas en lenguaje natural sobre el funcionamiento de la plataforma y reglamentos institucionales.

---

## 🛠️ Stack Tecnológico Detallado

### Frontend (Multiplataforma)
*   **Flutter 3.22+**: Framework principal para garantizar una interfaz fluida y nativa.
*   **Provider**: Gestión de estado eficiente y reactiva.
*   **Hive**: Base de datos local para soporte *Offline-First*.
*   **Local Auth**: Integración con hardware biométrico (Huella/Rostro).

### Backend & Infraestructura
*   **Firebase Realtime DB**: Estructura de datos NoSQL en tiempo real.
*   **Firebase Authentication**: Manejo de identidades seguro.
*   **Cloud Functions**: Lógica de servidor segura para procesamiento de datos.
*   **Gemini AI API**: Inteligencia artificial generativa para el asistente contextual.

---

## 📈 Roadmap de Implementación (Ciclo 2026A)
1.  **Fase 1:** Migración de datos históricos y validación de matrículas.
2.  **Fase 2:** Despliegue de la versión Web para personal administrativo.
3.  **Fase 3:** Lanzamiento de las apps móviles para alumnos y tutores.
4.  **Fase 4:** Activación del módulo de IA para asistencia en tiempo real.

---

## ⚙️ Despliegue y Configuración

### 1. Requisitos
*   Flutter SDK (v3.22 o superior)
*   Firebase CLI

### 2. Instalación
```bash
git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
cd asystem_cobacam
flutter pub get
```

### 3. Compilación para Web
```bash
flutter build web --release
```

### 4. Despliegue
```bash
firebase deploy --only hosting
```

---

## 📄 Licencia y Créditos
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
Desarrollado para la innovación y excelencia educativa. Todos los derechos reservados.
