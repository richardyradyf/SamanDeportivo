# Módulo de Perfil y Seguridad Firebase — Samán Deportivo

## 1. Descripción

Implementación del módulo de perfil de usuario para la aplicación **Samán Deportivo**, desarrollada con Flutter, Firebase Authentication y Cloud Firestore.

**Responsable:** Alexander

El módulo permite:

- Visualizar la información del usuario autenticado.
- Modificar los campos autorizados según su rol.
- Cerrar sesión mediante el controlador global de autenticación.
- Consultar los datos almacenados en Cloud Firestore.

El módulo Flutter fue integrado satisfactoriamente en la rama `develop` mediante el **Pull Request #5**.

## 2. Arquitectura

El módulo se encuentra en `lib/features/perfil/` y sigue una separación por responsabilidades.

| Archivo                                      | Responsabilidad                                             |
| -------------------------------------------- | ----------------------------------------------------------- |
| `domain/perfil_usuario.dart`                 | Modelo de datos del perfil y representación de roles        |
| `data/perfil_repository.dart`                | Contrato de acceso a datos                                  |
| `data/firestore_perfil_repository.dart`      | Acceso y actualización de perfiles mediante Cloud Firestore |
| `presentation/perfil_screen.dart`            | Interfaz de visualización y edición del perfil              |
| `presentation/perfil_con_sesion_screen.dart` | Integración con el controlador global `SesionController`    |

La integración utiliza `Provider` y el controlador de sesión desarrollado por Gabriel.

Se mantiene la separación entre la lógica del perfil y la navegación principal del proyecto.

## 3. Roles y permisos

El sistema contempla tres roles: Estudiante, Entrenador y Administrador.

| Funcionalidad                   | Estudiante | Entrenador | Administrador |
| ------------------------------- | ---------- | ---------- | ------------- |
| Consultar perfil propio         | Sí         | Sí         | Sí            |
| Editar nombre propio            | Sí         | Sí         | Sí            |
| Editar carnet propio            | Sí         | No         | No            |
| Modificar cédula                | No         | No         | No            |
| Modificar rol                   | No         | No         | No            |
| Modificar estado del estudiante | No         | No         | No            |
| Cerrar sesión                   | Sí         | Sí         | Sí            |

Las reglas locales propuestas también permiten que los administradores consulten otros perfiles. Esta autorización requiere revisión del equipo antes del despliegue.

## 4. Estructura de Cloud Firestore

**Colección:** `usuarios`

El identificador del documento debe coincidir con el UID proporcionado por Firebase Authentication.

### Campos generales

- `uid`: identificador de usuario.
- `nombre`: nombre completo.
- `cedula`: documento de identidad.
- `correo`: correo electrónico.
- `rol`: `estudiante`, `entrenador` o `administrador`.

### Campos específicos del estudiante

- `carnet`: número de carnet estudiantil.
- `estado`: `activo` o `inactivo`.

### Campos específicos del entrenador

- `especialidad`: disciplina deportiva.
- `aniosExperiencia`: cantidad de años de experiencia.

### Compatibilidad con UsuarioModel

Las reglas propuestas de creación de estudiantes fueron adaptadas al método `UsuarioModel.toMap()` implementado por Richard.

El documento de registro incluye nueve campos:

1. `uid`
2. `nombre`
3. `cedula`
4. `correo`
5. `rol`
6. `carnet`
7. `estado`
8. `especialidad`
9. `aniosExperiencia`

Durante el autorregistro de estudiantes, los campos `especialidad` y `aniosExperiencia` deben contener `null`.

El campo `uid` debe coincidir con el identificador del usuario autenticado.

## 5. Seguridad de Firestore

Las reglas propuestas se encuentran en `firestore.rules`.

Se implementan controles para:

- Exigir autenticación para acceder a perfiles.
- Restringir las modificaciones al propietario del documento.
- Validar los campos editables según el rol.
- Impedir cambios no autorizados de rol, cédula y estado.
- Impedir el autorregistro como entrenador o administrador.
- Bloquear la eliminación de perfiles desde el cliente.
- Validar la estructura y los tipos de los datos de registro.

### Registro de estudiantes

Las reglas locales propuestas exigen que los nuevos estudiantes sean registrados con:

`estado: inactivo`

Este criterio es compatible con el método `UsuarioService.guardarUsuario()` desarrollado por Richard y con las reglas publicadas originalmente en Firebase.

**Importante:** esta política sigue pendiente de confirmación con Richard y el equipo.

La clase `Estudiante` actualmente utiliza `activo` como valor predeterminado, por lo que todavía existe una inconsistencia entre el modelo de dominio y el servicio de registro.

La activación del estudiante no debe depender únicamente de un valor enviado por el cliente. El mecanismo definitivo de validación o habilitación institucional deberá definirse por el equipo.

### Limitaciones de las reglas propuestas

Las reglas locales están enfocadas en la colección `usuarios`.

Las demás colecciones permanecen bloqueadas mediante una regla general de denegación. Por este motivo, las reglas propuestas no deben considerarse listas para sustituir automáticamente la configuración de seguridad del proyecto completo.

**No ejecutar `firebase deploy --only firestore:rules` sin autorización y coordinación con el equipo.**

## 6. Pruebas automatizadas de seguridad

