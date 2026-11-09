# Samán Deportivo

**Proyecto de Sistemas de Información — Universidad Metropolitana (UNIMET)**  
**Grupo 3 · Metodología OpenUP · Hito 3: Construcción**

Samán Deportivo es una aplicación multiplataforma desarrollada con **Flutter y Firebase** para centralizar la gestión de actividades deportivas de la Universidad Metropolitana. Permite explorar deportes, gestionar reservas y cupos, administrar entrenadores y horarios, registrar reseñas y asistencia, y consultar indicadores operativos.

> **Estado del proyecto (9 de noviembre de 2026):** avance de la fase de **Construcción (Hito 3)** integrado en la rama `develop`, con funcionalidades de catálogo, administración, inscripciones, pagos en **PayPal Sandbox**, nómina, asistencia y analítica. La integración de código no equivale a certificación de funcionamiento completo ni a despliegue de producción. La rama `main` conserva, a la fecha de esta actualización, la entrega del Hito 2.

## 1. Evolución del proyecto

| Hito | Fase OpenUP | Alcance |
| --- | --- | --- |
| Hito 1 | Concepción | Problema, actores, requisitos, casos de uso y diseño inicial. |
| Hito 2 | Elaboración | Arquitectura base, autenticación, perfiles, navegación, seguridad inicial y pruebas. |
| Hito 3 | Construcción | Módulos de gestión deportiva, reservas, entrenadores, agenda, reseñas, pagos de prueba, asistencia y panel administrativo. |
| Hito 4 | Transición | Validación final, documentación de uso, despliegue y preparación de distribución. Algunas capacidades de landing y PWA ya están adelantadas en `develop`. |

### Base funcional conservada del Hito 2

- Registro de estudiantes mediante Firebase Authentication y perfil en `usuarios/{uid}`.
- Inicio de sesión, cierre de sesión y recuperación de contraseña.
- Control de sesión y navegación por roles: **estudiante**, **entrenador** y **administrador**.
- Consulta y edición del perfil según las restricciones del rol.
- Interfaz adaptable a escritorio, tabletas y dispositivos móviles, basada en Figma.
- Modelos, repositorios, controladores y reglas iniciales de seguridad para Firestore.
- Pruebas unitarias, de widgets y de seguridad con Firebase Emulator Suite.

El autorregistro público corresponde a estudiantes. La validación del formato del correo institucional **no constituye una verificación de identidad o solvencia ante los sistemas oficiales de la UNIMET**.

## 2. Funcionalidades desarrolladas en el Hito 3

### Estudiante

- Exploración del catálogo deportivo, detalles, horarios, entrenadores, costos y disponibilidad de cupos.
- Búsqueda, filtros y registro de eventos de búsqueda.
- Inscripción con reserva transaccional de cupo y estado inicial **pendiente**.
- Consulta de inscripciones; cancelación, vencimiento y reinscripción según las reglas del módulo.
- Sección **Mis deportes**, con disciplinas confirmadas, próxima sesión e información de asistencia.
- Reseñas y calificaciones sujetas a las condiciones de inscripción, con visualización de agregados.
- Interfaz de pagos con **PayPal Sandbox** y consulta de registros de pago.

### Entrenador

- Acceso al perfil de entrenador y consulta de estudiantes con inscripción confirmada en sus deportes.
- Nómina por disciplina.
- Registro y corrección de asistencia por sesión, con historial y porcentajes.
- Escritura de asistencia en lotes para respetar los límites de acceso de las reglas de Firestore.

### Administrador

- Gestión de disciplinas deportivas y sus parámetros.
- Creación y administración de entrenadores mediante Firebase Authentication y Firestore, sin depender de Cloud Functions para el alta.
- Asignación y modificación de horarios mediante transacciones y control de concurrencia.
- Gestión y moderación de reseñas.
- Consulta de estudiantes y control administrativo de su estado.
- Dashboard y analítica con indicadores de deportes, estudiantes, entrenadores, ocupación, inscripciones, pagos registrados y búsquedas.

### Integridad y seguridad de datos

