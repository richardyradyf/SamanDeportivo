import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;
const datosA = {
  nombre: 'Estudiante Uno', correo: 'uno@unimet.edu.ve', cedula: '12345678',
  carnet: '202611111', rol: 'estudiante', estado: 'activo',
};
const datosB = { ...datosA, nombre: 'Estudiante Dos', correo: 'dos@unimet.edu.ve',
  cedula: '12345679', carnet: '202622222' };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-saman-perfil',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', 'uid-a'), datosA);
    await setDoc(doc(ctx.firestore(), 'usuarios', 'uid-b'), datosB);
    await setDoc(doc(ctx.firestore(), 'usuarios', 'uid-admin'), {
      ...datosA, nombre: 'Administradora', correo: 'admin@unimet.edu.ve',
      rol: 'administrador',
    });
  });
});

after(async () => { if (env) await env.cleanup(); });

const estudiante = () => env.authenticatedContext('uid-a', { email: 'uno@unimet.edu.ve' }).firestore();
const admin = () => env.authenticatedContext('uid-admin', { email: 'admin@unimet.edu.ve' }).firestore();

test('estudiante consulta su propio perfil', async () => {
  await assertSucceeds(getDoc(doc(estudiante(), 'usuarios', 'uid-a')));
});

test('estudiante NO lee el perfil ajeno', async () => {
  await assertFails(getDoc(doc(estudiante(), 'usuarios', 'uid-b')));
});

test('estudiante cambia solamente nombre y carnet', async () => {
  await assertSucceeds(updateDoc(doc(estudiante(), 'usuarios', 'uid-a'), {
    nombre: 'Estudiante Modificado', carnet: '202633333',
  }));
});

test('estudiante NO puede convertirse en administrador', async () => {
  await assertFails(updateDoc(doc(estudiante(), 'usuarios', 'uid-a'), {
    rol: 'administrador',
  }));
});

test('estudiante NO puede modificar cedula ni estado', async () => {
  await assertFails(updateDoc(doc(estudiante(), 'usuarios', 'uid-a'), {
    cedula: '99999999', estado: 'inactivo',
  }));
});

test('estudiante NO puede crear un entrenador', async () => {
  const usurpador = env.authenticatedContext('uid-fraud', { email: 'fraud@unimet.edu.ve' }).firestore();
  await assertFails(setDoc(doc(usurpador, 'usuarios', 'uid-fraud'), {
    ...datosA, correo: 'fraud@unimet.edu.ve', rol: 'entrenador',
  }));
});

test('administrador puede consultar otros perfiles', async () => {
  await assertSucceeds(getDoc(doc(admin(), 'usuarios', 'uid-b')));
});

test('usuario anonimo no puede consultar perfiles', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'usuarios', 'uid-a')));
});


// Pruebas adicionales de Alexander: entrenador y administrador

async function prepararEntrenador(uid) {
  const correo = `${uid}@unimet.edu.ve`;

  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', uid), {
      nombre: 'Entrenador Prueba',
      correo,
      cedula: '12345679',
      rol: 'entrenador',
      especialidad: 'Baloncesto',
      aniosExperiencia: 5,
    });
  });

  return env.authenticatedContext(uid, { email: correo }).firestore();
}

test('entrenador puede editar su propio nombre', async () => {
  const coach = await prepararEntrenador('uid-coach-edit');

  await assertSucceeds(
    updateDoc(doc(coach, 'usuarios', 'uid-coach-edit'), {
      nombre: 'Entrenador Actualizado',
    }),
  );
});

test('administrador puede editar su propio nombre', async () => {
  await assertSucceeds(
    updateDoc(doc(admin(), 'usuarios', 'uid-admin'), {
      nombre: 'Administrador Actualizado',
    }),
  );
});

test('entrenador NO puede modificar su especialidad', async () => {
  const coach = await prepararEntrenador('uid-coach-deny');

  await assertFails(
    updateDoc(doc(coach, 'usuarios', 'uid-coach-deny'), {
      especialidad: 'Futbol',
    }),
  );
});

test('administrador NO puede cambiar su propio rol', async () => {
  await assertFails(
    updateDoc(doc(admin(), 'usuarios', 'uid-admin'), {
      rol: 'estudiante',
    }),
  );
});
