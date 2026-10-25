# Módulo de Perfil y Seguridad Firebase — Samán Deportivo

## 1. Descripción

Implementación del módulo de perfil de usuario y propuesta de reglas de seguridad de Cloud Firestore para la aplicación Samán Deportivo.

**Responsable del módulo de perfil y de las pruebas de seguridad:** Alexander.

El módulo permite:

- Consultar el perfil del usuario autenticado.
- Mostrar información según el rol.
- Editar únicamente los campos autorizados.
- Cerrar sesión utilizando el controlador global.
- Leer y actualizar información mediante Cloud Firestore.

El módulo Flutter fue integrado en `develop` mediante el PR #5.

La propuesta de reglas de seguridad se desarrolla por separado en el PR #6.

## 2. Arquitectura e integración

El módulo se encuentra en `lib/features/perfil/`.

| Archivo                                      | Responsabilidad                                      |
| -------------------------------------------- | ---------------------------------------------------- |
| `domain/perfil_usuario.dart`                 | Modelo interno del perfil                            |
| `data/perfil_repository.dart`                | Contrato de acceso a datos                           |
| `data/firestore_perfil_repository.dart`      | Implementación del repositorio con Firestore         |
| `presentation/perfil_screen.dart`            | Pantalla de consulta y edición                       |
| `presentation/perfil_con_sesion_screen.dart` | Adaptador entre el perfil y el controlador de sesión |

### Responsabilidades del equipo

- **Alexander:** módulo de perfil, repositorio de perfil, interfaz, adaptador de sesión y pruebas de seguridad propuestas.
- **Richard:** jerarquía de modelos `Persona`, `Estudiante`, `Entrenador` y `Administrador`, y `SesionController`.
- **Mariana:** `UsuarioModel`, `UsuarioService` y flujo de registro de estudiantes.
- **Gabriel:** `AuthGate`, navegación por roles e integración del perfil en las pantallas principales.

### Integración de navegación

Gabriel integró directamente `PerfilScreen` en el `AuthGate` para las pestañas de perfil de estudiantes y entrenadores, utilizando el UID y la función de cierre de sesión del controlador global.

Esta integración se encuentra en el PR #7, pendiente de fusionarse a `develop` al momento de esta actualización.

`PerfilConSesionScreen` permanece disponible, pero no necesita reemplazar la integración directa realizada por Gabriel.

## 3. Roles y permisos

| Operación                                       | Estudiante | Entrenador | Administrador        |
| ----------------------------------------------- | ---------- | ---------- | -------------------- |
| Leer perfil propio                              | Sí         | Sí         | Sí                   |
| Editar nombre propio                            | Sí         | Sí         | Sí                   |
| Editar carnet propio                            | Sí         | No         | No                   |
| Leer otros perfiles mediante get                | No         | No         | Sí                   |
| Listar usuarios                                 | No         | No         | Sí                   |
| Modificar cédula                                | No         | No         | No                   |
| Modificar rol                                   | No         | No         | No                   |
| Modificar estado de estudiantes                 | No         | No         | No, pendiente Hito 3 |
| Crear perfiles de entrenadores desde el cliente | No         | No         | No, pendiente Hito 3 |
| Eliminar perfiles desde el cliente              | No         | No         | No                   |

Los permisos administrativos de modificación y creación de usuarios privilegiados se implementarán durante el Hito 3.

## 4. Estructura de Cloud Firestore

**Colección:** `usuarios`

El identificador del documento corresponde al UID de Firebase Authentication.

### 4.1. Modelo de estudiante

El esquema de autorregistro aprobado por el equipo es el generado por `Estudiante.toMap()`.

El documento contiene exactamente seis campos:

| Campo    | Tipo   | Descripción            |
| -------- | ------ | ---------------------- |
| `cedula` | String | Documento de identidad |
| `nombre` | String | Nombre completo        |
| `correo` | String | Correo del usuario     |
| `rol`    | String | Debe ser `estudiante`  |
| `carnet` | String | Carnet estudiantil     |
| `estado` | String | Inicialmente `activo`  |

**El campo `uid` no se almacena dentro del documento.** Se utiliza exclusivamente como identificador de `usuarios/{uid}`.

