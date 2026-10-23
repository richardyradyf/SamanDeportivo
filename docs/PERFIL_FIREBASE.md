# Módulo de Perfil — Samán Deportivo

## 1. Descripción

Implementación del módulo de perfil de usuario para la aplicación Samán Deportivo, desarrollada con Flutter y Firebase.

**Responsable:** Alexander

El módulo permite visualizar la información del usuario autenticado, modificar los campos autorizados y cerrar sesión.

## 2. Arquitectura

El módulo se encuentra en `lib/features/perfil/` y sigue una separación por responsabilidades:

| Archivo                                 | Responsabilidad                 |
| --------------------------------------- | ------------------------------- |
| `domain/perfil_usuario.dart`            | Modelo de usuario y roles       |
| `data/perfil_repository.dart`           | Contrato de acceso a datos      |
| `data/firestore_perfil_repository.dart` | Integración con Cloud Firestore |
| `presentation/perfil_screen.dart`       | Interfaz de perfil y edición    |

El módulo requiere `firebase_auth` y `cloud_firestore`. Su integración con el enrutamiento y la inicialización general de Firebase corresponde al proyecto principal.

## 3. Roles soportados

| Funcionalidad     | Estudiante | Entrenador | Administrador |
| ----------------- | ---------- | ---------- | ------------- |
| Ver perfil propio | Sí         | Sí         | Sí            |
| Editar nombre     | Sí         | Sí         | Sí            |
| Editar carnet     | Sí         | No         | No            |
| Modificar rol     | No         | No         | No            |
| Modificar cédula  | No         | No         | No            |
| Cerrar sesión     | Sí         | Sí         | Sí            |

La lectura de otros perfiles por administradores se permite en las reglas locales, pero requiere coordinación con las reglas desplegadas.

## 4. Estructura de Firestore

Colección: `usuarios`

El identificador del documento debe corresponder al UID de Firebase Authentication.

**Campos generales:**

- `nombre`: string
- `cedula`: string
- `correo`: string
- `rol`: `estudiante`, `entrenador` o `administrador`

**Campos del estudiante:**

- `carnet`: string
- `estado`: string

**Campos del entrenador:**

- `especialidad`: string
- `aniosExperiencia`: entero (`int64` en Firebase Console)

La existencia de campos adicionales o valores nulos debe coordinarse con el esquema definitivo del equipo.

## 5. Seguridad

Las reglas locales se encuentran en `firestore.rules`.

Incluyen:

- Verificación de autenticación.
- Restricción de acceso al perfil propio.
- Restricción de campos modificables según el rol.
- Protección contra escalamiento de privilegios.
- Restricción de creación de perfiles privilegiados desde el cliente.
- Prohibición de eliminación de perfiles desde Flutter.

Los perfiles de entrenador y administrador deben aprovisionarse desde un entorno administrativo confiable.

## 6. Pruebas automatizadas

Archivo: `test/firestore/firestore.rules.test.mjs`

Las pruebas se ejecutan con Firebase Emulator Suite, usando el proyecto ficticio `demo-saman-perfil`.

Comando:

```bash
npm run test:rules
```

Cobertura:

- Acceso al perfil propio.
- Bloqueo de lectura de perfiles ajenos para estudiantes.
- Edición de nombre y carnet del estudiante.
- Protección de rol, cédula y estado.
- Bloqueo de creación de entrenadores desde cuentas estudiantiles.
- Lectura administrativa según reglas locales.
- Bloqueo de acceso anónimo.
- Edición de nombre para entrenadores y administradores.
- Restricciones de edición de especialidad y rol.

Las pruebas del módulo Flutter se encuentran en `test/features/perfil/` y requieren un proyecto Flutter correctamente configurado.

## 7. Integración con el proyecto principal

Para integrar el módulo:

1. Configurar Flutter y las dependencias Firebase en el proyecto principal.
2. Inicializar Firebase antes de utilizar el repositorio.
3. Integrar `PerfilScreen` en la navegación del usuario autenticado.
4. Utilizar Firebase Authentication para obtener el UID.
5. Verificar que exista el documento `usuarios/{uid}`.
6. Garantizar que el flujo global de autenticación reaccione al cierre de sesión.
7. Ejecutar las pruebas Flutter y de Firestore tras la integración.

El módulo no reemplaza la navegación ni la lógica global de autenticación desarrolladas por el resto del equipo.

## 8. Diferencias pendientes de integración

Las reglas locales y las reglas publicadas en Firebase no están completamente sincronizadas.

Diferencias identificadas:

- Valor inicial de `estado`: las reglas locales permiten `activo`; las reglas publicadas originalmente exigían `inactivo`.
- Esquema de creación: las reglas publicadas originalmente exigen un campo `uid` y campos adicionales con valores nulos.
- Lectura administrativa: las reglas locales permiten consultar otros perfiles, mientras que las reglas publicadas originalmente permiten únicamente la lectura propia.
- Las reglas publicadas recibieron una corrección para permitir editar nombres de entrenadores y administradores.

**Estas diferencias deben resolverse con el equipo antes de un despliegue de reglas desde GitHub.**

No ejecutar `firebase deploy --only firestore:rules` sin aprobación, ya que podría reemplazar las reglas del proyecto compartido.

## 9. Estado de la entrega

- Módulo de perfil implementado.
- Edición por rol implementada.
- Cierre de sesión implementado.
- Pruebas automatizadas de seguridad incorporadas.
- Integración final con el proyecto completo pendiente.
- Consolidación de reglas compartidas pendiente.