- Reglas por identidad, rol, propietario y operación.
- Índices de unicidad compartidos para cédulas y carnets de estudiantes; cédulas compartidas entre estudiantes y entrenadores.
- Transacciones relacionadas con reservas, cancelaciones, contadores de cupos y agenda.
- Reglas de acceso a nóminas y registros de asistencia.
- Pruebas de operaciones permitidas, operaciones rechazadas y concurrencia.

**Nota de alcance:** algunas pantallas siguen siendo provisionales, como la vista de inscripciones del administrador y «Mis disciplinas» del entrenador. La existencia de una clase o un PR fusionado no sustituye su validación funcional extremo a extremo.

## 3. Tecnologías

| Área | Tecnología |
| --- | --- |
| Aplicación | Flutter y Dart |
| Autenticación | Firebase Authentication |
| Base de datos y sincronización | Cloud Firestore |
| Estado de interfaz | Provider / ChangeNotifier |
| Pagos de prueba | PayPal JavaScript SDK en Sandbox; WebView en Android |
| Seguridad | Firestore Security Rules |
| Pruebas | `flutter_test`, Node.js test runner, `@firebase/rules-unit-testing` y Firebase Emulator Suite |
| Diseño | Figma y tipografía DM Sans |
| Control de versiones | Git y GitHub |

La solución está orientada al **plan Firebase Spark**. El repositorio conserva archivos y dependencias históricos asociados a Cloud Functions; **no se debe interpretar su presencia como evidencia de funciones desplegadas o requeridas por los flujos migrados a Spark**.

## 4. Arquitectura

El proyecto utiliza una organización por funcionalidades con separación de responsabilidades:

1. **Presentación:** pantallas, widgets, formularios, navegación y visualización de indicadores.
2. **Control de sesión y estado:** `SesionController`, `AuthGate` y Provider.
3. **Dominio:** modelos, enumeraciones, validaciones y cálculos.
4. **Datos:** repositorios y gateways para las operaciones con Firestore y Firebase Authentication.
5. **Seguridad:** reglas de Firestore, índices y operaciones transaccionales.

`AuthGate` observa el estado de autenticación y conduce a la interfaz correspondiente al rol. Los repositorios encapsulan consultas y escrituras. Las reglas de Firestore constituyen la última barrera de autorización para el acceso directo desde el cliente.

```text
lib/
├── main.dart
├── core/
│   ├── config/              # Selección de entorno y emuladores
│   ├── router/              # AuthGate y navegación
│   ├── theme/               # Identidad visual
│   └── widgets/             # Componentes compartidos
├── features/
│   ├── auth/                # Registro, inicio de sesión y recuperación
│   ├── perfil/              # Gestión de perfil
│   ├── publico/             # Landing y catálogo sin sesión
│   ├── estudiante/          # Catálogo, inscripciones y Mis deportes
│   ├── entrenador/          # Nómina, asistencia e historial
│   ├── admin/               # Deportes, entrenadores, agenda y dashboard
│   └── pagos/               # Pago Sandbox e historial
├── models/                  # Entidades y enumeraciones
├── repositories/            # Contratos de acceso a datos
├── services/                # Servicios de autenticación y validación
└── firebase_options.dart    # Configuración FlutterFire

firestore.rules              # Reglas de seguridad
firestore.indexes.json       # Índices compuestos
firebase.json                # Firebase y emuladores
firebase.security.test.json # Suite de reglas generales (puerto 8080)
firebase.inscripciones.test.json # Suite de inscripciones (puerto 8085)
test/                       # Pruebas Flutter y Firestore
scripts/                    # Semillas, mediciones y verificaciones
web/                        # Recursos de Flutter Web y PayPal Sandbox
```

### Colecciones principales de Firestore

| Colección o ruta | Propósito |
| --- | --- |
| `usuarios/{uid}` | Perfiles y roles. |
| `cedulas/{cedula}` y `carnets/{carnet}` | Índices de unicidad. |
| `deportes/{codigo}` | Información deportiva, horarios y contadores de cupos. |
| `inscripciones/{id}` | Reservas, estados, fechas, historial y referencia al pago. |
| `pagos/{orderId}` | Registros de pago para consulta y trazabilidad. |
| `asistencias/{id}` | Asistencia por deporte, fecha y estudiante. |
| `deportes/{codigo}/resenas/{uid}` | Reseñas asociadas al deporte. |
| `busquedas/{id}` | Eventos de búsqueda del catálogo. |
| `control/agenda` y `control/resenas` | Coordinación transaccional. |

