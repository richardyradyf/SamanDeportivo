# Plan de pruebas — Módulo de inscripciones deportivas

**Proyecto:** Samán Deportivo — Grupo 3, Universidad Metropolitana (UNIMET)
**Iteración:** Hito 3, fase de Construcción (OpenUP)
**Fecha de revisión documental:** 9 de noviembre de 2026
**Rama de referencia:** `develop`
**Commit de referencia consultado:** `77c858ae58df2968bfa06a1297a7b72913c27cbf`
**Responsables de ejecución:** equipo de Samán Deportivo; consolidación de evidencias de QA del Hito 3
**Estado del documento:** actualizado conforme al código integrado; **sin certificar la ejecución final de la batería de pruebas sobre este commit**.

> **Regla de interpretación:** que una funcionalidad esté implementada o que exista una prueba automatizada **no significa** que esa prueba haya sido ejecutada y aprobada en la versión final. Los estados de cada caso corresponden a la **validación final de este corte**, no al grado de implementación del código. Los resultados históricos se indican por separado.

## 1. Objetivo

Comprobar la integridad funcional y la seguridad del ciclo de inscripción deportiva: registro, reserva de cupos, validaciones de estudiantes, cancelación, reinscripción, expiración, rechazo, consultas propias, concurrencia y confirmación relacionada con pagos de prueba.

La evaluación comprende tanto el comportamiento de la interfaz Flutter como las transacciones de Cloud Firestore y las reglas de seguridad ejecutadas mediante Firebase Emulator Suite.

## 2. Alcance de la versión evaluada

### 2.1. Implementación disponible en `develop`

- Repositorio de inscripciones con transacciones de reserva, cancelación, expiración, reinscripción y confirmación: `lib/features/estudiante/inscripciones/data/firestore_inscripcion_repository.dart`.
- Modelo `Inscripcion`, estados e historial de cambios: `lib/models/inscripcion.dart` y `lib/models/enums.dart`.
- Interfaz «Mis inscripciones»: `lib/features/estudiante/inscripciones/screens/mis_inscripciones_screen.dart`.
- Reglas de seguridad de `inscripciones`, `deportes` y `pagos`: `firestore.rules`.
- Pruebas Flutter de modelos, validaciones e interfaz, y suites de reglas de Firestore.
- Flujo de pago **Sandbox** por PayPal JS SDK con registro transaccional del documento `pagos`, transición a `confirmada` y actualización de `cuposConfirmados`.

### 2.2. Restricciones importantes

1. El estado `activo` del estudiante no equivale a una consulta real de solvencia institucional UNIMET; la validación institucional es simulada.
2. Las reglas de Firestore verifican estructura, propietario, montos y consistencia atómica del pago, pero **no verifican la captura contra una fuente confiable de PayPal**. Un identificador de captura proporcionado por el cliente no es prueba independiente de un cobro. El flujo **no está validado para dinero real**.
3. Las reglas integradas en el PR #30 fueron fusionadas con una incidencia reconocida de **límite de 1.000 expresiones evaluadas** en determinados casos. Se requiere una nueva ejecución, aislando solicitudes y verificando los logs completos.
4. No se presupone que la caducidad se ejecute automáticamente en segundo plano: la prueba debe demostrar qué mecanismo invoca el proceso de expiración y bajo qué condiciones.

## 3. Entorno, dependencias y preparación

| Componente | Implementación |
|---|---|
| Aplicación | Flutter / Dart |
| Autenticación | Firebase Authentication |
| Persistencia | Cloud Firestore |
| Seguridad | `firestore.rules` |
| Pruebas Flutter | `flutter test` |
| Pruebas de reglas | `@firebase/rules-unit-testing` + Node.js test runner |
| Entorno de integración local | Firebase Emulator Suite |
| Proyecto Firebase simulado | IDs con prefijo `demo-`; nunca el proyecto real |

### 3.1. Preparar el repositorio

Usar una copia de trabajo limpia y un commit fijo de `develop`:

```bash
cd "$HOME/SamanDeportivo_H3_QA"
git status --short
git rev-parse HEAD
flutter pub get
npm ci
mkdir -p "$HOME/Downloads/SamanH3_QA"
git rev-parse HEAD > "$HOME/Downloads/SamanH3_QA/commit.txt"
```

Si hay cambios sin guardar, no restaurarlos ni sobrescribirlos. Confirmar que `commit.txt` contiene el commit efectivamente probado. Las referencias de este documento se actualizarán si se ejecuta el QA sobre un commit más reciente.

### 3.2. Escenarios de datos

- Administrador autorizado.
- Estudiante **A** activo y sin inscripción vigente.
- Estudiante **B** activo para intentos concurrentes.
- Estudiante **C** inactivo.
- Un deporte activo con cupos disponibles; otro con capacidad completa.
- Inscripciones en estados `pendiente`, `confirmada`, `cancelada`, `expirada` y `rechazada`.
- Pagos simulados y capturas de Sandbox **sin dinero real**.

Los datos semilla de pruebas automatizadas pueden cargarse con `withSecurityRulesDisabled` exclusivamente en el emulador. No utilizar esa configuración para justificar permisos efectivos de un usuario normal.

## 4. Sistema de clasificación de resultados

Cada caso se cierra con **una única clasificación**:

| Estado | Significado | Evidencia mínima |
|---|---|---|
| **APROBADO** | Se ejecutó el caso y el resultado coincidió con lo esperado, sin errores de evaluación que invaliden la operación. | Commit, fecha, nombre de test, log y/o captura. |
| **FALLIDO** | Se ejecutó el caso y el resultado fue incorrecto. | Evidencia del fallo y pasos de reproducción. |
| **BLOQUEADO** | Existe una dependencia o defecto conocido que impide verificar el criterio completo. | Motivo y persona responsable de desbloqueo. |
| **NO EJECUTADO** | No existe evidencia de ejecución final sobre el commit de referencia. | Pendiente de registrar. |

**Estado inicial del presente plan:** los casos están en `NO EJECUTADO` respecto del **QA consolidado** salvo INS-13, que se marca `BLOQUEADO` para la garantía de verificación confiable del pago. No se invalida con ello el trabajo ni las pruebas históricas de PR individuales.

## 5. Matriz de trazabilidad — INS-01 a INS-13

| Caso | Requisito / comportamiento | Evidencia de código o prueba disponible | Estado de QA final |
|---|---|---|---|
| INS-01 | Alta válida y reserva de un cupo | `inscripcion_inicial_positiva.rules.test.mjs` | **NO EJECUTADO** |
| INS-02 | Rechazo de duplicado | `validaciones_inscripcion_test.dart`; repositorio de inscripciones | **NO EJECUTADO** |
| INS-03 | Rechazo por falta de cupo | `validaciones_inscripcion_test.dart`; transacción de reserva | **NO EJECUTADO** |
| INS-04 | Rechazo de estudiante inactivo | `validaciones_inscripcion_test.dart`; reglas de reserva | **NO EJECUTADO** |
| INS-05 | Cancelación y liberación | `inscripcion_inicial_positiva.rules.test.mjs`; repositorio | **NO EJECUTADO** |
| INS-06 | Usuario desiste de cancelar | `auth_gate_cancelacion_test.dart` y pruebas de interfaz | **NO EJECUTADO** |
| INS-07 | Reinscripción e historial | `reinscripcion.rules.test.mjs`; modelo `Inscripcion` | **NO EJECUTADO** |
| INS-08 | Expiración sin doble liberación | `expiracion.rules.test.mjs`; repositorio | **NO EJECUTADO** |
| INS-09 | Dos reservas compiten por último cupo | Transacción de inscripciones; requiere prueba concurrente identificada | **NO EJECUTADO** |
| INS-10 | Consulta propia en tiempo real | `mis_inscripciones_screen_test.dart`; `observarDeEstudiante()` | **NO EJECUTADO** |
| INS-11 | Acceso prohibido a inscripción ajena | `inscripciones.rules.test.mjs` | **NO EJECUTADO** |
| INS-12 | Manipulación directa de cupos bloqueada | `inscripciones.rules.test.mjs` | **NO EJECUTADO** |
| INS-13 | Pago y confirmación seguros | `inscripciones.rules.test.mjs`; `pagar_inscripcion_screen_test.dart` | **BLOQUEADO** para verificación de captura real |

