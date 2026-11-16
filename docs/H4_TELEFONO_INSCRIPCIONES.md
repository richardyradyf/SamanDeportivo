# Hito 4 - Telefono en inscripciones

**Responsable:** Mariana Di Buongrazio.

## Objetivo

Incorporar el telefono internacional del estudiante en las
inscripciones, manteniendo la compatibilidad con los registros
historicos y el funcionamiento del modulo de pagos.

## Cambios realizados

- Se agrega estudianteTelefono como String opcional al modelo Inscripcion.
- Se copia el telefono del perfil al crear una inscripcion.
- Se actualiza la copia del telefono durante la reinscripcion.
- Se conserva el telefono durante los cambios de estado.
- Se mantiene la compatibilidad con inscripciones antiguas sin telefono.
- Se actualizan las reglas de seguridad de Firestore.
- Se valida que el telefono coincida con el perfil del estudiante.
- Se impide modificar directamente el telefono de una inscripcion.

## Contrato de datos

- usuarios/{uid}.telefono: fuente principal del telefono actualizado.
- inscripciones/{id}.estudianteTelefono: copia historica del telefono.
- Formato internacional E.164.
- Los registros antiguos pueden no contener este atributo.

## Integracion con pagos

Se mantienen los estados existentes y el identificador unico
de la inscripcion.

El estado pendiente permite realizar o reintentar el pago.
La confirmacion requiere una inscripcion pendiente y vigente.

No se modifica el flujo de PayPal ni la interfaz de pagos.

## Pruebas realizadas

- Pruebas unitarias del modelo: 10 de 10 aprobadas.
- Pruebas de Firestore: 26 de 26 aprobadas.
- Flutter analyze: sin problemas detectados.
- Se agregaron 14 pruebas automatizadas.
- Se amplio la prueba existente de confirmacion de pago.

## Limitaciones y observaciones

- Queda pendiente verificar si persisten los errores del limite
  de 1000 expresiones observados en el Hito 3.
- El telefono de las inscripciones historicas no se sincroniza
  automaticamente al editar el perfil.
- La nomina puede mostrar No registrado cuando no exista telefono.
- Se mantiene la limitacion de verificacion de pagos en sandbox.
- Las reglas deben integrarse en develop antes de su despliegue.

## Coordinacion

- Alexander: registro, perfil y motor de reservas.
- Andres: nomina del entrenador y reintentos de pago.
- Gabriel: interfaz y coordinacion de reglas.
- Mariana: modelo de inscripcion, telefono, reglas y pruebas.