## 5. Requisitos de desarrollo

- Flutter SDK compatible con Dart **`^3.13.5`**, según `pubspec.yaml`.
- Chrome para ejecutar Flutter Web; Android SDK y emulador/dispositivo para Android.
- Node.js y npm.
- Firebase CLI y Java para Firestore Emulator.
- Acceso autorizado al proyecto Firebase `saman-deportivo` solamente cuando se necesite trabajar fuera de los emuladores.

Verificar instalaciones:

```bash
flutter doctor
flutter --version
node --version
firebase --version
```

## 6. Instalación y ejecución

Clonar el repositorio y cambiar a la rama de integración:

```bash
git clone https://github.com/richardyradyf/SamanDeportivo.git
cd SamanDeportivo
git switch develop
flutter pub get
npm ci
```

### Ejecución local con emuladores (recomendada)

**Terminal 1 — iniciar Authentication y Firestore:**

```bash
npm run emulador
```

**Terminal 2 — cargar datos de demostración cuando corresponda:**

```bash
npm run emulador:datos
```

**Terminal 3 — iniciar la aplicación:**

```bash
flutter run -d chrome --dart-define=USAR_EMULADOR=true
```

La conexión al emulador se realiza en `lib/core/config/entorno.dart`. El proyecto utiliza por defecto Firestore en el puerto `8080` y Authentication en `9099`. En Android Emulator se utiliza `10.0.2.2` como acceso a la computadora anfitriona.

> **Advertencia:** ejecutar `flutter run -d chrome` **sin** `--dart-define=USAR_EMULADOR=true` conecta la aplicación al proyecto Firebase configurado. No utilizar usuarios ni pagos de prueba sobre datos compartidos sin autorización. La semilla debe usarse solamente en un entorno de emulador controlado.

### Compilación web

```bash
flutter build web
```

Esta instrucción genera `build/web`; **no publica automáticamente** la aplicación en Hosting.

## 7. Pruebas automatizadas

Ejecutar las suites con los puertos libres y sin otros emuladores en ejecución. Conservar la salida y el commit evaluado para la entrega.

### Flutter

```bash
flutter analyze
flutter test
flutter build web
```

### Reglas generales

```bash
npm run test:rules
```

### Concurrencia de agenda

```bash
firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-concurrencia \
  --only firestore \
  'node --test test/firestore/spark_concurrencia.rules.test.mjs'
```

### Nómina y asistencia

```bash
firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-perfil \
  --only firestore \
  'node --test test/firestore/asistencias.rules.test.mjs'
```

### Pagos y confirmación de inscripciones

```bash
firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-inscripciones \
  --only firestore \
  'node --test test/firestore/inscripciones.rules.test.mjs'
```

### Inscripciones avanzadas y registro único

```bash
firebase emulators:exec \
  --config firebase.inscripciones.test.json \
  --project demo-saman-inscripciones-permitidas \
  --only firestore \
  'node --test --test-concurrency=1 test/firestore/inscripcion_inicial_positiva.rules.test.mjs test/firestore/expiracion.rules.test.mjs test/firestore/rechazo.rules.test.mjs test/firestore/reinscripcion.rules.test.mjs test/firestore/registro_unico.rules.test.mjs'
```

**Interpretación de resultados:** una suite con código de salida `0` no garantiza por sí sola que una denegación haya sido evaluada correctamente. Algunas pruebas negativas pueden pasar aunque el emulador reporte el error de **límite de 1.000 expresiones**. Revisar los logs, las operaciones específicas y, cuando sea necesario, la cobertura de reglas.

Los resultados numéricos consignados en las descripciones de los PR corresponden a las ejecuciones reportadas por sus autores; el cierre debe utilizar los resultados de la batería completa sobre **un mismo commit de `develop`**.

## 8. Limitaciones y verificaciones pendientes

