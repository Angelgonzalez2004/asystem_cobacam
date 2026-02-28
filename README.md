# 🎓 ASYSTEM COBACAM - Plataforma de Excelencia Académica

**ASYSTEM COBACAM** es la evolución digital del **Colegio de Bachilleres del Estado de Campeche**. Una plataforma integral de alto nivel diseñada para centralizar, automatizar y asegurar el control escolar mediante una experiencia de usuario premium, moderna y ultra-profesional.

---

## ✨ Experiencia de Usuario Premium (Novedad)

Hemos elevado la estética del sistema a un nivel institucional superior, adoptando una filosofía de diseño **Premium Glassmorphism**:

*   **Interfaz Glassmorphism Refinada**: Pantallas de acceso (Login, Registro, Recuperación) con efectos de cristal esmerilado sobre un gradiente de malla institucional.
*   **Fondo Institucional Dinámico**: Uso de gradientes profundos (Deep Slate & Royal Blue) con iluminación ambiental para una sensación de tecnología y seriedad.
*   **Visibilidad de Alto Contraste**: Tipografía blanca sólida (`FontWeight.w900`) y etiquetas inteligentes que garantizan una legibilidad perfecta en cualquier condición lumínica.
*   **Totalmente Responsiva**: El sistema se adapta inteligentemente a monitores 4K, laptops, tablets y móviles, reordenando los formularios para mantener la elegancia.

---

## 🚀 Funcionalidades Críticas Actualizadas

### 🔔 Notificaciones en Tiempo Real (FCM)
Sistema de alerta inmediata para padres de familia y tutores:
*   **Notificación Automática**: El servidor detecta instantáneamente el registro de entrada o salida realizado por Prefectura.
*   **Seguridad Total**: Alerta en el dispositivo del tutor informando: *"El alumno [Nombre] acaba de ingresar/salir del plantel a las [Hora]"*.
*   **Omnicanal**: Funciona en Android, iOS y Navegadores Web (PWA).

### 👨‍👩‍👦 Control Total para Tutores
*   **Vinculación Inteligente**: El sistema vincula automáticamente al tutor con el alumno durante el registro mediante validación de matrícula.
*   **Dashboard de Asistencia Premium**: 
    *   Estadísticas mensuales: Conteo en tiempo real de Asistencias, Retardos e Inasistencias.
    *   **Banner de Rango Académico**: El sistema avisa dinámicamente si el mes consultado está fuera de las fechas oficiales del ciclo escolar.
    *   **Historial Histórico**: Selector de ciclos pasados para consultar años anteriores con un solo clic.
*   **Identidad Médica**: Visualización de alertas de salud (distintivo de pulso cardiaco) para un seguimiento preventivo.

### 📊 Gestión Administrativa y de Prefectura
*   **Pase de Lista Inteligente**: Escaneo QR de alta velocidad con sincronización Offline-First.
*   **Motor de Ciclos Escolares**: Gestión de periodos A/B con validación de fechas de inicio y término para la integridad de los datos.
*   **Generador de Credenciales HD**: Exportación de identificaciones oficiales en alta resolución vinculadas al historial del alumno.

---

## 🛠️ Arquitectura Tecnológica

### Core System
*   **Flutter 3.22+**: Motor multiplatforma de alto rendimiento.
*   **Firebase Cloud Messaging (FCM)**: Infraestructura de notificaciones push.
*   **Firebase Functions (V2)**: Lógica de servidor para procesamiento de señales de asistencia.
*   **Hive DB**: Almacenamiento local persistente para máxima velocidad y trabajo sin internet.

### Inteligencia Artificial
*   **AsystemBot (Gemini 1.5 Flash)**: Asistente integrado para soporte técnico y consultas de reglamento institucional en lenguaje natural.

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
# Genera la versión final optimizada
flutter build web --release
```

### 3. Lanzamiento al Hosting
```bash
# Despliegue directo en Firebase
firebase deploy --only hosting
```

---

## 📄 Licencia e Identidad
© 2026 **Colegio de Bachilleres del Estado de Campeche (COBACAM)**.
*Gestión Escolar Inteligente, Excelencia Educativa.*
Desarrollado para la innovación y el control total de la comunidad académica.
