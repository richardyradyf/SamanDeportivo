/**
 * A3.7 — Prueba end-to-end del disparador Firestore con emuladores.
 * Ejecutar SOLO mediante firebase emulators:exec --only auth,firestore,functions
 * Nunca escribe en producción; requiere FIRESTORE_EMULATOR_HOST.
 *
 * Esta prueba comprueba la ejecución real de onDocumentWritten y los
 * agregados en deportes/{codigo}; las reglas se prueban por separado.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, getApps, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const projectId = 'demo-saman-perfil';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('A3.7: FIRESTORE_EMULATOR_HOST no existe. Ejecute con Firebase Emulators.');
}
if (!process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST &&
    !process.env.FIREBASE_EMULATOR_HUB) {
  // La comprobación decisiva es observar los cambios de la función en Firestore.
  console.warn('A3.7: compruebe que el emulador de Functions también esté iniciado.');
}

const app = initializeApp({ projectId }, 'a3-7-e2e-' + process.pid);
const db = getFirestore(app);

async function esperarIndicadores(ref, { total, promedio }, etiqueta) {
  const deadline = Date.now() + 25000;
  let ultimo = null;
  while (Date.now() < deadline) {
    const snap = await ref.get();
    ultimo = snap.data() || null;
    if (ultimo && ultimo.totalResenas === total &&
        typeof ultimo.promedioCalificacion === 'number' &&
        Math.abs(ultimo.promedioCalificacion - promedio) < 0.00001) {
      return ultimo;
    }
    await new Promise(resolve => setTimeout(resolve, 350));
  }
  throw new Error(`Tiempo agotado en ${etiqueta}; esperado total=${total}, ` +
    `promedio=${promedio}; recibido ${JSON.stringify(ultimo)}`);
}

test('A3.7: una escritura real recalcula promedios visibles y preserva la agenda',
  { timeout: 130000 }, async (t) => {
    const codigo = 'TST-77';
    const ref = db.collection('deportes').doc(codigo);
    const resenas = ref.collection('resenas');
    const r1 = resenas.doc('usuario-test-1');
    const r2 = resenas.doc('usuario-test-2');
    const versionAgenda = Timestamp.fromDate(new Date('2026-11-07T12:00:00Z'));

    t.after(async () => {
      try { await ref.delete(); } catch (_) {}
      try { await deleteApp(app); } catch (_) {}
    });

    // Admin SDK contra el EMULADOR; se ignoran las reglas para sembrar datos.
    await ref.set({
      codigo, nombre: 'Deporte de prueba A3.7',
      promedioCalificacion: 0, totalResenas: 0,
      actualizadoEn: versionAgenda,
    });
    await r1.set({
      estudianteNombre: 'Prueba Uno', puntuacion: 5,
      comentario: 'Excelente', oculta: false, fecha: Timestamp.now(),
    });
    await esperarIndicadores(ref, { total: 1, promedio: 5 }, 'primera reseña');

    await r2.set({
      estudianteNombre: 'Prueba Dos', puntuacion: 3,
      comentario: 'Bien', oculta: false, fecha: Timestamp.now(),
    });
    await esperarIndicadores(ref, { total: 2, promedio: 4 }, 'segunda reseña');

    await r1.update({ oculta: true });
    await esperarIndicadores(ref, { total: 1, promedio: 3 }, 'ocultar reseña');

    await r2.update({ puntuacion: 4 });
    await esperarIndicadores(ref, { total: 1, promedio: 4 }, 'editar reseña');

    await r1.update({ oculta: false });
    await esperarIndicadores(ref, { total: 2, promedio: 4.5 }, 'mostrar reseña');

    await r1.update({ oculta: true });
    await r2.update({ oculta: true });
    const final = await esperarIndicadores(ref, { total: 0, promedio: 0 }, 'ocultar todas');
    assert.equal(final.actualizadoEn.toMillis(), versionAgenda.toMillis(),
      'La función no debe modificar la versión optimista de la agenda A2');
  });
