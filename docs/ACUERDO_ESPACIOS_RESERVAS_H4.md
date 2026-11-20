# Hito 4 — Contrato compartido de espacios y reservas

**Responsables:** Alexander (catálogo de espacios, agenda deportiva y validación de conflictos); Mariana (reservas, reglas y concurrencia); Gabriel (consulta de disponibilidad).

## Decisiones de modelo que ya implementa la rama de Alexander

- `espacios/{espacioId}` representa una instalación física. El ID es el identificador estable y **no cambia** cuando se edita su nombre.
- Campos: `nombre` (3–100 caracteres), `tipo` (1–60), `descripcion` (0–500), `activo` (booleano), `creadoEn` y `actualizadoEn` (timestamps).
- Se desactiva un espacio; no se elimina porque puede tener clases y reservas históricas.
- Todos los usuarios pueden leer este catálogo para consultar disponibilidad; solo un administrador puede crearlo o actualizarlo.
- `deportes/{codigo}.horarios[]` incorpora `espacioId` y conserva `lugar` como nombre de presentación para compatibilidad con los datos del Hito 3.
- La agenda debe comparar conflictos por `espacioId`, no por nombre. Los registros antiguos sin ID se comparan temporalmente por `lugar` y **deben migrarse** antes de activar las reservas generales.
- Intervalos contiguos son válidos: `[16:00, 18:00)` y `[18:00, 20:00)` no se solapan.

## Propuesta de colección para Mariana

`reservasEspacios/{reservaId}`:

| Campo | Tipo | Propósito |
| --- | --- | --- |
| `espacioId` | string | Referencia a `espacios/{espacioId}` |
| `usuarioUid` | string | Propietario autenticado |
| `rol` | string | Rol registrado en el momento de la reserva |
| `inicio` | timestamp | Fecha y hora exactas del inicio |
| `fin` | timestamp | Fecha y hora exactas del final |
| `motivo` | string | Uso previsto |
| `estado` | string | `activa` o `cancelada` |
| `creadoEn` | timestamp | Fecha de creación |
| `actualizadoEn` | timestamp | Última modificación |

**Validaciones de negocio:**

1. Todos los usuarios autenticados pueden reservar espacios activos, sin choques con otra reserva activa ni con una clase deportiva.
2. Para estudiantes: `fin - inicio <= 120 minutos` e `inicio <= ahora + 21 días`. No se permiten inicios pasados ni intervalos de duración nula/negativa.
3. Para entrenadores y administradores no aplicar esos límites de duración ni antelación. Sí siguen prohibidos los conflictos y las fechas pasadas.
4. Comparar intervalos como semiabiertos: `inicioA < finB && inicioB < finA`.
5. La disponibilidad pública solo debe exponer el espacio y las horas ocupadas, no el teléfono, correo ni identidad de otros usuarios.
6. La ocupación de una clase semanal se repite el día correspondiente mientras el deporte siga activo; usar una zona horaria definida para la universidad (propuesta: `America/Caracas`).

## Concurrencia: acuerdo pendiente de implementación conjunta

La rama actual de Alexander conserva el control existente `control/agenda`, que serializa modificaciones administrativas de las clases. **Por sí solo no bloquea una reserva creada concurrentemente.**

Antes de habilitar las reservas, acordar e implementar un **control compartido de ocupación** para *ambas* operaciones:

- Propuesta: `control/ocupacion` con una versión incremental leída y actualizada en la misma transacción de Firestore tanto al guardar una agenda como al crear/cancelar una reserva.
- Cada operación debe volver a comprobar las ocupaciones con la versión actual y fallar/reintentarse si cambió el estado.
- Las reglas deben exigir la escritura vinculada y comprobarla mediante `getAfter()`; ningún cliente debe poder eludir el control escribiendo solamente el documento de reserva/deporte.
- No basarse solo en una consulta previa de Flutter: dos clientes podrían consultar simultáneamente una franja libre.
- Contemplar los límites de acceso a documentos de las reglas de Firestore y pruebas de dos usuarios concurrentes.

## Próximos pasos acordados

1. **Alexander:** entregar `espacios`, pantalla administrativa, selector de espacios y detección de cruces entre deportes. Migrar horarios existentes a IDs antes de activar reservas.
2. **Mariana:** implementar `reservasEspacios`, permisos por rol, flujo de creación/cancelación y control compartido con la agenda.
3. **Alexander + Mariana:** completar el control de ocupación y las pruebas de concurrencia clase↔reserva, reserva↔reserva y admin↔admin antes de considerar el módulo terminado.
4. **Gabriel:** consumir las lecturas de espacios y reservas para presentar disponibilidad y «Mis reservas», sin recalcular permisos en la interfaz.

**Nota:** el catálogo de espacios de Alexander es una primera entrega independiente. El bloqueo universal de ocupaciones no está cerrado hasta integrar el trabajo de Mariana y las reglas compartidas.