Los campos `especialidad` y `aniosExperiencia` no forman parte del documento de registro del estudiante.

### 4.2. Estado inicial

El equipo estableció que:

- Todo estudiante nuevo comienza con `estado: activo`.
- El propio estudiante no puede modificar su estado.
- Solo el administrador podrá inactivar estudiantes mediante una funcionalidad del Hito 3.

El estado `activo` representa la decisión funcional acordada para este proyecto; no debe interpretarse por sí solo como una validación institucional externa.

### 4.3. Diferencia con el modelo anterior

`UsuarioModel.toMap()` genera nueve campos, mientras que el modelo aprobado `Estudiante.toMap()` genera seis.

Por lo tanto, las reglas de autorregistro propuestas aceptan exclusivamente el formato de seis campos.

**Pendiente de Mariana:** actualizar y probar el servicio de registro para que guarde el formato aprobado y utilice `estado: activo`.

## 5. Reglas de seguridad de Firestore

Las reglas propuestas están implementadas en:

`firestore.rules`

### 5.1. Lectura de usuarios

- Los usuarios autenticados pueden leer su propio perfil.
- Los administradores pueden consultar perfiles de otros usuarios mediante `get`.
- Los administradores pueden listar documentos de la colección `usuarios` mediante `list`.
- Los estudiantes y entrenadores no tienen permisos generales de listado.
- Los usuarios no autenticados no tienen acceso a perfiles.

### 5.2. Creación de estudiantes

La regla `nuevoEstudianteValido(uid)` exige:

- Que el UID autenticado coincida con el ID del documento.
- Que el documento contenga exactamente los seis campos acordados.
- Que el rol sea `estudiante`.
- Que el estado inicial sea `activo`.
- Que el correo coincida con el correo de Firebase Authentication.
- Que el nombre, la cédula y el carnet cumplan las validaciones establecidas.

Los usuarios no pueden registrarse como entrenadores o administradores desde el cliente.

### 5.3. Edición de perfiles

Las reglas permiten:

- Estudiantes: editar nombre y carnet propios.
- Entrenadores: editar su nombre.
- Administradores: editar su nombre.

No se permiten cambios de rol, cédula o estado desde las operaciones ordinarias de actualización del perfil.

Tampoco se permite eliminar documentos de usuario desde el cliente.

### 5.4. Denegación general

Se mantiene:

`match /{document=**} { allow read, write: if false; }`

Esta denegación general constituye la política de cierre por defecto de las colecciones todavía no implementadas.

Durante el Hito 3 se incorporarán reglas específicas para las nuevas colecciones.

### 5.5. Despliegue

Las reglas deben probarse en el emulador antes de desplegarse.

**El despliegue a Firebase compartido corresponde a Mariana**, después de verificar el flujo completo de registro y recibir la aprobación del equipo.

No realizar despliegues independientes desde la rama de Alexander.

## 6. Pruebas automatizadas

Archivo de pruebas:

`test/firestore/firestore.rules.test.mjs`

Archivo de configuración:

`firebase.security.test.json`

Proyecto de pruebas:

`demo-saman-perfil`

### Ejecución

```bash
npm ci
npm run test:rules
```

Las pruebas usan Firebase Emulator Suite y no modifican la base de datos compartida.

### Cobertura

- Consulta del perfil propio.
- Bloqueo de lectura de perfiles ajenos para estudiantes.
- Edición de nombre y carnet del estudiante.
- Bloqueo de cambios de rol.
- Bloqueo de cambios de cédula y estado.
- Bloqueo de creación de entrenadores.
- Lectura de otros perfiles por administradores.
- Bloqueo de usuarios anónimos.
- Edición del nombre de entrenadores.
- Edición del nombre de administradores.
- Bloqueo de modificación de especialidad.
- Bloqueo de modificación del rol administrativo.
- Autorregistro válido con seis campos y estado activo.
- Rechazo del autorregistro con estado inactivo.
- Rechazo de documentos de registro con nueve campos.
- Listado de usuarios por administradores.
- Bloqueo del listado de usuarios para estudiantes.

**Total de casos previstos: 17.**

