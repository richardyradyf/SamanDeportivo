// Reglas de nómina y asistencia (RF-13 y RF-14, Hito 3).
//
// npx firebase emulators:exec --config firebase.security.test.json \
//   --project demo-saman-perfil --only firestore \
//   "node --test test/firestore/asistencias.rules.test.mjs"
import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, query, setDoc,
  updateDoc, where, writeBatch,
} from 'firebase/firestore';

let env;

const usuario = (nombre, rol) => ({
  nombre, rol, estado: 'activo', correo: `${nombre}@correo.unimet.edu.ve`,
});

// Un estudiante confirmado por cada letra, para probar un lote completo.
const loteUids = ['est-a', 'est-b', 'est-c', 'est-d', 'est-e', 'est-f', 'est-g', 'est-h'];

const inscripcion = (estudianteUid, estado, entrenadorUid = 'ent-1') => ({
  estudianteUid,
  estudianteNombre: `Estudiante ${estudianteUid}`,
  estudianteCedula: '28000001',
  estudianteCarnet: '20231001',
  estudianteCorreo: `${estudianteUid}@correo.unimet.edu.ve`,
  deporteId: 'FUT-01',
  deporteNombre: 'Fútbol sala',
  entrenadorUid,
  estado,
});

const dia = new Date(2026, 10, 5);

/** Registro válido de asistencia de [uid] en FUT-01. */
const registro = (uid, cambios = {}) => ({
  inscripcionId: `${uid}_FUT-01`,
  estudianteUid: uid,
  estudianteNombre: `Estudiante ${uid}`,
  deporteId: 'FUT-01',
  entrenadorUid: 'ent-1',
  fecha: Timestamp.fromDate(dia),
  estado: 'presente',
  ...cambios,
});

const idDe = (uid) => `FUT-01_2026-11-05_${uid}`;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-saman-perfil',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios', 'admin-1'), usuario('admin', 'administrador'));
    await setDoc(doc(db, 'usuarios', 'ent-1'), usuario('entrenador1', 'entrenador'));
    await setDoc(doc(db, 'usuarios', 'ent-2'), usuario('entrenador2', 'entrenador'));
    await setDoc(doc(db, 'usuarios', 'est-1'), usuario('estudiante1', 'estudiante'));
    await setDoc(doc(db, 'usuarios', 'est-2'), usuario('estudiante2', 'estudiante'));
    await setDoc(doc(db, 'deportes', 'FUT-01'), {
      codigo: 'FUT-01', nombre: 'Fútbol sala', entrenadorUid: 'ent-1',
    });
    await setDoc(doc(db, 'inscripciones', 'est-1_FUT-01'), inscripcion('est-1', 'confirmada'));
    await setDoc(doc(db, 'inscripciones', 'est-2_FUT-01'), inscripcion('est-2', 'pendiente'));
    for (const uid of loteUids) {
      await setDoc(doc(db, 'inscripciones', `${uid}_FUT-01`), inscripcion(uid, 'confirmada'));
    }
    // Registro ya guardado, para las pruebas de lectura y corrección.
    await setDoc(doc(db, 'asistencias', idDe('est-1')), registro('est-1'));
  });
});

after(async () => { if (env) await env.cleanup(); });

const como = (uid) => env.authenticatedContext(uid).firestore();
const entrenador = () => como('ent-1');
const otroEntrenador = () => como('ent-2');
const estudiante = () => como('est-1');
const admin = () => como('admin-1');

// Escritura

test('el entrenador registra la asistencia de un inscrito confirmado', async () => {
  await assertSucceeds(setDoc(doc(entrenador(), 'asistencias', idDe('est-a')), registro('est-a')));
});

test('el entrenador NO registra a alguien con la inscripción pendiente', async () => {
  await assertFails(setDoc(doc(entrenador(), 'asistencias', idDe('est-2')), registro('est-2')));
});

test('otro entrenador NO registra asistencia en un deporte que no es suyo', async () => {
  await assertFails(setDoc(
    doc(otroEntrenador(), 'asistencias', idDe('est-b')),
    registro('est-b', { entrenadorUid: 'ent-2' }),
  ));
});

test('el entrenador NO registra a nombre de otro entrenador', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-b')),
    registro('est-b', { entrenadorUid: 'ent-2' }),
  ));
});

