# Asystem-Cobacam

**Asystem-Cobacam** es una solución integral multiplataforma (Móvil y Web) desarrollada en Flutter para la gestión escolar y administrativa del *Colegio de Bachilleres del Estado de Campeche (COBACAM)*.

El sistema está diseñado para modernizar y digitalizar procesos clave como el control de asistencia, la gestión académica y la administración de planteles, soportando operaciones tanto en línea como fuera de línea.

## 🚀 Características Principales

*   **Multi-Rol**: Paneles de control personalizados para diferentes tipos de usuarios (Administradores, Directivos, Docentes, Prefectos y Alumnos).
*   **Gestión de Asistencia**: Registro y monitoreo de asistencia de alumnos y personal.
*   **Modo Offline/Online**: Sincronización de datos con Firebase cuando hay conexión y almacenamiento local persistente con Hive para zonas sin cobertura.
*   **Escaneo Inteligente**: Uso de códigos QR/Barras para validación de credenciales y pases de lista.
*   **Reportes**: Generación y manejo de reportes (soporte para Excel).

## 👥 Roles de Usuario

El sistema cuenta con dashboards específicos para:

1.  **General Admin**: Superusuario con control total del sistema y configuración global.
2.  **Campus Admin**: Administrador encargado de un plantel o centro educativo específico.
3.  **Academic**: Módulo para docentes y personal académico (gestión de grupos y calificaciones).
4.  **Prefect**: Herramientas para el control de disciplina y asistencia diaria.
5.  **Student**: Acceso para alumnos (consulta de horarios, asistencia e historial).

## 🛠️ Stack Tecnológico

### Frontend & Core
*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Gestión de Estado**: `provider`
*   **Navegación & Rutas**: Estándar de Flutter

### Backend & Servicios en la Nube
*   **Firebase Auth**: Autenticación segura de usuarios.
*   **Firebase Realtime Database**: Base de datos NoSQL para sincronización en tiempo real.
*   **Firebase Storage**: Almacenamiento de archivos y multimedia.

### Almacenamiento Local (Offline First)
*   **Hive**: Base de datos ligera y rápida NoSQL (key-value) para persistencia local.

### Librerías Clave
*   `mobile_scanner`: Escaneo de códigos QR y de barras.
*   `connectivity_plus`: Detección de estado de red (Wi-Fi/Datos).
*   `excel`: Lectura y escritura de hojas de cálculo.
*   `file_picker` / `image_picker`: Selección de archivos y captura de imágenes.
*   `shared_preferences`: Almacenamiento de configuraciones simples.

## 📂 Estructura del Proyecto

```
lib/
├── data/           # Datos estáticos (Listas de planteles, códigos de acceso)
├── models/         # Modelos de datos (Student, Group, Schedule, etc.)
├── providers/      # Lógica de estado (Theme, Auth, etc.)
├── screens/        # Vistas de la aplicación
│   ├── dashboards/ # Paneles por rol (admin, student, prefect, etc.)
│   ├── login/      # Flujos de autenticación
│   └── ...
├── services/       # Servicios externos (Firebase, Hive, Conectividad)
├── utils/          # Utilidades y helpers
└── widgets/        # Componentes UI reutilizables
```

## 🔧 Configuración e Instalación

1.  **Requisitos Previos**:
    *   Flutter SDK instalado (Versión recomendada: 3.10.x o superior).
    *   Dart SDK.
    *   Configuración de entorno para Android/iOS (Android Studio / Xcode).

2.  **Clonar el repositorio**:
    ```bash
    git clone https://github.com/Angelgonzalez2004/asystem_cobacam.git
    cd asystem_cobacam
    ```

3.  **Instalar dependencias**:
    ```bash
    flutter pub get
    ```

4.  **Generar archivos de código (si es necesario para Hive/JsonSerializable)**:
    ```bash
    dart run build_runner build
    ```

5.  **Ejecutar la aplicación**:
    ```bash
    flutter run
    ```

---
Desarrollado para el **Colegio de Bachilleres del Estado de Campeche**.