**Resultado de la versión corregida: 17 pruebas aprobadas, 0 fallidas, utilizando Firebase Emulator Suite.**

Los mensajes `PERMISSION_DENIED` en pruebas negativas son esperados cuando las operaciones prohibidas se rechazan correctamente.

## 7. Validación del módulo Flutter

El PR #5 fue fusionado correctamente a `develop`.

Resultados de validación posteriores a la integración:

| Verificación                           | Resultado            |
| -------------------------------------- | -------------------- |
| `dart analyze`                         | Sin problemas        |
| `flutter test`                         | 8 pruebas aprobadas  |
| Inicio de sesión con cuentas de prueba | Validado manualmente |
| Consulta de información según rol      | Validado manualmente |
| Edición de campos permitidos           | Validado manualmente |
| Cierre de sesión                       | Validado manualmente |

La integración de navegación desarrollada por Gabriel se encuentra en el PR #7.

## 8. Riesgos y tareas pendientes

### 8.1. Normalización del correo electrónico

Las reglas comparan el correo almacenado en Firestore con `request.auth.token.email`.

Para evitar diferencias de mayúsculas, Mariana deberá normalizar el correo antes de almacenarlo:

`correo.trim().toLowerCase()`

También debe verificarse que el correo usado durante el registro en Firebase Authentication sea consistente.

**Responsable:** Mariana.

### 8.2. Duplicidad de cédula y carnet

Las reglas actuales no garantizan unicidad de cédulas o carnets.

Tampoco se debe permitir que los estudiantes consulten libremente los documentos de otros usuarios para comprobar duplicados.

La validación de unicidad deberá resolverse mediante un mecanismo confiable definido por el equipo, con operaciones privilegiadas o índices de reserva protegidos.

**Responsable de coordinación:** Mariana.

**Hito propuesto:** Hito 3.

### 8.3. Modificación administrativa

Durante el Hito 3 se implementarán permisos específicos para que el administrador pueda:

- Cambiar el estado de estudiantes.
- Crear o gestionar entrenadores.
- Realizar las operaciones administrativas autorizadas.

Estos permisos no están incluidos en las reglas actuales.

### 8.4. Modelos de perfil duplicados

El módulo de Alexander utiliza `PerfilUsuario` y `RolPerfil`, mientras que la arquitectura compartida dispone de `Persona` y sus subclases.

La implementación actual es funcional, pero la unificación de modelos puede evaluarse como refactorización del Hito 3.

### 8.5. Consolidación de seguridad

Antes de desplegar, se debe comparar la propuesta con las reglas efectivamente publicadas en Firebase.

Las reglas de las nuevas colecciones deberán incorporarse sin introducir accesos excesivos ni eliminar permisos necesarios.

## 9. Estado de entrega

| Entregable                            | Estado                                  |
| ------------------------------------- | --------------------------------------- |
| Módulo Flutter de perfil              | Completado                              |
| Integración Flutter mediante PR #5    | Fusionado                               |
| Integración con controlador de sesión | Validada                                |
| Navegación por roles de Gabriel       | PR #7 pendiente de merge                |
| Reglas de seguridad por roles         | Implementadas; ajustes en revisión      |
| Registro con seis campos activos      | Definido por el equipo                  |
| Pruebas de seguridad corregidas       | Pendientes de confirmación de ejecución |
| Permisos de lectura administrativa    | Definidos                               |
| Normalización de correo en registro   | Pendiente de Mariana                    |
| Validación de unicidad                | Pendiente para Hito 3                   |
| Permisos administrativos avanzados    | Pendientes para Hito 3                  |
| Despliegue de reglas                  | Pendiente de Mariana                    |

## 10. Conclusión

La funcionalidad de perfil de Alexander se encuentra integrada en `develop`.

Las reglas de seguridad propuestas para el Hito 2 establecen controles de autenticación, autorización por rol y restricciones de modificación de perfiles.

La versión final de las reglas deberá validarse con las pruebas automatizadas y con el flujo de registro de Mariana antes de su aprobación para despliegue.

La integración debe mantenerse coordinada con el resto del equipo, preservando las responsabilidades y decisiones de arquitectura acordadas.