**Nota:** las pruebas listadas acreditan que hay cobertura implementada, no su resultado actual. En particular, una prueba con identificadores PayPal inventados sirve para validar la coherencia de una simulación, pero no para demostrar autenticidad del pago.

## 6. Casos detallados

### INS-01. Inscripción exitosa

**Precondiciones:** estudiante autenticado, activo, deporte activo y con al menos un cupo libre; no existe inscripción vigente al mismo deporte.

**Acción:** solicitar la inscripción desde el catálogo.

**Resultados esperados:**

- Se crea `inscripciones/{estudianteUid}_{deporteId}` en estado `pendiente`.
- `cuposOcupados` aumenta **exactamente en uno**, sin superar `cupoMaximo`.
- Se establece `fechaLimitePago`, y el historial comienza con `pendiente`.
- Las escrituras vinculadas se completan de manera atómica; ninguna se aplica parcialmente.

**Referencia automatizada:** `test/firestore/inscripcion_inicial_positiva.rules.test.mjs`.
**Estado:** **NO EJECUTADO** en QA consolidado.
**Evidencia:** pendiente de adjuntar `inscripciones_avanzadas.log` y captura/lectura del estado final.

### INS-02. Inscripción duplicada

**Precondiciones:** inscripción del estudiante en estado `pendiente` o `confirmada` para el mismo deporte.

**Acción:** intentar una segunda reserva.

**Resultados esperados:** mensaje de inscripción ya existente; ningún nuevo documento o cupo adicional; contador sin cambios.

**Referencia:** `test/features/estudiante/inscripciones/validaciones_inscripcion_test.dart` y `FirestoreInscripcionRepository.inscribirse()`.
**Estado:** **NO EJECUTADO**.
**Evidencia:** caso automático más captura de mensaje al usuario.

### INS-03. Deporte sin cupos

**Precondiciones:** `cuposOcupados == cupoMaximo`.

**Acción:** solicitar reserva.

**Resultados esperados:** operación rechazada, sin cambiar la capacidad ni crear reserva.

**Referencia:** `validaciones_inscripcion_test.dart`; lógica transaccional y reglas `deportes`.
**Estado:** **NO EJECUTADO**.

### INS-04. Estudiante inactivo

**Precondiciones:** perfil propio con `estado = inactivo`.

**Acción:** intentar inscribirse.

**Resultados esperados:** rechazo sin reservar cupo y mensaje explicativo; no asumir consulta institucional real.

**Referencia:** `validaciones_inscripcion_test.dart` y validación de estado del usuario en la transacción/reglas.
**Estado:** **NO EJECUTADO**.

### INS-05. Cancelación exitosa

**Precondiciones:** inscripción propia que aún ocupa cupo.

**Acción:** confirmar la cancelación desde la interfaz.

**Resultados esperados:** estado `cancelada`, actualización del historial y decremento exactamente una vez de `cuposOcupados`; si era `confirmada`, descontar también `cuposConfirmados`; todo atómicamente.

**Referencia:** `inscripcion_inicial_positiva.rules.test.mjs`, `mis_inscripciones_screen_test.dart`, `FirestoreInscripcionRepository.cancelar()`.
**Estado:** **NO EJECUTADO** en QA consolidado.

### INS-06. Cancelación rechazada por el usuario

**Precondiciones:** inscripción cancelable visible.

**Acción:** abrir confirmación y pulsar «Volver»/cancelar en el diálogo.

**Resultados esperados:** no se invoca la operación de cancelación y el documento permanece idéntico.

