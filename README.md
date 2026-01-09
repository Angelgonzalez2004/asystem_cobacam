# 🎓 Asystem Cobacam - Suite de Gestión Académica Integral

**Asystem Cobacam** es una plataforma digital de vanguardia desarrollada para el **Colegio de Bachilleres del Estado de Campeche (COBACAM)**. Su objetivo es modernizar, centralizar y optimizar todos los procesos académicos y administrativos, conectando a alumnos, docentes, prefectos y personal directivo en un ecosistema seguro y eficiente.

---

## 🚀 Versión 2.1.0: "Seguridad y Offline"

Esta actualización introduce mejoras críticas para la operatividad en planteles con conectividad limitada y herramientas avanzadas para la seguridad del alumnado.

### 🌟 Nuevas Funcionalidades

#### 📡 Modo Offline Nativo (Sin Internet)
El sistema ahora es capaz de operar completamente sin conexión a internet.
*   **Persistencia Inteligente:** Si se va la red, la aplicación guarda automáticamente los registros de asistencia en una base de datos local segura.
*   **Sincronización Automática:** En cuanto el dispositivo recupera la conexión, los datos se suben a la nube de Firebase sin intervención del usuario.
*   **Inicio de Sesión Offline:** Permite acceder a la aplicación incluso si no hay internet al abrirla, utilizando las credenciales y configuración cacheadas de la última sesión exitosa.

#### 📸 Pase de Lista Profesional 2.0
El módulo de asistencia ha sido rediseñado para la velocidad y la precisión.
*   **Buscador Predictivo:** Si el alumno olvida su credencial, el prefecto puede buscarlo por nombre o matrícula. El sistema despliega una tarjeta con **Foto, Nombre y Grupo** para evitar errores de identidad.
*   **Feedback Sensorial:**
    *   🟢 **Verde + Vibración Suave:** Registro exitoso.
    *   🟠 **Naranja:** Retardo o Salida Anticipada.
    *   🔴 **Rojo + Vibración Fuerte:** Error o alumno dado de baja.
*   **Protección Anti-Duplicados:** Bloqueo inteligente del escáner para evitar lecturas dobles accidentales.
*   **Controles de Cámara:** Flash (Linterna) integrado para operar en entradas oscuras y cambio de cámara frontal/trasera.

#### ⚠️ Gestión de Incidencias Express
*   **Reporte Rápido:** Desde la misma pantalla de asistencia, el prefecto puede reportar faltas al reglamento (Uniforme, Cabello, Celular) con solo dos toques, sin detener la fila de entrada.
*   **Historial Digital:** Todas las incidencias quedan registradas en el expediente del alumno.

#### 💳 Generador de Credenciales Avanzado
*   **Lotes Masivos:** Capacidad para generar credenciales de grupos enteros copiando y pegando listas de matrículas.
*   **Formato PDF:** Genera planillas listas para imprimir con 8 credenciales por hoja, optimizando el uso de papel.

#### 📊 Reportes Ejecutivos
*   **Exportación a Excel:** Descarga reportes detallados de asistencia que incluyen no solo horas, sino datos de contacto de tutores, teléfonos de emergencia y alertas médicas.

---

## 🏛️ Arquitectura del Sistema

El proyecto está construido sobre una arquitectura **escalable y modular** utilizando las mejores prácticas de ingeniería de software moderno.

### 📱 Stack Tecnológico
*   **Frontend:** [Flutter](https://flutter.dev) (Dart)
    *   Diseño **Material 3** adaptable.
    *   **Librerías Clave:** `mobile_scanner` (QR/Barras), `hive` (BD Local NoSQL), `connectivity_plus` (Red), `excel` (Reportes), `pdf` (Impresión).
*   **Backend & Cloud:** [Firebase](https://firebase.google.com)
    *   **Authentication:** Gestión de usuarios.
    *   **Realtime Database:** Sincronización en milisegundos con persistencia en disco habilitada.
    *   **Hosting:** Despliegue global.

---

## 🛠️ Configuración y Despliegue

### Requisitos Previos
*   Flutter SDK 3.4+
*   Cuenta de Firebase configurada.

### Comandos Útiles

**Instalar dependencias:**
```bash
flutter pub get
```

**Generar Adaptadores (Hive):**
```bash
dart run build_runner build
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
