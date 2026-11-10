
# Plan de pruebas - Módulo de inscripciones

## Proyecto
Samán Deportivo - Hito 3 y Hito 4

## 1. Objetivo

Verificar el funcionamiento del módulo de inscripciones
deportivas, comprobando las validaciones del estudiante,
la disponibilidad de cupos, los cambios de estado y
la seguridad de las operaciones.

## 2. Entorno de pruebas

- Aplicación: Flutter
- Base de datos: Cloud Firestore
- Autenticación: Firebase Authentication
- Entorno: Firebase Emulator Suite
- Pruebas Flutter: flutter test
- Pruebas de seguridad: @firebase/rules-unit-testing

## 3. Casos de prueba

### INS-01. Inscripción exitosa

Precondición:
- Estudiante autenticado y activo.
- Deporte activo con cupos disponibles.
- El estudiante no tiene inscripción vigente.

Acción:
Solicitar una inscripción.

Resultado esperado:
- Se crea una inscripción pendiente.
- Se reserva exactamente un cupo.
- Se establece el plazo de pago.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-02. Inscripción duplicada

Precondición:
El estudiante ya tiene una inscripción vigente.

Acción:
Intentar inscribirse nuevamente al mismo deporte.

Resultado esperado:
- La operación se rechaza.
- No se crea otra reserva.
- Los cupos no cambian.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-03. Deporte sin cupos

Precondición:
El deporte tiene todos sus cupos ocupados.

Acción:
Solicitar una inscripción.

Resultado esperado:
- La inscripción se rechaza.
- No se supera el cupo máximo.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-04. Estudiante inactivo

Precondición:
El estudiante está marcado como inactivo.

Acción:
Intentar inscribirse.

Resultado esperado:
- No se reserva ningún cupo.
- Se muestra el mensaje correspondiente.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-05. Cancelación exitosa

Precondición:
El estudiante tiene una inscripción vigente.

Acción:
Confirmar la cancelación desde la aplicación.

Resultado esperado:
- El estado cambia a cancelada.
- Se libera exactamente un cupo.
- El historial registra la transición.

Estado: INTERFAZ PROBADA.
Pendiente: transacción real en Firestore.

### INS-06. Cancelación rechazada por el usuario

Acción:
Pulsar Cancelar inscripción y luego Volver.

Resultado esperado:
- No se llama al repositorio.
- La inscripción permanece sin cambios.

Estado: PRUEBA DE INTERFAZ APROBADA.

### INS-07. Reinscripción

Precondición:
Existe una inscripción cancelada o expirada.

Acción:
Solicitar una nueva inscripción al mismo deporte.

Resultado esperado:
- Se reutiliza el identificador anterior.
- Se conserva el historial.
- Se reserva un cupo si existe disponibilidad.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-08. Expiración

Precondición:
Una inscripción pendiente supera el plazo de pago.

Acción:
Ejecutar el proceso de expiración.

Resultado esperado:
- El estado cambia a expirada.
- Se libera el cupo.
- No se libera el mismo cupo dos veces.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-09. Inscripciones simultáneas

Precondición:
Queda un solo cupo y existen dos estudiantes activos.

Acción:
Ambos solicitan inscribirse simultáneamente.

Resultado esperado:
- Solo uno obtiene el cupo.
- El otro recibe un error de disponibilidad.
- El contador no supera el máximo.

Estado: PENDIENTE DE INTEGRACIÓN.

### INS-10. Consulta de inscripciones propias

Precondición:
El estudiante inicia sesión.

Acción:
Abrir Mis inscripciones.

Resultado esperado:
- Se muestran sus inscripciones.
- Se visualizan deporte, estado y fechas.
- Se actualiza la información al cambiar Firestore.

Estado: INTERFAZ PREPARADA.
Pendiente: verificar lectura real autorizada.

### INS-11. Protección de inscripciones ajenas

Acción:
Un estudiante intenta modificar una inscripción ajena.

Resultado esperado:
La operación es rechazada por Firestore.

Estado: PRUEBA DE SEGURIDAD APROBADA
con las reglas actuales.

### INS-12. Manipulación manual de cupos

Acción:
Un estudiante intenta modificar los contadores
del deporte sin una operación autorizada.

Resultado esperado:
Firestore rechaza la modificación.

Estado: PRUEBA DE SEGURIDAD APROBADA
con las reglas actuales.

### INS-13. Confirmación de pago

Precondición:
Existe una inscripción pendiente y un pago aprobado.

Acción:
El sistema recibe la verificación autorizada del pago.

Resultado esperado:
- El estado cambia a confirmada.
- Se actualizan los contadores correspondientes.
- No puede confirmarse desde el cliente con un pago falso.

Estado: PENDIENTE DE INTEGRACIÓN CON PAGOS.

## 4. Criterios de aceptación

El módulo podrá considerarse funcionalmente validado cuando:

- Las inscripciones válidas se completen correctamente.
- No se admitan duplicados ni sobrecupos.
- Las cancelaciones liberen el cupo correspondiente.
- Las reinscripciones mantengan el historial.
- Las expiraciones no produzcan dobles liberaciones.
- Los permisos de Firestore permitan únicamente
  operaciones autorizadas.
- Las pruebas automatizadas y de integración sean exitosas.

## 5. Evidencias

Para cada prueba de integración registrar:

- Identificador de la prueba.
- Fecha de ejecución.
- Resultado obtenido.
- Resultado esperado.
- Captura de pantalla o salida de terminal.
- Estado: aprobado, fallido o bloqueado.

## 6. Resultados registrados

Al 6 de noviembre de 2026:

- 175 pruebas Flutter aprobadas.
- 31 pruebas de seguridad de Firestore aprobadas.
- flutter analyze: sin errores.
- Las transacciones reales de inscripciones aún
  requieren reglas de seguridad específicas.

Los resultados anteriores no equivalen a la aprobación
de los casos de integración pendientes.