**Referencia:** `test/core/router/auth_gate_cancelacion_test.dart`, pruebas de interfaz.
**Antecedente:** el documento anterior consignaba una prueba de interfaz aprobada, sin identificar commit ni log de esa ejecución.
**Estado:** **NO EJECUTADO** en QA consolidado.

### INS-07. Reinscripción

**Precondiciones:** inscripción cancelada, expirada o rechazada, con disponibilidad de cupos.

**Acción:** solicitar inscripción nuevamente.

**Resultados esperados:** se reutiliza el ID, se crea una nueva etapa `pendiente`, se conserva el historial previo y se reserva un único cupo sin duplicar la reserva.

**Referencia:** `reinscripcion.rules.test.mjs`, `Inscripcion.reinscribir()`.
**Estado:** **NO EJECUTADO**.

### INS-08. Expiración de reserva

**Precondiciones:** inscripción `pendiente` con `fechaLimitePago` anterior al momento de prueba.

**Acción:** invocar el proceso explícito de expiración.

**Resultados esperados:** `expirada`, un solo decremento de cupos, historial actualizado; ejecuciones repetidas no pueden liberar el mismo cupo otra vez.

**Referencia:** `expiracion.rules.test.mjs`, `FirestoreInscripcionRepository.expirar()`.
**Estado:** **NO EJECUTADO**.

**Control adicional:** verificar si el sistema tiene un disparador automático en ejecución real o si la expiración depende de una llamada explícita. No confundir una función implementada con una tarea programada.

### INS-09. Inscripciones simultáneas

**Precondiciones:** queda un cupo; estudiantes A y B activos, sin reserva vigente.

**Acción:** lanzar dos intentos de inscripción concurrentes al mismo deporte.

**Resultados esperados:** exactamente un éxito y un rechazo, sin sobrecupo; contar documentos resultantes y verificar `cuposOcupados <= cupoMaximo`.

**Referencia:** transacciones de `FirestoreInscripcionRepository.inscribirse()` y seguridad de `deportes`; la suite `spark_concurrencia.rules.test.mjs` cubre **concurrencia de agenda**, no prueba por sí misma este escenario de inscripciones.

**Estado:** **NO EJECUTADO**.
**Evidencia requerida:** test concurrente específico o prueba controlada con dos usuarios y resultado atómico documentado.

### INS-10. Consulta de inscripciones propias

**Precondiciones:** usuario autenticado con varios registros en diferentes estados.

**Acción:** abrir «Mis inscripciones» y modificar un estado desde otra sesión autorizada.

**Resultados esperados:** únicamente registros propios, datos de deporte/estado/fechas correctos y actualización mediante `Stream`; no mostrar documentos de terceros.

**Referencia:** `mis_inscripciones_screen_test.dart`, `FirestoreInscripcionRepository.observarDeEstudiante()`.
**Estado:** **NO EJECUTADO** en QA consolidado.

### INS-11. Protección de inscripciones ajenas

**Precondiciones:** usuario A autenticado e inscripción de B existente.

**Acción:** intentar leer o modificar la inscripción ajena.

**Resultados esperados:** `permission-denied`; ninguna alteración. El rechazo debe provenir de reglas correctamente evaluadas, **no por agotamiento accidental de las 1.000 expresiones**.

**Referencia:** `test/firestore/inscripciones.rules.test.mjs`.
**Antecedente:** documento previo reportaba prueba de seguridad aprobada, sin registro de ejecución final asociado.
**Estado:** **NO EJECUTADO** en QA consolidado.

### INS-12. Manipulación manual de cupos

**Precondiciones:** usuario estudiante sin operación de inscripción autorizada.

**Acción:** modificar directamente `cuposOcupados` o `cuposConfirmados` en un deporte.

**Resultados esperados:** operación denegada; el contador no cambia. Distinguir un rechazo correcto de un error interno del evaluador de reglas.

**Referencia:** `test/firestore/inscripciones.rules.test.mjs`.
**Antecedente:** documento previo reportaba esta protección aprobada en un corte anterior.
**Estado:** **NO EJECUTADO** en QA consolidado.

### INS-13. Confirmación de pago