1. **Solvencia UNIMET:** se simula mediante el estado administrativo `activo`/`inactivo` del estudiante; no se consulta un sistema institucional real.
2. **PayPal Sandbox:** la interfaz captura el resultado mediante PayPal JS SDK, pero la confirmación escrita desde Flutter **no verifica el identificador de captura contra la API de PayPal mediante un servidor de confianza**. Las reglas cotejan estructura, identidad, monto y escrituras vinculadas, pero ello **no prueba que el dinero se haya cobrado**. Este flujo debe utilizarse únicamente con Sandbox y datos de prueba; no es apto para cobros reales.
3. **Reglas Firestore:** está pendiente acreditar la eliminación de los errores de **1.000 expresiones** observados en determinadas pruebas negativas de inscripción y concurrencia. No desplegar reglas sin revisar las operaciones afectadas.
4. **Pantallas provisionales:** entre otras, la consulta administrativa de inscripciones y «Mis disciplinas» del entrenador requieren completar su presentación.
5. **Validación integral:** faltan registros de una ejecución completa de QA en un único commit y verificación manual de los tres roles.
6. **Rendimiento y despliegue:** existen mediciones con emulador documentadas, pero faltan pruebas de Hosting y de base de datos real. No hay certificación de despliegue final en este README.

## 9. Documentación técnica y evidencias

- [Patrones de diseño](docs/PATRONES_DISENO.md)
- [Perfil y Firebase](docs/PERFIL_FIREBASE.md)
- [Reglas de Firestore](firestore.rules)
- [Plan de pruebas de inscripciones](docs/plan_pruebas_inscripciones.md)
- [Rendimiento del catálogo](docs/rendimiento_catalogo.md)
- [Cierre técnico de módulos Spark](docs/SPARK_ALEXANDER_CIERRE.md)
- [Pruebas generales de reglas](test/firestore/firestore.rules.test.mjs)
- [Pruebas de asistencia](test/firestore/asistencias.rules.test.mjs)
- [Pruebas de registro único](test/firestore/registro_unico.rules.test.mjs)

El informe académico del **Hito 2** fue entregado por separado. La documentación del **Hito 3** debe utilizar evidencia de las pruebas ejecutadas y del código efectivamente integrado.

## 10. Flujo de trabajo y control de versiones

- **`main`:** entregas aprobadas y línea base estable.
- **`develop`:** integración continua del equipo.
- **`feature/*`:** nuevas funcionalidades.
- **`fix/*`:** correcciones.
- **`docs/*`:** documentación.

Flujo: rama de trabajo desde `develop` → implementación y pruebas → Pull Request hacia `develop` → revisión → integración → QA integral → Pull Request de `develop` hacia `main`.

Evitar cambios directos o `force push` sobre `main`. Registrar el commit exacto sobre el que se ejecutó el QA y preservar evidencia de los escenarios aprobados y bloqueados.

### Trabajo integrado durante Construcción

Los PR **#18 a #34** abarcan modelos y estructura base, catálogo, administración de deportes, entrenadores, agenda, dashboard, reseñas, inscripciones, registro único, nómina, asistencia, landing y pagos Sandbox. Consultar el historial de GitHub para identificar autores, revisión y fecha de cada integración.

## 11. Equipo de desarrollo

- **Richard Yrady:** coordinación general, arquitectura e integración de ramas.
- **Mariana Di Buongrazio:** registro único, inscripciones, cupos y reglas correspondientes.
- **Gabriel Cedeño:** catálogo, búsquedas, experiencia del estudiante, landing e integración de asistencia.
- **Andrés Arrieta:** autenticación, recuperación de contraseña, pagos y componentes de nómina/asistencia.
- **Alexander Ramírez:** perfiles, gestión de deportes y entrenadores, agenda, reseñas, dashboard, reglas y pruebas Spark.

---

**Alcance documental:** este README describe el código disponible en `develop` y sus limitaciones conocidas al 9 de noviembre de 2026. No equivale a una aprobación de despliegue, una certificación de seguridad para pagos reales ni una declaración de que todos los requisitos del Hito 3 estén cerrados.
