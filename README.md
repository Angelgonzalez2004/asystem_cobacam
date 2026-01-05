# 🎓 Asystem-Cobacam

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Tailwind CSS](https://img.shields.io/badge/Design-Tailwind_Inspired-38B2AC?style=for-the-badge&logo=tailwind-css)

**Asystem-Cobacam** es una plataforma integral de gestión escolar diseñada para el *Colegio de Bachilleres del Estado de Campeche*. Una solución moderna, fluida y robusta que centraliza la administración académica y el control de asistencia.

---

## ✨ Características Principales

*   **📱 Experiencia Multiplataforma**: Diseño responsivo optimizado para Android, iOS y Web (PC/Tablets).
*   **🎨 Diseño Premium**: Interfaz inspirada en **Tailwind CSS**, con paleta de colores Slate/Indigo, bordes redondeados y sombras suaves.
*   **⚡ Animaciones Fluidas**: Transiciones de entrada `FadeInUp` en todas las pantallas para una navegación profesional.
*   **🔍 Control de Asistencia**: Sistema avanzado de escaneo de QR/Barcodes con soporte **Offline-First** (vía Hive).
*   **📅 Constructor de Horarios**: Herramienta visual para generar y exportar horarios de clases como imágenes.
*   **📊 Gestión de Datos**: Importación masiva de alumnos desde Excel y reportes académicos detallados.

---

## 👥 Perfiles del Sistema

| Rol | Funciones Clave |
| :--- | :--- |
| **👨‍🎓 Estudiante** | Consulta de horarios, calificaciones y credencial digital. |
| **👩‍🏫 Académico** | Gestión de materias, maestros y pase de lista por grupo. |
| **👮 Prefecto** | Control de asistencia, gestión de alumnos y días no lectivos. |
| **🏢 Admin Plantel** | Estadísticas locales, gestión de usuarios y códigos de acceso. |
| **🛡️ Admin General** | Supervisión global del sistema y anuncios institucionales. |

---

## 🛠️ Stack Tecnológico

*   **Core**: Flutter 3.38+ & Dart.
*   **Base de Datos**: Firebase Realtime Database.
*   **Autenticación**: Firebase Auth.
*   **Almacenamiento**: Firebase Storage (Fotos de perfil).
*   **Persistencia Local**: Hive (Caché offline).
*   **UI/UX**: Custom Tailwind-inspired Theme, Material 3.

---

## 🚀 Instalación y Despliegue

1. **Clonar el proyecto**:
   ```bash
   git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
   ```
2. **Actualizar SDK y Dependencias**:
   ```bash
   flutter upgrade
   flutter pub get
   ```
3. **Ejecutar en Web**:
   ```bash
   flutter run -d chrome
   ```
4. **Desplegar a Firebase**:
   ```bash
   flutter build web
   firebase deploy
   ```

---
💎 *Código Limpio: Proyecto verificado con 0 errores, 0 advertencias y 0 sugerencias por el analizador de Flutter.*
