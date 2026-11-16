# Hito 4 — Reservas de instalaciones (fase 2A)

## Alcance del PR

- Repositorio de reservas para Flutter y Firebase Spark (sin Cloud Functions).
- Crear reservas privadas en `reservasEspacios/{id}` y su proyección pública
  `ocupacionesEspacios/{id}` en la misma transacción.
- Cancelar una reserva propia: pasarla a `cancelada`, eliminar su ocupación
  pública y actualizar el control de concurrencia atómicamente.
- Serializar los cambios de reservas y horarios de clases mediante la versión
  de `control/agenda`.
- Impedir, en el cliente, reservas en horarios de clases semanales o reservas
  existentes; impedir también que una nueva agenda invada reservas particulares.
- Reglas de Firestore que exigen escrituras enlazadas y sin datos personales
  en `ocupacionesEspacios`.

No incluye aún un formulario ni un calendario para estudiantes, entrenadores o
administradores. La integración visual se hará en un PR posterior (fase 2B).

## Contrato de datos

`reservasEspacios/{id}` (privado):

| Campo | Descripción |
| --- | --- |
| `espacioId` | Instalación del catálogo público |
| `usuarioUid`, `rol` | Propietario y rol verificados por reglas |
| `inicio`, `fin` | Fechas UTC almacenadas como Timestamp |
| `motivo` | Motivo de 3–200 caracteres, solo visible para su propietario y administradores |
| `estado` | `activa` o `cancelada` |
| `creadoEn`, `actualizadoEn` | Marcas del servidor |

`ocupacionesEspacios/{id}` (público): exclusivamente `espacioId`, `inicio` y
`fin`. Comparte ID con la reserva privada; al cancelar se elimina.

`control/agenda`: la versión aumenta en 1 tanto al cambiar una agenda como al
crear/cancelar una reserva. El documento guarda *o bien* la marca de edición
administrativa (`codigoDeporte`, `adminUid`) *o bien* la de reserva
(`reservaId`, `accion`), además de `version` y `actualizadoEn`.

## Concurrencia

1. La app lee desde el servidor versión, deportes y ocupaciones del espacio.
2. Una transacción vuelve a leer `control/agenda` y los documentos relacionados.
3. Si la versión cambió, se cancela la operación y se solicita recargar.
4. Se verifica la duración (estudiantes: máximo 2 h), la antelación
   (estudiantes: máximo 21 días) y la ausencia de solapes con clases y reservas.
5. Se escriben los tres documentos de la operación en un único commit.

La agenda administrativa aplica la misma verificación de reservas antes de
confirmar un cambio de clases. El algoritmo relee los documentos existentes,
por lo que está pensado para el tamaño pequeño del proyecto académico.

**Límite de seguridad de Firebase Spark:** Firestore Security Rules no puede
buscar reservas arbitrarias que se solapen en toda una colección. Las reglas
validan propiedad, duración, fecha, estructura y atomicidad, pero **la ausencia
de solapamientos se garantiza solo en el flujo transaccional de esta app**.
Un cliente modificado que escriba directamente en Firestore podría generar un
solape. Para una garantía adversarial se requiere otro diseño de datos con
bloqueos documentales por franja y reglas que los comprueben, o validación en
un servidor de confianza. No presentar esta versión como completamente segura
frente a clientes maliciosos.

## Verificación

Desde la raíz del repositorio:

```bash
git diff --check
dart analyze
flutter test test/models/reserva_espacio_test.dart test/features/reservas/validaciones_reserva_test.dart
npm run test:rules
```

Ejecutar además una prueba manual con dos sesiones simultáneas y una edición
de agenda concurrente. La suite de reglas histórica puede emitir la alerta de
1.000 expresiones: si ocurre, el QA de reglas queda **pendiente**, no aprobado.

No publicar reglas en Firebase ni integrar el PR hasta obtener resultados de
las pruebas del emulador y revisar la seguridad de las escrituras.