**Precondiciones:** inscripción pendiente no vencida y resultado de prueba de PayPal Sandbox.

**Acción:** ejecutar el flujo de pago y confirmar la inscripción.

**Resultados esperados para la simulación actual:**

- Se crea `pagos/{orderId}` con los datos del resultado recibido.
- `inscripciones/{id}` pasa a `confirmada` y referencia el pago.
- `deportes/{codigo}.cuposConfirmados` aumenta exactamente una vez.
- Las tres escrituras se incluyen en una sola transacción.
- Se rechaza un monto incorrecto, un pago asociado a otro estudiante y una confirmación sin documento de pago relacionado.

**Criterio adicional de seguridad para un pago auténtico:** la captura y el importe deben verificarse directamente ante PayPal desde un entorno confiable, sin depender exclusivamente de datos proporcionados por el cliente. **Esta verificación no existe en el flujo Spark actual**: las reglas solo pueden validar consistencia en Firestore y los campos suministrados. Por tanto, no puede asegurarse que un cliente malicioso no fabrique una confirmación aparente.

**Referencias:** `test/firestore/inscripciones.rules.test.mjs`, `test/features/pagos/pagar_inscripcion_screen_test.dart`, `lib/features/pagos/presentation/pagar_inscripcion_screen.dart` y `FirestoreInscripcionRepository.confirmar()`.

**Estado:** **BLOQUEADO** respecto al criterio de autenticidad de pago; **NO EJECUTADO** para el recorrido final con Sandbox en el commit de cierre.
**Restricción de uso:** solo académico/Sandbox, sin cobros reales y sin certificar seguridad de una pasarela de pagos de producción.

## 7. Ejecución automatizada y registro de evidencias

Ejecutar desde la raíz del repositorio. Los siguientes comandos escriben resultados en la carpeta de QA y usan proyectos Firebase locales `demo-*`.

### 7.1. Flutter

```bash
set -o pipefail
flutter analyze 2>&1 | tee "$HOME/Downloads/SamanH3_QA/flutter_analyze.log"
flutter test 2>&1 | tee "$HOME/Downloads/SamanH3_QA/flutter_test.log"
flutter build web 2>&1 | tee "$HOME/Downloads/SamanH3_QA/flutter_build_web.log"
```

Si se van a registrar resultados de cada comando, ejecutar y conservar también su código de salida. El `flutter build web` valida compilación, no aprobación funcional de un recorrido.

### 7.2. Reglas generales

```bash
npm run test:rules 2>&1 | tee "$HOME/Downloads/SamanH3_QA/reglas_generales.log"
```

### 7.3. Inscripciones y pagos, con configuración del puerto 8080

```bash
npx firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-inscripciones \
  --only firestore \
  'node --test test/firestore/inscripciones.rules.test.mjs' \
  2>&1 | tee "$HOME/Downloads/SamanH3_QA/inscripciones_pago.log"
```

### 7.4. Inscripciones avanzadas, con configuración del puerto 8085

```bash
npx firebase emulators:exec \
  --config firebase.inscripciones.test.json \
  --project demo-saman-inscripciones-permitidas \
  --only firestore \
  'node --test --test-concurrency=1 test/firestore/inscripcion_inicial_positiva.rules.test.mjs test/firestore/expiracion.rules.test.mjs test/firestore/rechazo.rules.test.mjs test/firestore/reinscripcion.rules.test.mjs test/firestore/registro_unico.rules.test.mjs' \
  2>&1 | tee "$HOME/Downloads/SamanH3_QA/inscripciones_avanzadas.log"
```

### 7.5. Suites complementarias

```bash
npx firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-perfil \
  --only firestore \
  'node --test test/firestore/asistencias.rules.test.mjs' \
  2>&1 | tee "$HOME/Downloads/SamanH3_QA/asistencias.log"

npx firebase emulators:exec \
  --config firebase.security.test.json \
  --project demo-saman-concurrencia \
  --only firestore \
  'node --test test/firestore/spark_concurrencia.rules.test.mjs' \
  2>&1 | tee "$HOME/Downloads/SamanH3_QA/concurrencia_agenda.log"
```