test('el estudiante NO marca su propia asistencia', async () => {
  await assertFails(setDoc(
    doc(estudiante(), 'asistencias', idDe('est-1')),
    registro('est-1', { entrenadorUid: 'est-1' }),
  ));
});

test('un ID que no corresponde al registro se rechaza', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', 'FUT-01_2026-11-05_est-c'),
    registro('est-d'),
  ));
});

test('un estado distinto de presente o ausente se rechaza', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-c')),
    registro('est-c', { estado: 'tarde' }),
  ));
});

test('campos de más se rechazan', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-c')),
    { ...registro('est-c'), nota: 'llegó tarde' },
  ));
});

test('una fecha futura se rechaza', async () => {
  const futura = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-c')),
    registro('est-c', { fecha: Timestamp.fromDate(futura) }),
  ));
});

test('un lote de 8 registros se guarda completo', async () => {
  const db = entrenador();
  const lote = writeBatch(db);
  for (const uid of loteUids) {
    lote.set(doc(db, 'asistencias', idDe(uid)), registro(uid, { estado: 'ausente' }));
  }
  await assertSucceeds(lote.commit());
});

test('el entrenador corrige presente por ausente', async () => {
  await assertSucceeds(updateDoc(doc(entrenador(), 'asistencias', idDe('est-1')), {
    estado: 'ausente',
  }));
});

test('el entrenador NO cambia el día de un registro', async () => {
  await assertFails(updateDoc(doc(entrenador(), 'asistencias', idDe('est-1')), {
    fecha: Timestamp.fromDate(new Date(2026, 10, 4)),
  }));
});

test('nadie borra un registro de asistencia', async () => {
  await assertFails(deleteDoc(doc(entrenador(), 'asistencias', idDe('est-1'))));
  await assertFails(deleteDoc(doc(admin(), 'asistencias', idDe('est-1'))));
});

// Lectura de asistencia

test('el estudiante ve su propio historial de asistencia', async () => {
  await assertSucceeds(getDocs(query(
    collection(estudiante(), 'asistencias'),
    where('estudianteUid', '==', 'est-1'),
  )));
});

test('el estudiante NO ve la asistencia de otros', async () => {
  await assertFails(getDocs(query(
    collection(como('est-2'), 'asistencias'),
    where('estudianteUid', '==', 'est-1'),
  )));
});

test('el entrenador ve el historial de su deporte', async () => {
  await assertSucceeds(getDocs(query(
    collection(entrenador(), 'asistencias'),
    where('deporteId', '==', 'FUT-01'),
    where('entrenadorUid', '==', 'ent-1'),
  )));
});

test('otro entrenador NO ve el historial de un deporte ajeno', async () => {
  await assertFails(getDoc(doc(otroEntrenador(), 'asistencias', idDe('est-1'))));
});

test('el administrador ve toda la asistencia', async () => {
  await assertSucceeds(getDocs(collection(admin(), 'asistencias')));
});

// Nómina

test('el entrenador ve la nómina confirmada de su deporte', async () => {
  await assertSucceeds(getDocs(query(
    collection(entrenador(), 'inscripciones'),
    where('entrenadorUid', '==', 'ent-1'),
    where('deporteId', '==', 'FUT-01'),
    where('estado', '==', 'confirmada'),
  )));
});

test('el entrenador NO ve inscripciones pendientes', async () => {
  await assertFails(getDoc(doc(entrenador(), 'inscripciones', 'est-2_FUT-01')));
  await assertFails(getDocs(query(
    collection(entrenador(), 'inscripciones'),
    where('entrenadorUid', '==', 'ent-1'),
    where('deporteId', '==', 'FUT-01'),
  )));
});

test('otro entrenador NO ve la nómina', async () => {
  await assertFails(getDocs(query(
    collection(otroEntrenador(), 'inscripciones'),
    where('entrenadorUid', '==', 'ent-1'),
    where('estado', '==', 'confirmada'),
  )));
});

test('el entrenador NO modifica inscripciones', async () => {
  await assertFails(updateDoc(doc(entrenador(), 'inscripciones', 'est-1_FUT-01'), {
    estado: 'cancelada',
  }));
});