Las pruebas de Firestore se encuentran en:

`test/firestore/firestore.rules.test.mjs`

Se utilizan Firebase Emulator Suite y el proyecto ficticio:

`demo-saman-perfil`

La configuración independiente del emulador se encuentra en:

`firebase.security.test.json`

Para ejecutar las pruebas:

`npm run test:rules`

### Cobertura implementada

- Lectura del perfil propio.
- Bloqueo de lectura de perfiles ajenos para estudiantes.
- Edición de nombre y carnet del estudiante.
- Protección contra cambios de rol.
- Protección contra cambios de cédula y estado.
- Bloqueo de creación no autorizada de entrenadores.
- Lectura administrativa según las reglas locales.
- Bloqueo de usuarios anónimos.
- Edición de nombre para entrenadores.
- Edición de nombre para administradores.
- Protección de especialidad del entrenador.
- Protección del rol del administrador.
- Registro compatible con `UsuarioModel.toMap()`.
- Rechazo del autorregistro directamente como estudiante activo.
- Rechazo del formato antiguo de seis campos con estado activo.

### Resultados

**Última ejecución: 23 de octubre de 2026.**

| Métrica            | Resultado               |
| ------------------ | ----------------------- |
| Pruebas ejecutadas | 15                      |
| Pruebas aprobadas  | 15                      |
| Pruebas fallidas   | 0                       |
| Entorno            | Firebase Emulator Suite |
| Proyecto           | `demo-saman-perfil`     |

Los mensajes `PERMISSION_DENIED` registrados durante las pruebas negativas son esperados y verifican que las reglas rechazan las operaciones prohibidas.

Las pruebas se ejecutaron localmente y no modificaron la base de datos real de Firebase.

Estas pruebas validan los escenarios incluidos en la cobertura, pero no sustituyen una auditoría completa de seguridad ni las pruebas de integración del proyecto completo.

## 7. Integración con el proyecto Flutter

El módulo fue integrado mediante el **PR #5**, fusionado en la rama `develop`.

La integración incluye:

- Pantallas de perfil para los tres roles.
- Edición de información autorizada.
- Acceso a Cloud Firestore.
- Integración con `SesionController`.
- Manejo del estado de autenticación.
- Cierre de sesión.
- Pruebas automatizadas del módulo.

### Validación posterior a la integración

Se ejecutaron las siguientes verificaciones sobre `develop`:

| Verificación                           | Resultado           |
| -------------------------------------- | ------------------- |
| `dart analyze`                         | Sin problemas       |
| `flutter test`                         | 8 pruebas aprobadas |
| Integración manual de inicio de sesión | Correcta            |
| Visualización de perfiles por rol      | Correcta            |
| Edición de información por rol         | Correcta            |
| Cierre de sesión                       | Correcto            |

La navegación definitiva hacia el módulo de perfil todavía debe conectarse desde la interfaz principal de la aplicación en coordinación con Gabriel y Richard.

## 8. Diferencias y decisiones pendientes

Antes de desplegar las reglas de seguridad propuestas, el equipo deberá revisar los siguientes puntos.

### 8.1 Estado inicial del estudiante

- `UsuarioService` requiere `inactivo`.
- La clase `Estudiante` utiliza `activo` por defecto.
- Las reglas locales propuestas requieren `inactivo`.

**Pendiente:** confirmar el estado inicial y el mecanismo autorizado para la activación del estudiante.

### 8.2 Permisos administrativos

Las reglas propuestas permiten a los administradores consultar otros perfiles.

**Pendiente:** confirmar si esta capacidad forma parte de los requisitos funcionales y definir su alcance.

### 8.3 Reglas de las demás colecciones

Las reglas locales actuales bloquean colecciones distintas de `usuarios`.

**Pendiente:** integrar las reglas de seguridad de los demás módulos sin eliminar permisos legítimos ni introducir accesos excesivos.

### 8.4 Publicación de reglas

**Pendiente:** comparar las reglas propuestas con las actualmente publicadas en Firebase y obtener aprobación del responsable del proyecto antes del despliegue.

## 9. Estado de entrega

| Entregable                                            | Estado               |
| ----------------------------------------------------- | -------------------- |
| Módulo Flutter de perfil                              | Completado           |
| Integración con `SesionController`                    | Completada           |
| Integración en `develop` — PR #5                      | Fusionada            |
| Pruebas Flutter                                       | 8 aprobadas          |
| Reglas locales de seguridad                           | Implementadas        |
| Compatibilidad de registro con `UsuarioModel.toMap()` | Validada en emulador |
| Pruebas de seguridad Firebase                         | 15 aprobadas         |
| Navegación definitiva al perfil                       | Pendiente            |
| Aprobación de política de activación                  | Pendiente            |
| Reconciliación de reglas compartidas                  | Pendiente            |
| Despliegue de reglas a Firebase                       | No realizado         |

### Consideraciones finales

Las pruebas realizadas demuestran que los escenarios implementados funcionan correctamente en los entornos evaluados.

Sin embargo, las reglas de seguridad todavía requieren revisión conjunta antes de ser publicadas en Firebase.

El módulo Flutter y la propuesta de seguridad se mantienen como entregables separados para facilitar su revisión y evitar interferencias con el trabajo de los demás integrantes.