**Importante:** los emuladores deben estar detenidos antes de cada `emulators:exec`; ejecutar los bloques de forma secuencial. No ejecutar pruebas de reglas sobre el proyecto `saman-deportivo` real.

## 8. Incidencia: máximo de 1.000 expresiones en reglas Firestore

### 8.1. Antecedente comprobado

Durante una ejecución anterior de las suites en una rama de corrección, se registraron advertencias `maximum of 1000 expressions to evaluate has been reached` en **reglas generales**, **concurrencia** e **inscripciones**, aunque las suites devolvieron estado de proceso correcto. Las pruebas de registro único no mostraron ese aviso en dicha ejecución.

Se probaron dos optimizaciones locales que **no eliminaron las advertencias**. Por lo tanto, no constituyen correcciones verificadas. La integración posterior del PR #30 no certifica por sí sola la eliminación del problema.

### 8.2. Verificación requerida en el commit final

1. Conservar los logs de cada suite y el `firestore-debug.log` correspondiente a **esa misma ejecución**.
2. Buscar errores de presupuesto de expresiones, por ejemplo:

   ```bash
   grep -RniE 'maximum of 1000 expressions|1000 expressions|exceeded.*expressions' \
     "$HOME/Downloads/SamanH3_QA"
   ```

3. Si aparecen, identificar caso, operación, ruta y número de línea. Usar trazas y cobertura de reglas del emulador cuando corresponda.
4. Repetir la solicitud en una prueba aislada para distinguir una denegación esperada de un fallo interno de evaluación.
5. **No marcar aprobado un caso negativo cuando el rechazo se produjo por exceder el presupuesto de expresiones**, aunque `assertFails` devuelva éxito.
6. No desplegar reglas a un proyecto compartido ni afirmar que la incidencia está resuelta sin una nueva medición.

**Estado de la incidencia:** **PENDIENTE DE VERIFICACIÓN EN `develop` CONSOLIDADO**.

## 9. Criterios de aceptación del módulo

Para cerrar el módulo como validado debe acreditarse lo siguiente:

- INS-01 a INS-12: comportamiento funcional y de seguridad observado y conforme, con logs/capturas vinculados a un commit.
- Reserva, cancelación, rechazo y expiración: contadores coherentes e historial preservado, incluso en repeticiones o concurrencia.
- INS-09: prueba específica de carrera por el último cupo; no sustituirla por la prueba de concurrencia de agenda.
- Reglas: ninguna autorización incorrecta y ninguna operación supuestamente exitosa invalidada por el máximo de expresiones.
- Consulta: el estudiante solo ve lo suyo; el administrador conserva sus permisos.
- Pagos: demostración explícita en Sandbox. Para acreditar **seguridad de cobro real**, exigir validación de captura por backend confiable; de lo contrario declarar esa limitación y mantener el uso en simulación.
- QA automatizado: `flutter analyze`, `flutter test`, compilación web y suites Firestore sobre el mismo commit final, sin regresiones.

## 10. Planilla de evidencias del corte final

**Commit realmente probado:** ____________________
**Fecha/hora de ejecución:** ____________________
**Responsable:** ____________________
**Entorno (SO, Flutter, Node, Firebase CLI):** ____________________

| Caso | Resultado (APROBADO / FALLIDO / BLOQUEADO / NO EJECUTADO) | Evidencia concreta (archivo/log/test/captura) | Incidencia u observación |
|---|---|---|---|
| INS-01 | NO EJECUTADO | — | — |
| INS-02 | NO EJECUTADO | — | — |
| INS-03 | NO EJECUTADO | — | — |
| INS-04 | NO EJECUTADO | — | — |
| INS-05 | NO EJECUTADO | — | — |
| INS-06 | NO EJECUTADO | — | — |
| INS-07 | NO EJECUTADO | — | — |
| INS-08 | NO EJECUTADO | — | — |
| INS-09 | NO EJECUTADO | — | Requiere carrera real/automatizada entre dos estudiantes |
| INS-10 | NO EJECUTADO | — | — |
| INS-11 | NO EJECUTADO | — | Verificar causa exacta del rechazo |
| INS-12 | NO EJECUTADO | — | Verificar causa exacta del rechazo |
| INS-13 | BLOQUEADO | — | Verificación confiable de PayPal ausente; prueba Sandbox pendiente |

