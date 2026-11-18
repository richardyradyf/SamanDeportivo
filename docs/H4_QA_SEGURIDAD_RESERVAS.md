# Hito 4 - Seguridad, concurrencia y QA de reservas

## 1. Información general

- Proyecto: Samán Deportivo.
- Responsable: Mariana Di Buongrazio.
- Fecha: 16 de noviembre de 2026.
- Rama: feature/mariana-seguridad-reservas-h4.
- Entorno: Flutter Web y Firebase Emulator Suite.
- Destino de integración: develop.

## 2. Objetivo

Verificar la seguridad, privacidad, concurrencia y consistencia
de las reservas de espacios deportivos, incluyendo su relación
con las clases oficiales y la agenda administrativa.

Adicionalmente, incorporar la restricción temporal de cancelación
acordada con Alexander y Gabriel.

## 3. Cambios funcionales

Una reserva solamente puede cancelarse cuando:

- El usuario autenticado es su propietario.
- Su estado es activa.
- La fecha actual es estrictamente anterior a su inicio.

La restricción se aplica a estudiantes, entrenadores y
administradores.

El repositorio Flutter utiliza DateTime.now() para validar
la operación. Las reglas de Firestore utilizan request.time
para evitar que la restricción dependa del reloj del cliente.

La cancelación conserva el documento privado, elimina la
ocupación pública e incrementa la versión del control de agenda
mediante una operación atómica.

No se modificaron las firmas públicas del repositorio ni
las pantallas de reservas.

## 4. Resultados de pruebas

| Tipo de prueba | Ejecutadas | Aprobadas |
|---|---:|---:|
| Flutter test | 470 | 470 |
| Reglas de Firestore | 179 | 179 |
| Integración Flutter Web | 7 | 7 |
| Total | 656 | 656 |

Flutter analyze: sin problemas detectados.

Las comprobaciones de integración se ejecutaron mediante una
herramienta QA independiente en Chrome, no mediante flutter test.

## 5. Pruebas incorporadas

Se agregaron 36 pruebas automatizadas de Firestore:

| Categoría | Cantidad |
|---|---:|
| Concurrencia y caracterización de limitaciones | 3 |
| Cancelaciones | 6 |
| Conflictos entre clases y reservas | 4 |
| Restricciones por rol | 9 |
| Privacidad y seguridad | 9 |
| Restricción temporal de cancelación | 5 |
| Total | 36 |

También se incorporaron siete comprobaciones directas de
integración con los repositorios reales de Flutter.

La contribución comprende 43 pruebas y comprobaciones nuevas.

## 6. Pruebas de integración

| ID | Escenario | Resultado |
|---|---|---|
| INT-01 | Dos estudiantes reservan simultáneamente | Aprobada |
| INT-02 | Reserva sobre otra reserva existente | Aprobada |
| INT-03 | Reserva sobre una clase oficial | Aprobada |
| INT-04 | Clase sobre una reserva activa | Aprobada |
| INT-05 | Cancelación y reutilización del horario | Aprobada |
| INT-06 | Cancelación de una reserva en curso | Aprobada |
| INT-07 | Cancelación de una reserva finalizada | Aprobada |

En INT-01 solamente una solicitud consiguió confirmar
la reserva. La otra recibió permission-denied de Firestore.

Las comprobaciones INT-02, INT-03 e INT-04 verificaron
los mensajes funcionales de conflicto del repositorio.

## 7. Restricción temporal

Las pruebas H4-TEMP-01 a H4-TEMP-05 verifican:

- Cancelación permitida antes del inicio.
- Rechazo de cancelación de una reserva en curso.
- Rechazo de cancelación de una reserva finalizada.
- Rechazo de cancelación tardía de un administrador.
- Rechazo de cancelación tardía de un entrenador.

Las operaciones rechazadas mantienen intactos los tres
documentos involucrados.

La igualdad exacta entre la hora actual y el inicio queda
excluida por la comparación estricta de la implementación,
aunque no se reprodujo experimentalmente ese instante exacto.

## 8. Privacidad y consistencia

Se comprobó que:

- Los visitantes no pueden leer reservas privadas.
- La ocupación pública no expone datos personales.
- Los usuarios no pueden cancelar reservas ajenas.
- El administrador puede leer reservas ajenas, pero no cancelarlas.
- No se permiten modificaciones directas de la ocupación pública.
- Las operaciones de reserva requieren el control de agenda.
- Una cancelación válida libera el horario correspondiente.

## 9. Limitaciones identificadas

El control de agenda serializa operaciones mediante versiones.

Sin embargo, las reglas actuales no garantizan por sí solas
la ausencia de solapamientos arbitrarios ante clientes modificados.

Se reprodujeron tres escenarios:

- H4-LIM-01: creación directa de reservas solapadas.
- H4-LIM-02: creación directa de una reserva sobre una clase.
- H4-LIM-03: modificación directa de una clase sobre una reserva.

Estas pruebas son de caracterización: aprobarlas significa
que se reprodujo la limitación, no que se solucionó.

El repositorio habitual de Flutter sí rechazó los conflictos
evaluados en las pruebas de integración.

Se recomienda evaluar una arquitectura de escritura confiable
o un mecanismo de bloqueo verificable mediante reglas.

También se recomienda migrar las agendas históricas para que
utilicen espacioId, evitando depender únicamente del nombre
de la instalación.

## 10. Límite de 1000 expresiones

Se detectaron advertencias anteriores a esta contribución
relacionadas con el límite de evaluación de Firestore.

Las principales reglas involucradas corresponden a las
actualizaciones de deportes e inscripciones.

En la ejecución de 36 pruebas anterior a la restricción
temporal se observaron 12 apariciones del mensaje asociado
al límite, distribuidas entre cuatro casos.

Las cinco nuevas pruebas temporales no presentaron ese
aviso específico en la ejecución de 41 pruebas.

Persisten errores de evaluación en algunas operaciones
denegadas. Una prueba negativa aprobada no garantiza que
el rechazo se haya producido exclusivamente por la condición
que se pretendía verificar.

La optimización de estas reglas queda pendiente.

## 11. Reproducción de pruebas

### Pruebas de Flutter

    flutter test
    flutter analyze

### Pruebas de Firestore

    npx.cmd firebase emulators:exec --config firebase.security.test.json --project demo-saman-concurrencia --only firestore 'node --test --test-concurrency=1 test/firestore/firestore.rules.test.mjs test/firestore/spark_concurrencia.rules.test.mjs'

### Integración con Flutter Web

Terminal 1:

    npx.cmd firebase emulators:start --config firebase.reservas.test.json --project demo-saman-reservas-h4 --only auth,firestore

Terminal 2, después de iniciar los emuladores:

    $env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
    $env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"

    node scripts/cargar_datos_reservas_h4.mjs

    flutter run -d chrome -t tool/qa_reservas_h4.dart

Utilizar un entorno de emulación limpio para reproducir
las pruebas de integración.

## 12. Conclusiones

Las pruebas realizadas respaldan el funcionamiento de los
flujos evaluados de reservas, cancelaciones, privacidad y agenda.

Se incorporó la restricción temporal tanto en Flutter como
en las reglas de Firestore.

Los resultados no constituyen una certificación absoluta
de seguridad y deben interpretarse junto con las limitaciones
documentadas.

No se realizaron despliegues en Firebase de producción
como parte de esta contribución.