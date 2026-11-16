# Hito 4 — Reservas de espacios: fase 1 (dominio y disponibilidad)

Responsable: **Alexander Ramírez**, quien también asumió el bloque de reservas
originalmente previsto para Mariana. No modifica el flujo de pagos de Andrés,
las pantallas del entrenador a cargo de Richard ni las inscripciones de Gabriel.

## Dependencias y orden de integración

1. **Primero** integrar el PR de Alexander del catálogo de `espacios` y la
   agenda administrativa con `HorarioSesion.espacioId`.
2. **Después** integrar este PR de dominio de reservas. La rama fue preparada
   encima de la rama del catálogo; el parche entregado contiene únicamente
   los cambios de esta fase.
3. **Por último**, implementar la fase 2 de escritura, seguridad y pantallas.

No desplegar esta fase como un sistema de reservas completo: todavía no hay
creación ni cancelación de reservas desde la aplicación. La colección de
disponibilidad admite **lectura**, pero se deniega toda escritura de clientes.

## Contrato de datos

### `reservasEspacios/{reservaId}` — privada (fase 2)

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `espacioId` | string | ID estable de `espacios/{espacioId}` |
| `usuarioUid` | string | Propietario, autenticado |
| `rol` | string | `estudiante`, `entrenador` o `administrador` |
| `inicio`, `fin` | timestamp UTC | Intervalo semiabierto `[inicio, fin)` |
| `motivo` | string | Entre 3 y 200 caracteres |
| `estado` | string | `activa` o `cancelada` |
| `creadoEn`, `actualizadoEn` | timestamp | Auditoría |

En fase 2, cada usuario leerá sus propias reservas; el administrador podrá
consultar las necesarias para su función. No publicar motivo ni datos
personales mediante el calendario.

### `ocupacionesEspacios/{reservaId}` — pública (lectura en fase 1)

Solo contiene `espacioId`, `inicio` y `fin`. Nunca incluir nombre, cédula,
carnet, correo, teléfono, UID, rol ni motivo. El ID debe ser aleatorio, no
derivado de la identidad del usuario. Al cancelar una reserva, la proyección
debe desaparecer en la **misma transacción** que cambia su estado privado.

El repositorio `FirestoreDisponibilidadRepository` observa esta proyección por
espacio y rango de fechas; `ValidacionesReserva.consultarOcupaciones` agrega
las clases semanales activas para que la interfaz muestre ambos bloqueos.
La consulta de calendario se limita a **31 días por ventana**, únicamente para
evitar cargar períodos enormes; **no** limita cuántos días ni con cuánta
antelación puede reservar un entrenador o administrador.

## Validaciones de dominio

- Todos: espacio activo, inicio futuro, fin posterior al inicio, motivo válido,
  sin intersección con otra reserva del mismo espacio ni con la agenda de
  disciplinas activas asignadas a él.
- Estudiantes: duración máxima de **2 horas** y finalización hasta **21 días**
  desde el momento de solicitud.
- Entrenadores y administradores: sin esos dos límites, pero sujetos a las
  mismas reglas de no solapamiento.
- Las reservas contiguas sí son válidas: una que termina a las 18:00 no impide
  otra que empieza exactamente a las 18:00.
- Las sesiones de deportes son **semanales**, no eventos de una sola fecha.
  Se interpretan con la hora oficial de Venezuela (Caracas, UTC−04:00).
- La compatibilidad con deportes antiguos sin `espacioId` utiliza el nombre
  del lugar. Antes de lanzar reservas, migrar las agendas antiguas para que
  todas apunten a IDs estables; la comparación por nombres puede ser ambigua.

## Fase 2 — pendientes imprescindibles

1. Implementar un repositorio de escritura para crear y cancelar reservas
   privadas junto a su proyección pública de forma atómica.
2. Unificar el **control de concurrencia** de agenda y reservas: cada alta,
   cancelación o cambio de horario que afecte un espacio debe pasar por el
   mismo mecanismo transaccional de validación/revisión. Revisar también las
   reglas para que no permitan esquivar ese mecanismo. No basta con un
   `get()` previo al `set()`: dos clientes podrían reservar simultáneamente.
3. Crear reglas de `reservasEspacios`: propietario autenticado, campos
   permitidos, referencias coherentes, límites por rol y privacidad.
   Verificar la correspondencia con `ocupacionesEspacios` mediante
   `getAfter()`/`existsAfter()` donde corresponda.
4. Considerar la limitación de Firestore Spark: las reglas por sí solas no
   pueden comprobar intersecciones arbitrarias contra todos los documentos.
   Para garantía resistente a clientes maliciosos se necesita un esquema de
   bloqueo verificable por reglas (p. ej. intervalos discretizados) o un
   proceso confiable en servidor. No afirmar que una comprobación solo desde
   Flutter elimina completamente las carreras.
5. Crear UI para los tres roles: elegir espacio, fecha y franja libre,
   confirmar reserva, listar **Mis reservas**, cancelar la propia y consultar
   disponibilidad por espacio/fecha/hora sin información privada.
6. Probar concurrencia de dos cuentas, choque con clase recurrente,
   cancelación, límites de estudiante, permisos por rol y consultas públicas.
7. Incluir datos de ejemplo para la exposición sin nombres en la proyección
   pública; coordinar con el sembrador de Alexander y con Richard.

## Pruebas de esta fase

```bash
dart analyze
flutter test test/models/reserva_espacio_test.dart \
  test/features/reservas/validaciones_reserva_test.dart
```

Para reglas, usar el emulador de Firestore y la suite que incluye
`test/firestore/firestore.rules.test.mjs`:

```bash
npm run test:rules
```
