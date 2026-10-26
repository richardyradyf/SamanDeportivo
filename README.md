# Samán Deportivo

**Proyecto de Sistemas de Información — Universidad Metropolitana (UNIMET)**  
**Grupo 3 · Fase de Elaboración (Hito 2)**

Samán Deportivo es una aplicación desarrollada en **Flutter** con **Firebase Authentication** y **Cloud Firestore** para centralizar progresivamente la gestión de actividades deportivas de la UNIMET. El proyecto sigue la metodología **OpenUP** y se desarrolla de forma colaborativa mediante Git y GitHub.

> **Estado del proyecto:** línea base del Hito 2 (Elaboración). Los módulos completos de deportes, cupos, horarios, inscripciones, pagos y asistencia forman parte de la fase de Construcción (Hito 3); el despliegue final y la PWA corresponden a Transición (Hito 4). Las pantallas de inicio pueden contener secciones provisionales.

## Funcionalidades del Hito 2

- Registro de estudiantes con validación de formato del correo institucional, creación de cuenta mediante Firebase Authentication y perfil en `usuarios/{uid}` de Cloud Firestore.
- Inicio y cierre de sesión con correo electrónico y contraseña.
- Recuperación de contraseña mediante Firebase Authentication.
- Control de sesión y redirección a las pantallas iniciales según el rol: **estudiante**, **entrenador** o **administrador**.
- Consulta y edición de perfil según los campos permitidos; acceso al perfil administrativo desde **Configuración**.
- Navegación adaptable a dispositivos móviles, tabletas y escritorio, siguiendo el sistema visual diseñado en Figma.
- Reglas de seguridad de Firestore para proteger perfiles y restringir operaciones según la identidad y el rol.
- Pruebas unitarias y de widgets en Flutter, y pruebas automatizadas de reglas con Firebase Emulator Suite.

**Alcances y limitaciones:** el autorregistro público corresponde únicamente a estudiantes. Las cuentas administrativas y de entrenador se aprovisionan mediante acceso privilegiado durante esta fase. La validación del *formato* del correo institucional no equivale a comprobar la identidad o solvencia académica/financiera ante los sistemas de la UNIMET. No se garantiza todavía la unicidad global de cédulas y carnets; estas restricciones y las funcionalidades deportivas se abordarán en iteraciones posteriores.

## Tecnologías

| Área | Tecnología |
| --- | --- |
| Interfaz y aplicación | Flutter / Dart |
| Autenticación | Firebase Authentication |
| Base de datos | Cloud Firestore |
| Estado y dependencias de interfaz | Provider / ChangeNotifier |
| Pruebas | `flutter_test`, Node.js test runner y Firebase Emulator Suite |
| Diseño | Figma; tipografía DM Sans |
| Control de versiones | Git y GitHub |

## Requisitos para desarrollo

- Flutter SDK y Dart compatibles con `pubspec.yaml` (**Dart SDK `^3.13.5`**).
- Google Chrome, si se ejecutará Flutter Web.
- Node.js y npm para ejecutar las pruebas de reglas.
- Firebase CLI y un entorno Java compatible para Firestore Emulator.
- Configuración/autorización apropiada para el proyecto Firebase de desarrollo, cuando se ejecute la aplicación sin emuladores.

## Instalación y ejecución

```bash
git clone https://github.com/richardyradyf/SamanDeportivo.git
cd SamanDeportivo
flutter pub get
flutter run -d chrome
```

> **Atención:** la entrada `lib/main.dart` inicializa Firebase usando `lib/firebase_options.dart`. **Por defecto la aplicación no utiliza emuladores**, sino el proyecto Firebase configurado. No utilices usuarios de prueba ni realices escrituras en un entorno compartido sin coordinación del equipo. Para pruebas totalmente locales de registro/login/perfil es necesario configurar Authentication y Firestore Emulator y una entrada de ejecución temporal que conecte sus SDK a los emuladores.

## Pruebas

Análisis estático y pruebas Flutter:

```bash
flutter analyze
flutter test
```

Pruebas de seguridad de Firestore (ejecuta este comando con el puerto `8080` libre):

```bash
npm ci
npm run test:rules
```

