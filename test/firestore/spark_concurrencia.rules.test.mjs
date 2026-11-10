/**
 * Samán Deportivo — QA de concurrencia administrativa para Firebase Spark.
 *
 * Prueba la frontera de SEGURIDAD y los commits atomicos de control/agenda
 * con DOS contextos autenticados distintos y un emulador real de Firestore.
 * NO importa ni ejecuta el gateway Dart. Para verificar la UI/gateway Dart,
 * ejecutar tambien el procedimiento manual en docs/SPARK_ALEXANDER_CIERRE.md.
 *
 * Ejecutar unicamente en emulador:
 * firebase emulators:exec --config firebase.security.test.json \
 *   --project demo-saman-concurrencia --only firestore \
 *   'node --test test/firestore/spark_concurrencia.rules.test.mjs'
 */
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test, {before, after, beforeEach} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, writeBatch,
  serverTimestamp,
} from 'firebase/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Ejecuta esta prueba usando firebase emulators:exec; nunca en producción.');
}

const projectId = 'demo-saman-concurrencia';
let env;
const HORARIO_A = {dia: 'lunes', horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha A'};
const HORARIO_B = {dia: 'lunes', horaInicio: '17:00', horaFin: '19:00', lugar: 'Cancha B'};
const HORARIO_C = {dia: 'lunes', horaInicio: '18:00', horaFin: '20:00', lugar: 'Cancha C'};

const deporte = (codigo, nombre) => ({
  codigo, nombre,
  descripcion: 'Deporte para prueba de concurrencia',
  disciplina: 'colectivo',
  costo: 0,
  imagenUrl: null,
  cupoMaximo: 20,
  cuposOcupados: 0,
  cuposConfirmados: 0,
  entrenadorUid: null,
  entrenadorNombre: null,
  entrenadorEspecialidad: null,
  horarios: [],
  dias: [],
  activo: true,
  promedioCalificacion: 0,
  totalResenas: 0,
  creadoEn: new Date('2026-11-01T12:00:00Z'),
  actualizadoEn: null,
});

const administracion = uid => ({
  rol: 'administrador', nombre: `Administrador ${uid}`,
  cedula: uid === 'admin-1' ? '12345678' : '12345679',
  correo: `${uid}@unimet.edu.ve`, carnet: '2026001', estado: 'activo',
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {rules: readFileSync('firestore.rules', 'utf8')},
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'usuarios', 'admin-1'), administracion('admin-1')),
      setDoc(doc(db, 'usuarios', 'admin-2'), administracion('admin-2')),
      setDoc(doc(db, 'usuarios', 'coach-1'), {
        rol: 'entrenador', nombre: 'Entrenador Uno',
        especialidad: 'Multideporte', correo: 'coach1@unimet.edu.ve',
        cedula: '98765432', aniosExperiencia: 8,
      }),
      setDoc(doc(db, 'deportes', 'FUT-01'), deporte('FUT-01', 'Fútbol')),
      setDoc(doc(db, 'deportes', 'TEN-01'), deporte('TEN-01', 'Tenis')),
    ]);
  });
});

function dbAdmin(uid) {
  return env.authenticatedContext(uid, {email: `${uid}@unimet.edu.ve`}).firestore();
}

function loteAgenda(db, codigo, horario, version, adminUid) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'deportes', codigo), {
    entrenadorUid: 'coach-1',
    entrenadorNombre: 'Entrenador Uno',
    entrenadorEspecialidad: 'Multideporte',
    horarios: [horario], dias: [horario.dia],
    actualizadoEn: serverTimestamp(),
  });
  batch.set(doc(db, 'control', 'agenda'), {
    version, codigoDeporte: codigo, adminUid,
    actualizadoEn: serverTimestamp(),
  });
  return batch;
}

test('carrera: dos administradores con la misma versión no confirman ambos', async () => {
  const a = dbAdmin('admin-1');
  const b = dbAdmin('admin-2');

  // Ambas propuestas parten de una agenda vacía y versión inicial 0.
  // Los horarios se solapan y se asignan al MISMO entrenador.
  const aPromise = loteAgenda(a, 'FUT-01', HORARIO_A, 1, 'admin-1').commit();
  const bPromise = loteAgenda(b, 'TEN-01', HORARIO_B, 1, 'admin-2').commit();
  const resultados = await Promise.allSettled([aPromise, bPromise]);
  assert.equal(resultados.filter(r => r.status === 'fulfilled').length, 1,
    `Exactamente una escritura debe ganar: ${JSON.stringify(resultados.map(r => r.status))}`);
  assert.equal(resultados.filter(r => r.status === 'rejected').length, 1);

  const control = (await getDoc(doc(a, 'control', 'agenda'))).data();
  const futbol = (await getDoc(doc(a, 'deportes', 'FUT-01'))).data();
  const tenis = (await getDoc(doc(a, 'deportes', 'TEN-01'))).data();
  assert.equal(control.version, 1);
  assert.equal(Number(futbol.entrenadorUid === 'coach-1') +
    Number(tenis.entrenadorUid === 'coach-1'), 1);
  assert.equal(futbol.cuposOcupados, 0);
  assert.equal(tenis.cuposOcupados, 0);
});

test('cliente rezagado no puede reutilizar la versión aunque cambie otro deporte', async () => {
  const a = dbAdmin('admin-1');
  const b = dbAdmin('admin-2');
  await assertSucceeds(loteAgenda(a, 'FUT-01', HORARIO_A, 1, 'admin-1').commit());
  await assertFails(loteAgenda(b, 'TEN-01', HORARIO_B, 1, 'admin-2').commit());
  const control = (await getDoc(doc(a, 'control', 'agenda'))).data();
  assert.equal(control.version, 1);
  assert.equal((await getDoc(doc(a, 'deportes', 'TEN-01'))).data().entrenadorUid, null);
});

test('versión siguiente permite un horario contiguo para el mismo entrenador', async () => {
  const a = dbAdmin('admin-1');
  const b = dbAdmin('admin-2');
  await assertSucceeds(loteAgenda(a, 'FUT-01', HORARIO_A, 1, 'admin-1').commit());
  // El gateway Dart debe comprobar antes que 18:00-20:00 no se cruza.
  await assertSucceeds(loteAgenda(b, 'TEN-01', HORARIO_C, 2, 'admin-2').commit());
  const control = (await getDoc(doc(a, 'control', 'agenda'))).data();
  assert.equal(control.version, 2);
  assert.equal((await getDoc(doc(a, 'deportes', 'FUT-01'))).data().horarios[0].horaFin, '18:00');
  assert.equal((await getDoc(doc(a, 'deportes', 'TEN-01'))).data().horarios[0].horaInicio, '18:00');
});

test('no se puede adelantar control de agenda sin actualizar el deporte', async () => {
  const a = dbAdmin('admin-1');
  await assertFails(setDoc(doc(a, 'control', 'agenda'), {
    version: 1, codigoDeporte: 'FUT-01', adminUid: 'admin-1',
    actualizadoEn: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(a, 'control', 'agenda'))).exists(), false);
});

test('no se pueden modificar horarios sin un avance válido del control', async () => {
  const a = dbAdmin('admin-1');
  await assertFails(updateDoc(doc(a, 'deportes', 'FUT-01'), {
    entrenadorUid: 'coach-1', entrenadorNombre: 'Entrenador Uno',
    entrenadorEspecialidad: 'Multideporte',
    horarios: [HORARIO_A], dias: ['lunes'], actualizadoEn: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(a, 'deportes', 'FUT-01'))).data().horarios.length, 0);
});
