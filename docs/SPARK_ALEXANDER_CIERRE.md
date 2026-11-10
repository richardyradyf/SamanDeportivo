# Samán Deportivo — cierre técnico del trabajo de Alexander (Firebase Spark)

**Estado al 8 de noviembre de 2026:** los pasos 1–3 se instalaron en el worktree local y el usuario reportó 127/127 pruebas Firestore, 339/339 Flutter y `flutter analyze` sin errores. Este Paso 4 aporta pruebas adicionales y preparación del PR; su ejecución todavía debe realizarse en la Mac. **No se ha hecho deploy.**

## 1. Alcance que sí puede cerrar Alexander ahora

- Crear entrenador sin Cloud Functions usando una segunda app de Firebase Auth, transacción de perfil+índice de cédula e invitación por reset de contraseña.
- Agenda de deportes con `FirestoreAgendaGateway`, comprobación de conflictos y versión global `control/agenda`.
- Reseñas de estudiantes con inscripción confirmada, promedios visibles y moderación de administrador; transacciones protegidas por reglas y `control/resenas`.
- Pruebas de reglas sobre dos administradores simultáneos (nuevo en Paso 4), verificación estática, revisión de UI y PR con reversión del trigger del PR #24.

**Queda fuera de su bloque:** escrituras de `inscripciones` y `pagos` (todavía restringidas), pasarela de pagos simulada (Andrés), confirmación transaccional de reservas (Mariana) y eliminación general de `functions/` (decisión de integración una vez que no haya dependencias).

## 2. Instalar Paso 4 en el worktree existente

```bash
cd "$HOME/SamanDeportivo_spark_h3_paso2"
unzip -o "$HOME/Downloads/SamanDeportivo_Spark_Paso4_Alexander.zip" -d .
python3 spark_paso4/instalar.py --previsualizar
python3 spark_paso4/instalar.py --aplicar
```

El instalador **no modifica** `firestore.rules`, Dart ni pruebas previas. Comprueba los SHA-256 de Paso 3 y crea únicamente archivos de QA/documentación nuevos, sin sobrescribir. Permite repetición si los archivos añadidos son exactamente iguales.

## 3. Ejecutar las pruebas nuevas y existentes

```bash
bash scripts/qa_spark_alexander.sh
```

O por separado:

```bash
npm run test:rules
firebase emulators:exec --config firebase.security.test.json \
  --project demo-saman-concurrencia --only firestore \
  'node --test test/firestore/spark_concurrencia.rules.test.mjs'
flutter analyze
flutter test
git diff --check
```

Se espera que la nueva suite tenga **5 pruebas** y la anterior **127**, siempre que el snapshot coincida. La nueva suite prueba reglas de concurrencia y escrituras atómicas con dos contextos administrativos. **No invoca el gateway Flutter real**, así que no equivale por sí sola a probar dos interfaces reales.

## 4. Prueba manual de interfaz — dos sesiones de administrador

Solo en entorno de **emulador** o **pruebas controladas**, sin cambiar datos de producción:

1. Levantar los emuladores con las reglas locales, iniciar la app apuntando al emulador y preparar **dos cuentas administradoras diferentes** y un entrenador de prueba.
2. Abrir administrador A en un navegador y B en otro perfil o incógnito independiente; abrir la agenda de dos deportes diferentes antes de guardar.
3. En A asignar al entrenador X el lunes 16:00–18:00 al deporte 1. En B preparar para el mismo entrenador el lunes 17:00–19:00 en el deporte 2.
4. Guardar A; inmediatamente guardar B sin recargar. Debe rechazarse la segunda operación por versión desactualizada o por conflicto. Verificar que solo el deporte 1 cambió y que `control/agenda.version` avanzó una sola vez.
5. Recargar B: la operación de solapamiento debe seguir siendo rechazada.
6. Probar 18:00–20:00 en B (contiguo, no solapado): debe aceptarse tras refrescar.
7. Desasignar al entrenador y verificar que el deporte conserva los horarios y limpia nombre/especialidad.
8. Abrir dos administradores moderando reseñas visibles simultáneamente: el agregado debe coincidir con reseñas visibles y evitar perder el incremento de versión del control.
9. Registrar los resultados y capturas. Si una operación deja datos inconsistentes, **no desplegar ni fusionar**.

No extrapolar el resultado de una prueba aislada a todos los casos: la concurrencia real depende de la red y de los reintentos de Firestore.

## 5. Crear los commits locales y revertir el trigger del PR #24

El PR #24 ya fue fusionado a `develop` con merge commit:

`847b903c89c8d856d507d3145a4039e5853f9c2f`

Agregó el trigger `recalcularCalificacionesDeporte` más tres archivos de implementación/pruebas. El PR #26 ya incorporó el cálculo transaccional de Flutter, y los pasos Spark 2–3 añadieron validación por reglas. Mantener ambos sistemas arriesgaría recálculos duplicados.

**Importante:** primero confirma que la migración está localmente probada, luego realiza el commit de esa migración y **después** revierte el merge del PR #24 en un commit separado, pero en **la misma rama y el mismo PR**. Así el merge final a `develop` incorpora ambos cambios juntos.