El script `test:rules` utiliza `firebase.security.test.json`, el proyecto de demostración `demo-saman-perfil` y Firestore Emulator. Las pruebas están definidas en `test/firestore/firestore.rules.test.mjs` y cubren acceso al perfil, restricciones por rol y operaciones no autorizadas. Para revisar las dependencias de Node.js:

```bash
npm audit
npm audit --omit=dev
```

`npm audit` puede devolver hallazgos en dependencias de desarrollo; revisar los resultados antes de modificar el árbol de dependencias. **No ejecutar `npm audit fix --force` sin evaluación del equipo.**

## Arquitectura

El frontend Flutter organiza responsabilidades entre pantallas, controladores, modelos y servicios/repositorios. `SesionController` escucha los cambios de Firebase Authentication y del perfil en Firestore. `AuthGate` selecciona la pantalla inicial según el estado de sesión y el rol, y `FirestorePerfilRepository` encapsula la lectura y actualización de los perfiles.

```text
lib/
├── main.dart                         # Inicialización de Firebase y Provider
├── core/
│   ├── router/auth_gate.dart         # Acceso según sesión y rol
│   ├── theme/                       # Diseño y estilos compartidos
│   └── widgets/                     # Navegación y widgets reutilizables
├── features/
│   ├── auth/                        # Registro, login, recuperación y sesión
│   ├── perfil/                      # Dominio, repositorio e interfaz de perfil
│   ├── estudiante/                  # Inicio del estudiante
│   ├── entrenador/                  # Inicio del entrenador
│   └── admin/                       # Inicio y configuración administrativa
├── models/                          # Persona, Estudiante, Entrenador, Administrador
├── services/                        # AuthService y UsuarioService
└── firebase_options.dart            # Configuración Firebase para Flutter

firestore.rules                     # Seguridad de Cloud Firestore
firebase.security.test.json        # Configuración de las pruebas locales
node_modules/                      # Dependencias locales; no versionar
```

### Modelo de usuarios

Los perfiles se almacenan en la colección `usuarios`, con un documento por UID de Authentication. Los campos comunes son `cedula`, `nombre`, `correo` y `rol`. Un estudiante incorpora `carnet` y `estado`; un entrenador, `especialidad` y `aniosExperiencia`. Los datos de autenticación, incluida la contraseña, son administrados por Firebase Authentication y no se almacenan en los documentos de usuario.

## Documentación técnica

- [Patrones de diseño](docs/PATRONES_DISENO.md)
- [Perfil y seguridad de Firebase](docs/PERFIL_FIREBASE.md)
- [Reglas de seguridad](firestore.rules)
- [Pruebas de reglas de Firestore](test/firestore/firestore.rules.test.mjs)
- Informe académico del Hito 2: documento entregado por el equipo fuera de este repositorio, hasta que se incorpore una versión aprobada.

## Colaboración y ramas

- **`main`**: línea base estable/entregas aprobadas del proyecto.
- **`develop`**: rama de integración del equipo.
- **`feature/*`**, **`fix/*`**, **`docs/*`**: ramas de trabajo para funciones, correcciones y documentación.

Flujo recomendado: crear una rama desde `develop` → implementar y probar → abrir Pull Request dirigido a `develop` → revisión e integración → validar `develop` → abrir Pull Request de `develop` a `main` al cerrar el hito. Evitar commits directos o *force push* a `main`.

## Equipo

- **Richard Yrady:** coordinación e integración del proyecto, modelo de dominio, sesión y diseño compartido.
- **Mariana Di Buongrazio:** registro de estudiantes e integración con Firebase.
- **Gabriel Cedeño:** navegación responsiva, AuthGate y patrones de diseño.
- **Andrés Arrieta:** inicio de sesión y recuperación de contraseña.
- **Alexander Ramírez:** módulo de perfil, interfaz, seguridad de Firestore y pruebas asociadas.

## Estado de entregas

- **Hito 1 — Concepción:** definición del problema, requisitos, modelado inicial y prototipado.
- **Hito 2 — Elaboración:** arquitectura base, autenticación, perfiles, seguridad e integración.
- **Hito 3 — Construcción:** módulos de operación deportiva y funcionalidades de negocio **pendientes**.
- **Hito 4 — Transición:** validación final, PWA y despliegue en Firebase Hosting **pendientes**.

*Este README describe la funcionalidad existente y el alcance del Hito 2; no certifica por sí solo el despliegue de reglas ni la aprobación académica de la entrega.*
