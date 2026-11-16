# Hito 4 — Reservas de instalaciones (fase 2B: interfaz)

## Alcance

- Acceso «Reservas de espacios» en la barra superior para **estudiante,
  entrenador y administrador**. No modifica sus menús ni el número de pestañas.
- Catálogo de instalaciones **activas** y selección de fecha, hora, duración
  y motivo (entre 3 y 200 caracteres).
- Vista de clases semanales y reservas particulares ocupadas para el día
  elegido y el siguiente, **sin datos personales de otras reservas**.
- Consulta de las **reservas propias**, con su estado y opción de cancelar una
  reserva activa, previa confirmación.
- Restricciones visibles para estudiante: duración máxima de **2 horas** y
  anticipación máxima de **21 días**. La validación real se repite en la
  transacción de la fase 2A y en las reglas de Firestore.
- Mensajes de progreso, error de disponibilidad y cambio concurrente.

## Hora de Venezuela

La interfaz representa explícitamente las horas en Venezuela (UTC−04), igual
que el modelo de clases semanales del Hito 4. Guarda y compara `DateTime` UTC.
No usa la zona horaria local del computador o teléfono para asignar la cancha.
La vista incluye dos días para detectar también reservas que cruzan medianoche.

## Arquitectura

`ReservasEspaciosScreen` recibe contratos de repositorio inyectables:

- `EspacioRepository` — catálogo de instalaciones.
- `DeporteRepository` — horarios oficiales.
- `DisponibilidadRepository` — ocupaciones públicas.
- `ReservasRepository` — lectura, creación y cancelación de reservas propias.

En producción utiliza sus adaptadores `Firestore*`; en pruebas se inyectan
implementaciones falsas sin Firebase. No agrega colecciones, índices ni reglas
adicionales: usa el dominio y las transacciones del PR #46.

## Verificación desde la raíz del proyecto

```bash
git diff --check
dart format lib/features/reservas/presentation test/features/reservas/reservas_espacios_screen_test.dart
dart analyze
flutter test test/features/reservas/reservas_espacios_screen_test.dart
flutter test test/features/reservas test/features/estudiante/screens/inicio_estudiante_screen_test.dart test/features/admin/screens/inicio_admin_screen_test.dart test/features/entrenador/screens/inicio_entrenador_screen_test.dart
flutter test
```

### QA manual con emulador (tres roles)

1. Abrir «Reservas de espacios» y comprobar nombre y tipo de espacios activos.
2. Confirmar que los bloques de clase semanal y «Reservado» son visibles.
3. Crear una reserva válida; debe aparecer en «Mis reservas» y bloquear el
   intervalo en otra sesión.
4. Intentar reservar la misma cancha durante una clase o una reserva existente:
   mostrar error, **sin crear documentos**.
5. Dos usuarios intentan reservar a la vez: solo el primero debe completar la
   transacción; el segundo recarga la disponibilidad.
6. Cancelar una reserva propia: debe cambiar a `cancelada` y liberar el bloque
   público, sin borrar su historial privado.
7. Intentar superar las 2 h / 21 días como estudiante: debe rechazarse.
8. Confirmar que entrenadores y administradores pueden crear y cancelar sus
   **propias** reservas, sin poder consultar datos privados ajenos por esta UI.
9. Cambiar de día/instalación y comprobar que las ocupaciones se actualizan.
10. Comprobar en móvil y escritorio el acceso sin cambiar la navegación.

## Límites conocidos

- Las advertencias históricas de **1.000 expresiones** de Firestore Rules siguen
  pendientes de resolución (Hito 3). No declarar el QA de reglas como limpio.
- Un cliente modificado podría eludir el chequeo de solapamientos realizado en
  Flutter: Firestore Rules no comprueba todos los intervalos arbitrarios. Para
  protegerse de clientes maliciosos se necesitan bloqueos verificables por
  franja temporal o un backend de confianza. **No desplegar como producción.**
- El catálogo académico relee deportes y ocupaciones completos antes de la
  transacción; no está diseñado para miles de instalaciones.