```bash
cd "$HOME/SamanDeportivo_spark_h3_paso2"
git status --short

# INSPECCION: no ejecutar sobre main ni develop.
bash scripts/revertir_trigger_pr24.sh --verificar

# Agregar solo código y QA real de Alexander, no los respaldos ni instaladores.
git add firestore.rules \
  lib/features/admin/administracion/data/resenas_admin_repository.dart \
  lib/features/admin/entrenadores/data/firebase_agenda_gateway.dart \
  lib/features/admin/entrenadores/data/firebase_entrenador_provisioner.dart \
  lib/features/admin/entrenadores/data/firestore_agenda_gateway.dart \
  lib/features/admin/entrenadores/data/spark_entrenador_provisioner.dart \
  lib/features/admin/entrenadores/presentation/crear_entrenador_dialog.dart \
  lib/features/admin/entrenadores/presentation/entrenadores_admin_screen.dart \
  lib/features/admin/screens/inicio_admin_screen.dart \
  lib/features/estudiante/catalogo/data/firestore_resena_repository.dart \
  test/firestore/firestore.rules.test.mjs \
  test/firestore/spark_concurrencia.rules.test.mjs \
  docs/SPARK_ALEXANDER_CIERRE.md \
  docs/SPARK_ALEXANDER_PR.md \
  scripts/qa_spark_alexander.sh \
  scripts/verificar_spark_alexander.py \
  scripts/revertir_trigger_pr24.sh

git diff --cached --check
git diff --cached --stat
git diff --cached

# SOLO si el diff es correcto:
git commit -m 'refactor(spark): entrenadores, agenda, resenas y seguridad'

# Ahora no debe haber cambios rastreados sin commitear.
git diff --quiet && git diff --cached --quiet

# Reversión del trigger PR #24 como segundo commit de ESTE MISMO PR:
bash scripts/revertir_trigger_pr24.sh --aplicar

# Revisar alcance, confirmar que no borra funciones de otros módulos:
git show --stat HEAD
git diff origin/develop...HEAD --stat
```

**No hacer** `git revert` del PR #26: ahí está la base del cálculo transaccional. **No borrar `functions/`**: aún contiene funciones de otras áreas.

Si el revert presenta conflicto, ejecutar **antes de cualquier otro comando** `git status`, revisar los archivos conflictivos y, si no se puede resolver de forma segura, `git revert --abort`. No aplicar `git reset --hard`.

## 6. Después de los commits

- Verificar `git status --short` (los respaldos y carpetas auxiliares se verán como untracked, pero no deben entrar al PR).
- Ejecutar las dos suites de Firestore, `flutter analyze` y `flutter test` otra vez.
- Leer `docs/SPARK_ALEXANDER_PR.md`, incorporar la descripción del PR, y solo entonces hacer `git push -u origin refactor/alexander-spark-h3-paso2` y crear un PR **a `develop`** si el equipo autoriza esa integración.
- No desplegar las reglas en producción ni fusionar por cuenta propia sin comprobar que no bloqueen operaciones que están migrando Mariana y Andrés.

## 7. Limitaciones de seguridad y de implementación que deben quedar explícitas

- **Un cliente administrador manipulado puede eludir las validaciones de solapamiento de Flutter** si conserva el protocolo de versión. Las reglas no recorren todos los deportes; la protección es fuerte frente a administradores que usen el gateway correcto, pero no frente a uno malicioso. Para una garantía universal se necesitaría modelar ocupaciones únicas por entrenador/franja en documentos independientes o usar backend confiable.
- El documento global `control/agenda` y `control/resenas` serializa operaciones, pero puede generar contención y no escala bien a grandes cargas; es adecuado para el tamaño académico previsto.
- Auth y Firestore no comparten transacción; la cuenta de entrenador podría quedar huérfana si fallara el rollback compensatorio.
- El modo Spark propuesto no valida pagos verdaderos. Un recibo simulado no debe presentarse como transacción real de PayPal. Los módulos de Andrés y Mariana deben mantener sus reglas bloqueadas hasta implementar el acuerdo.
- Los promedios se validan con tolerancia matemática pequeña: se deben probar además series largas de reseñas y moderación si el dataset crece.
- Las suites de Firestore tienen límites de evaluación de reglas, coste y accesos; probar también operaciones reales sobre emuladores antes de desplegar.

## 8. Criterios de aceptación de la parte de Alexander

- [ ] Los **127 tests** existentes siguen verdes.
- [ ] Las **5 pruebas adicionales** de concurrencia pasan (132 de reglas en total, repartidas en 2 suites).
- [ ] `flutter analyze` sin problemas.
- [ ] Las **339 pruebas Flutter** existentes siguen pasando.
- [ ] Prueba manual con dos administradores completada y evidenciada.
- [ ] Prueba manual de creación, invitación y reenvío de entrenador completada.
- [ ] Prueba manual de reseña confirmada, actualización de promedio y moderación completada.
- [ ] Un único PR contiene migración + **revert PR #24**.
- [ ] `functions/` queda disponible hasta que todos acuerden su retirada.
- [ ] Sin cambios en inscripciones y pagos fuera del ámbito de Alexander.
