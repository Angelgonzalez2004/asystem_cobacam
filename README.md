# 🎓 Asystem-Cobacam

![Flutter](https://img.shields.io/badge/Flutter-3.38.5-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Code Quality](https://img.shields.io/badge/Linter-0_Issues-4CAF50?style=for-the-badge&logo=dart&logoColor=white)
![Design](https://img.shields.io/badge/Design-Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)
![Security](https://img.shields.io/badge/Security-RBAC-red?style=for-the-badge&logo=security&logoColor=white)

**Asystem-Cobacam** es la plataforma tecnológica definitiva para la gestión académica del *Colegio de Bachilleres del Estado de Campeche*. Diseñada para ofrecer una experiencia profesional, segura y altamente eficiente en 2026.

---

## 🚀 Innovaciones UI/UX

*   **🎨 Estética Institucional**: Interfaz inspirada en **Tailwind CSS**, con un diseño limpio, moderno y colores institucionales optimizados para la legibilidad.
*   **🌓 Modo Dual Inteligente**: Soporte completo para **Tema Claro** y **Tema Oscuro**, adaptable automáticamente a las preferencias del sistema del usuario o configurable manualmente.
*   **📱 Responsividad Total (Multiplataforma)**: Arquitectura adaptativa (`LayoutBuilder`) que transforma la experiencia según el dispositivo:
    *   **Escritorio/Web:** Barra de navegación lateral expandible y paneles de datos amplios.
    *   **Móvil/Tableta:** Menú lateral deslizante (Drawer) y listas optimizadas para el tacto.
*   **✨ Animaciones Premium**: Transiciones fluidas `FadeInUp` y navegación `SlideRight` que elevan la profesionalidad de la herramienta.

---

## 🛡️ Funcionalidades Avanzadas por Perfil (RBAC)

La aplicación implementa un estricto Control de Acceso Basado en Roles (RBAC):

| Perfil | Icono | Funcionalidades Maestras |
| :--- | :---: | :--- |
| **Estudiante** | 👨‍🎓 | Historial de calificaciones, horarios dinámicos en tiempo real y credencial digital con código QR. |
| **Académico** | 👩‍🏫 | Gestión de maestros, catálogo de materias, asignación de cargas horarias y pase de lista grupal. |
| **Prefectura** | 👮 | **Scanner de Asistencia (Online/Offline)**, gestión de alumnos, reportes de incidencias y control de días no lectivos. |
| **Administración** | 🏢 | Supervisión global de planteles, generación de códigos de acceso seguros y estadísticas de rendimiento. |

---

## 🏥 Gestión Médica y de Bajas (NUEVO)

*   **🩺 Módulo de Salud**: Expediente clínico digital que registra **alergias**, condiciones de salud específicas (visión, motricidad) y estado general para emergencias.
*   **📂 Control de Bajas Lógicas**: Sistema que preserva el historial académico y asistencias pasadas de alumnos dados de baja, permitiendo auditorías futuras.
*   **♻️ Reactivación Instantánea**: Capacidad de reincorporar alumnos con un solo clic, recuperando todo su historial previo sin recaptura de datos.
*   **🚻 Identidad Visual**: Iconografía y paletas de colores adaptativas para identificación rápida de género en listas masivas.

---

## 🔐 Seguridad y Gestión de Cuenta (Enterprise)

*   **📧 Cambio de Correo Seguro**: Protocolo de actualización de credenciales con **re-autenticación obligatoria** para prevenir robos de identidad.
*   **🗑️ Eliminación de Cuenta (Cumplimiento GDPR)**:
    *   Borrado seguro y permanente de datos de autenticación.
    *   Limpieza automática de registros en Realtime Database.
    *   Eliminación de activos multimedia (fotos) en Cloud Storage.
*   **👤 Perfil Dinámico Sincronizado**:
    *   Visualización en tiempo real de cambios en todos los dispositivos.
    *   **Subida de Fotos Híbrida**: Algoritmo inteligente que detecta la plataforma (Web vs. Móvil) para gestionar la compresión y subida de imágenes (`putData` vs `putFile`) sin errores.

---

## 🛠️ Arquitectura y Excelencia Técnica

*   **💎 Calidad de Código**: Verificado con `flutter analyze` reportando **0 errores, 0 advertencias y 0 sugerencias**.
*   **📡 Tecnología Offline-First**:
    *   Uso de bases de datos locales (`Hive`) para funcionamiento sin internet.
    *   Sincronización automática silenciosa con Firebase al recuperar conexión.
*   **🛡️ Manejo de Errores Robusto**: Implementación de "safety nets" (bloques try-catch y casteo seguro de tipos) para prevenir cierres inesperados en Android debido a inconsistencias de datos.

---

## 📡 Acceso Directo

*   **🌐 Plataforma Web**: [https://asystemcobacam.web.app](https://asystemcobacam.web.app)
*   **📦 Código Fuente**: [GitHub - asystem_cobacam](https://github.com/Angelgonzalez2004/asystem_cobacam)

---
*Desarrollado con excelencia e innovación para el COBACAM - 2026*