### 10.1. Suites automatizadas

| Suite | Archivo de log | Ejecución / aprobación / fallos | Máximo de expresiones |
|---|---|---|---|
| Flutter análisis | `flutter_analyze.log` | Pendiente | N/A |
| Flutter test | `flutter_test.log` | Pendiente | N/A |
| Flutter web build | `flutter_build_web.log` | Pendiente | N/A |
| Reglas generales | `reglas_generales.log` | Pendiente | Pendiente |
| Inscripciones y pagos | `inscripciones_pago.log` | Pendiente | Pendiente |
| Inscripciones avanzadas | `inscripciones_avanzadas.log` | Pendiente | Pendiente |
| Nómina y asistencia | `asistencias.log` | Pendiente | Pendiente |
| Concurrencia de agenda | `concurrencia_agenda.log` | Pendiente | Pendiente |

### 10.2. Registro de incidencias

| ID | Descripción | Impacto | Responsable | Estado |
|---|---|---|---|---|
| H3-SEC-001 | Posible agotamiento de las 1.000 expresiones en Firestore | Seguridad/funcionalidad | Por asignar | Pendiente de reproducción sobre el commit final |
| H3-PAY-001 | Sin comprobación confiable de captura en PayPal | No apto para pagos reales | Por asignar | Limitación conocida de Sandbox |
| H3-QA-001 | Evidencia integral pendiente de registrar | Cierre académico/técnico | Equipo | No ejecutado en este documento |

## 11. Antecedentes de validación y trazabilidad Git

- **6 de noviembre de 2026:** el documento de pruebas anterior registraba 175 pruebas Flutter y 31 pruebas de seguridad aprobadas, además de `flutter analyze` sin errores. Esos números pertenecen a un corte anterior y **no deben copiarse como resultados del QA consolidado actual**.
- **PR #30:** integración de reglas de inscripción con agenda, entrenadores y reseñas. Su descripción reportaba 175 pruebas de emulador ejecutadas secuencialmente y reconocía el problema de expresiones; fue fusionado a `develop` el 9 de noviembre de 2026.
- **PR #31:** índices y registro único de cédulas/carnets, integrado dentro de la rama del PR #30.
- **PR #34:** incorpora pagos PayPal Sandbox y la confirmación en transacción. Su descripción reporta 394 pruebas Flutter y 198 pruebas de reglas aprobadas. **Son cifras reportadas por el PR, no verificaciones independientes de este documento**.

Referencias del repositorio:

- [Repositorio Samán Deportivo](https://github.com/richardyradyf/SamanDeportivo)
- [PR #30 — Reglas de inscripciones](https://github.com/richardyradyf/SamanDeportivo/pull/30)
- [PR #31 — Registro único](https://github.com/richardyradyf/SamanDeportivo/pull/31)
- [PR #34 — PayPal Sandbox](https://github.com/richardyradyf/SamanDeportivo/pull/34)

## 12. Conclusión del plan

El Hito 3 dispone de una implementación considerable del módulo de inscripciones y de pruebas automatizadas asociadas. La **validación final**, sin embargo, exige ejecutar y documentar las suites sobre un mismo commit, comprobar los casos de concurrencia y confirmar que las denegaciones de Firestore no ocultan errores del evaluador. El flujo de pagos actual puede demostrarse como simulación académica en Sandbox, pero no valida de forma confiable la autenticidad de capturas.

**Próxima acción:** ejecutar el QA final, completar las tablas de resultados con evidencias y actualizar los estados INS-01 a INS-13 sin sustituir resultados observados por suposiciones basadas en la integración del código.
