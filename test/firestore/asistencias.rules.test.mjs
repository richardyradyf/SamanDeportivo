// Reglas de nómina y asistencia (RF-13 y RF-14, Hito 3).
//
// npx firebase emulators:exec --config firebase.security.test.json \
//   --project demo-saman-perfil --only firestore \
//   "node --test test/firestore/asistencias.rules.test.mjs"
import assert from 'node:assert/strict';
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

// Otra disciplina: BAS-01 es de ent-2 y est-m solo está inscrito ahí.
const registroBas = (uid, cambios = {}) => registro(uid, {
  inscripcionId: `${uid}_BAS-01`,
  deporteId: 'BAS-01',
  entrenadorUid: 'ent-2',
  ...cambios,
});

const idBas = (uid) => `BAS-01_2026-11-05_${uid}`;

/** Registros guardados de [uid] en FUT-01 el día de prueba, sin reglas. */
const registrosDelDia = async (uid) => {
  let docs = [];
  await env.withSecurityRulesDisabled(async (ctx) => {
    const res = await getDocs(query(
      collection(ctx.firestore(), 'asistencias'),
      where('estudianteUid', '==', uid),
      where('deporteId', '==', 'FUT-01'),
      where('fecha', '==', Timestamp.fromDate(dia)),
    ));
    docs = res.docs;
  });
  return docs;
};

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
    await setDoc(doc(db, 'deportes', 'BAS-01'), {
      codigo: 'BAS-01', nombre: 'Baloncesto', entrenadorUid: 'ent-2',
    });
    await setDoc(doc(db, 'inscripciones', 'est-m_BAS-01'), {
      ...inscripcion('est-m', 'confirmada', 'ent-2'),
      deporteId: 'BAS-01',
      deporteNombre: 'Baloncesto',
    });
    // Registros ya guardados, para las pruebas de lectura y corrección.
    await setDoc(doc(db, 'asistencias', idDe('est-1')), registro('est-1'));
    await setDoc(doc(db, 'asistencias', idDe('est-f')), registro('est-f', { estado: 'ausente' }));
    await setDoc(doc(db, 'asistencias', idBas('est-m')), registroBas('est-m'));
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

test('un ID con una fecha distinta a la del registro se rechaza', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', 'FUT-01_2026-11-04_est-c'),
    registro('est-c'),
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

test('el entrenador corrige guardando el registro completo, como la app', async () => {
  await assertSucceeds(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-f')),
    registro('est-f', { estado: 'presente' }),
  ));
});

test('la corrección actualiza el mismo documento y no crea otro', async () => {
  const docs = await registrosDelDia('est-f');
  assert.equal(docs.length, 1);
  assert.equal(docs[0].id, idDe('est-f'));
  assert.equal(docs[0].data().estado, 'presente');
});

test('el entrenador NO cambia el día al corregir con el registro completo', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-f')),
    registro('est-f', { fecha: Timestamp.fromDate(new Date(2026, 10, 4)) }),
  ));
});

test('el entrenador NO cambia la hora de la fecha al corregir', async () => {
  await assertFails(updateDoc(doc(entrenador(), 'asistencias', idDe('est-f')), {
    fecha: Timestamp.fromDate(new Date(2026, 10, 5, 15, 30)),
  }));
});

test('el entrenador NO pasa un registro a otro estudiante al corregir', async () => {
  await assertFails(updateDoc(doc(entrenador(), 'asistencias', idDe('est-f')), {
    estudianteUid: 'est-g',
    inscripcionId: 'est-g_FUT-01',
  }));
});

test('las correcciones rechazadas no cambian el registro', async () => {
  const docs = await registrosDelDia('est-f');
  assert.equal(docs.length, 1);
  assert.equal(docs[0].data().estudianteUid, 'est-f');
  assert.deepEqual(docs[0].data().fecha, Timestamp.fromDate(dia));
});

// Otra disciplina

test('el entrenador de la otra disciplina sí registra en la suya', async () => {
  await assertSucceeds(setDoc(
    doc(otroEntrenador(), 'asistencias', idBas('est-m')),
    registroBas('est-m', { estado: 'ausente' }),
  ));
});

test('el entrenador NO registra asistencia en otra disciplina aunque firme como él', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idBas('est-m')),
    registroBas('est-m', { entrenadorUid: 'ent-1' }),
  ));
});

test('el entrenador NO registra en su disciplina a un inscrito de otra', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-m')),
    registro('est-m'),
  ));
});

test('el entrenador NO usa la inscripción de otra disciplina en la suya', async () => {
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idDe('est-m')),
    registro('est-m', { inscripcionId: 'est-m_BAS-01' }),
  ));
});

test('el entrenador NO corrige la asistencia de otra disciplina', async () => {
  await assertFails(updateDoc(doc(entrenador(), 'asistencias', idBas('est-m')), {
    estado: 'presente',
  }));
  await assertFails(setDoc(
    doc(entrenador(), 'asistencias', idBas('est-m')),
    registroBas('est-m', { entrenadorUid: 'ent-1', estado: 'presente' }),
  ));
});

test('el entrenador NO lee la asistencia de otra disciplina', async () => {
  await assertFails(getDoc(doc(entrenador(), 'asistencias', idBas('est-m'))));
  await assertFails(getDocs(query(
    collection(entrenador(), 'asistencias'),
    where('deporteId', '==', 'BAS-01'),
  )));
  await assertFails(getDocs(query(
    collection(entrenador(), 'asistencias'),
    where('deporteId', '==', 'BAS-01'),
    where('entrenadorUid', '==', 'ent-2'),
  )));
});

test('la consulta del entrenador solo trae registros de su disciplina', async () => {
  const res = await assertSucceeds(getDocs(query(
    collection(entrenador(), 'asistencias'),
    where('entrenadorUid', '==', 'ent-1'),
  )));
  assert.ok(res.size > 0);
  assert.ok(res.docs.every((d) => d.data().deporteId === 'FUT-01'));
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
