
import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-saman-inscripciones-permitidas',
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

function estudiante(uid) {
  return env.authenticatedContext(uid, {
    email: `${uid}@unimet.edu.ve`,
  }).firestore();
}

function datosEstudiante(uid, cedula, carnet) {
  return {
    cedula,
    nombre: 'Estudiante de Prueba',
    correo: `${uid}@unimet.edu.ve`,
    rol: 'estudiante',
    carnet,
    estado: 'activo',
  };
}

async function registrar(uid, cedula, carnet) {
  const db = estudiante(uid);
  const batch = writeBatch(db);

  batch.set(
    doc(db, 'usuarios', uid),
    datosEstudiante(uid, cedula, carnet),
  );

  batch.set(doc(db, 'cedulas', cedula), { uid });
  batch.set(doc(db, 'carnets', carnet), { uid });

  return batch.commit();
}

test('registro completo con cedula y carnet nuevos', async () => {
  await assertSucceeds(
    registrar('uid-unico-a', '28111001', '20261001'),
  );
});

test('rechazar una cedula registrada por otro estudiante', async () => {
  await assertSucceeds(
    registrar('uid-unico-b', '28111002', '20261002'),
  );

  await assertFails(
    registrar('uid-unico-c', '28111002', '20261003'),
  );
});

test('rechazar un carnet registrado por otro estudiante', async () => {
  await assertSucceeds(
    registrar('uid-unico-d', '28111004', '20261004'),
  );

  await assertFails(
    registrar('uid-unico-e', '28111005', '20261004'),
  );
});

test('rechazar el registro sin indices', async () => {
  const uid = 'uid-sin-indices';
  const db = estudiante(uid);

  await assertFails(
    setDoc(
      doc(db, 'usuarios', uid),
      datosEstudiante(uid, '28111006', '20261006'),
    ),
  );
});

test('rechazar cambios directos del carnet', async () => {
  const uid = 'uid-unico-f';

  await assertSucceeds(
    registrar(uid, '28111007', '20261007'),
  );

  const db = estudiante(uid);

  await assertFails(
    updateDoc(doc(db, 'usuarios', uid), {
      carnet: '20269999',
    }),
  );
});

test('permitir cambiar el nombre sin modificar el carnet', async () => {
  const uid = 'uid-unico-g';

  await assertSucceeds(
    registrar(uid, '28111008', '20261008'),
  );

  const db = estudiante(uid);

  await assertSucceeds(
    updateDoc(doc(db, 'usuarios', uid), {
      nombre: 'Nombre Actualizado',
    }),
  );
});

test('permitir cambiar a un carnet disponible', async () => {
  const uid = 'uid-unico-h';

  await assertSucceeds(
    registrar(uid, '28111009', '20261009'),
  );

  const db = estudiante(uid);
  const batch = writeBatch(db);

  batch.set(doc(db, 'carnets', '20261010'), { uid });

  batch.update(doc(db, 'usuarios', uid), {
    carnet: '20261010',
  });

  batch.delete(doc(db, 'carnets', '20261009'));

  await assertSucceeds(batch.commit());

  const perfil = await getDoc(doc(db, 'usuarios', uid));

  if (perfil.data()?.carnet !== '20261010') {
    throw new Error('El carnet no se actualizo');
  }
});

test('rechazar un cambio hacia un carnet ocupado', async () => {
  await assertSucceeds(
    registrar('uid-unico-i', '28111011', '20261011'),
  );

  await assertSucceeds(
    registrar('uid-unico-j', '28111012', '20261012'),
  );

  const db = estudiante('uid-unico-j');
  const batch = writeBatch(db);

  batch.set(doc(db, 'carnets', '20261011'), {
    uid: 'uid-unico-j',
  });

  batch.update(doc(db, 'usuarios', 'uid-unico-j'), {
    carnet: '20261011',
  });

  batch.delete(doc(db, 'carnets', '20261012'));

  await assertFails(batch.commit());
});

test('dos estudiantes compiten por la misma cedula', async () => {
  const resultados = await Promise.allSettled([
    registrar('uid-carrera-a', '28999001', '20269001'),
    registrar('uid-carrera-b', '28999001', '20269002'),
  ]);

  const exitosos = resultados.filter(
    (resultado) => resultado.status === 'fulfilled',
  );

  const rechazados = resultados.filter(
    (resultado) => resultado.status === 'rejected',
  );

  if (exitosos.length !== 1 || rechazados.length !== 1) {
    throw new Error(
      'Debe registrarse exactamente un estudiante con esa cedula',
    );
  }
});

test('dos estudiantes compiten por el mismo carnet', async () => {
  const resultados = await Promise.allSettled([
    registrar('uid-carrera-c', '28999003', '20269003'),
    registrar('uid-carrera-d', '28999004', '20269003'),
  ]);

  const exitosos = resultados.filter(
    (resultado) => resultado.status === 'fulfilled',
  );

  const rechazados = resultados.filter(
    (resultado) => resultado.status === 'rejected',
  );

  if (exitosos.length !== 1 || rechazados.length !== 1) {
    throw new Error(
      'Debe registrarse exactamente un estudiante con ese carnet',
    );
  }
});
