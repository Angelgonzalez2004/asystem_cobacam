# 🎓 Asystem Cobacam - Plataforma de Gestión Académica Integral

**Asystem Cobacam** es una avanzada plataforma digital en continua evolución, diseñada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su misión es modernizar, centralizar y optimizar los procesos académicos y administrativos, creando un ecosistema seguro y eficiente que conecta a estudiantes, docentes, prefectos y personal directivo.

---

## ✨ Características Principales y Novedades

Asystem Cobacam se enfoca en proporcionar una experiencia integral y eficiente, integrando funcionalidades clave para la gestión educativa moderna y en constante mejora.

### 👥 Gestión de Usuarios y Roles (RBAC)
Un robusto sistema de control de acceso basado en roles (`RBAC`) asegura que cada usuario (Alumno, Prefecto, Académico, Administrador de Plantel, Administrador General) acceda a una interfaz y funcionalidades personalizadas, adaptadas a sus necesidades específicas.

### 🚀 Últimas Actualizaciones (Febrero 2026)

#### 🔐 Seguridad y Autenticación Biométrica
*   **Desbloqueo por Huella/Rostro:** Implementación de autenticación biométrica nativa. Los usuarios pueden proteger el acceso a la aplicación utilizando los sensores de su dispositivo (huella dactilar o reconocimiento facial), complementando el bloqueo por PIN existente.
*   **Gestión de Sesiones:** Visualización y control de sesiones activas en múltiples dispositivos, con opción de cierre de sesión remoto por seguridad.

#### 🪪 Credencialización Digital Inteligente
*   **Generador de Alta Resolución:** Módulo de credencialización capaz de generar identificaciones digitales y para impresión en alta definición (1030x666 px).
*   **Sincronización Automática:**
    *   **Foto de Perfil:** La foto que el alumno sube a su perfil se sincroniza automáticamente con su credencial digital.
    *   **Fallback de Género:** Si el alumno no tiene foto, la credencial muestra automáticamente un icono representativo según su género.
*   **Descarga Controlada:** Los alumnos pueden descargar su credencial digital (formato PNG) directamente a su dispositivo, con un límite de seguridad de **3 descargas por mes**.

#### 🧑‍🎓 Perfil del Alumno: Control y Autonomía
*   **Edición Condicional:** Los alumnos pueden editar sus datos personales (excluyendo matrícula y ciclo escolar) solo bajo autorización expresa de la Prefectura.
*   **Permiso de Un Solo Uso:** Una vez que el alumno guarda sus cambios, el permiso de edición se revoca automáticamente para garantizar la integridad de los datos institucionales.
*   **Gestión de Foto de Perfil:**
    *   Los alumnos pueden actualizar su foto de perfil (y por ende, su credencial) con un límite de **3 cambios por mes**.
    *   La eliminación de la foto es ilimitada y revierte la credencial al icono por defecto.
*   **Campo NSS Unificado:** Estandarización del campo "Número de Seguro Social" (NSS) en todas las vistas (Prefectura y Alumno) para asegurar la consistencia de la información médica.

#### 👩‍🏫 Herramientas para Prefectura
*   **Autorización por Lotes:** Capacidad para autorizar la edición de perfil a todos los alumnos de un ciclo escolar con un solo clic.
*   **Visor de Ciclos:** Gestión completa de ciclos escolares, grupos y asignación de docentes.

### 📊 Gestión de Asistencia Avanzada
*   **Pase de Lista Flexible:** Registro mediante escaneo de credenciales QR, entrada manual o registro masivo.
*   **Reportes en Excel:** Exportación detallada de asistencias e incidencias con fórmulas automáticas para el cálculo de retardos y justificaciones.
*   **Modo Offline-First:** Funcionalidad completa sin conexión a internet, sincronizando los datos con Firebase cuando la conexión se restablece.

### 🧠 Asistencia con IA (AsystemBot)
Integración con **Gemini 1.5 Flash** para proporcionar asistencia contextual y respuestas en lenguaje natural sobre el funcionamiento de la plataforma y reglamentos institucionales.

---

## 🏛️ Arquitectura y Tecnologías Clave

*   **Frontend:** [Flutter](https://flutter.dev/) (Dart) para una experiencia nativa en Web, Android e iOS.
*   **Backend & Cloud:**
    *   **Firebase Realtime Database:** Sincronización de datos en tiempo real.
    *   **Firebase Authentication:** Gestión segura de identidades.
    *   **Firebase Hosting:** Despliegue de alto rendimiento para la versión web.
    *   **Cloud Functions:** Lógica de negocio segura y conexión con APIs de IA.
*   **Almacenamiento Local:** [Hive](https://pub.dev/packages/hive) para persistencia offline rápida.
*   **Seguridad Local:** `local_auth` y `flutter_secure_storage` para biometría y encriptación de datos sensibles.

---

## 📜 Historia del Desarrollo

El sistema **ASYSTEM** inició su desarrollo entre **Mayo y Agosto de 2024** como un proyecto de estadía profesional impulsado por alumnos de la **UTCAM** (Universidad Tecnológica de Campeche).

Actualmente, el proyecto se encuentra en sus **etapas finales de desarrollo**, preparándose para pruebas piloto en el **Plantel 05 Atasta** para el ciclo escolar **Marzo 2026**. El liderazgo técnico está a cargo de **Ángel del Carmen González Alcocer**.

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
