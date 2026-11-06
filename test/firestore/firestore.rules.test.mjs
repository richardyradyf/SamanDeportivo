import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';

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

const nuevoRegistro = (estado = 'activo') => ({
  cedula: '12345678',
  nombre: 'Estudiante Registro',
  correo: 'registro@unimet.edu.ve',
  rol: 'estudiante',
  carnet: '202644444',
  estado,
});

test('estudiante puede registrarse activo con los 6 campos acordados', async () => {
  const uid = 'uid-registro-valido';
  const db = env.authenticatedContext(uid, {
    email: 'registro@unimet.edu.ve',
  }).firestore();

  await assertSucceeds(
    setDoc(doc(db, 'usuarios', uid), nuevoRegistro()),
  );
});

test('estudiante NO puede registrarse como inactivo', async () => {
  const uid = 'uid-registro-inactivo';
  const db = env.authenticatedContext(uid, {
    email: 'registro@unimet.edu.ve',
  }).firestore();

  await assertFails(
    setDoc(doc(db, 'usuarios', uid), nuevoRegistro('inactivo')),
  );
});

test('registro con 9 campos adicionales debe rechazarse', async () => {
  const uid = 'uid-registro-nueve-campos';
  const db = env.authenticatedContext(uid, {
    email: 'registro@unimet.edu.ve',
  }).firestore();

  await assertFails(
    setDoc(doc(db, 'usuarios', uid), {
      ...nuevoRegistro(),
      uid,
      especialidad: null,
      aniosExperiencia: null,
    }),
  );
});

test('administrador puede listar usuarios', async () => {
  await assertSucceeds(
    getDocs(collection(admin(), 'usuarios')),
  );
});

test('estudiante NO puede listar usuarios', async () => {
  await assertFails(
    getDocs(collection(estudiante(), 'usuarios')),
  );
});

// A1 HITO 3 - PRUEBAS DE DEPORTES (Alexander)
const nuevoDeporteA1 = (codigo) => ({
  codigo, nombre: 'Fútbol sala', descripcion: 'Entrenamiento',
  disciplina: 'colectivo', costo: 10, imagenUrl: null,
  cupoMaximo: 20, cuposOcupados: 0, cuposConfirmados: 0,
  entrenadorUid: null, entrenadorNombre: null, entrenadorEspecialidad: null,
  horarios: [], dias: [], activo: true,
  promedioCalificacion: 0, totalResenas: 0,
  creadoEn: new Date('2026-11-05T10:00:00Z'), actualizadoEn: null,
});

async function sembrarDeporteA1(codigo, modificaciones = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'deportes', codigo), {
      ...nuevoDeporteA1(codigo), ...modificaciones,
    });
  });
}

test('A1: administrador crea un deporte válido', async () => {
  await assertSucceeds(setDoc(
    doc(admin(), 'deportes', 'FUT-91'), nuevoDeporteA1('FUT-91'),
  ));
});

test('A1: estudiante no crea deportes', async () => {
  await assertFails(setDoc(
    doc(estudiante(), 'deportes', 'FUT-92'), nuevoDeporteA1('FUT-92'),
  ));
});

test('A1: un visitante puede leer el catálogo', async () => {
  await sembrarDeporteA1('FUT-93');
  await assertSucceeds(getDocs(collection(env.unauthenticatedContext().firestore(), 'deportes')));
});

test('A1: administrador edita nombre y cupo máximo', async () => {
  await sembrarDeporteA1('FUT-94');
  await assertSucceeds(updateDoc(doc(admin(), 'deportes', 'FUT-94'), {
    nombre: 'Fútbol universitario', cupoMaximo: 25, actualizadoEn: new Date(),
  }));
});

test('A1: estudiante no edita deportes', async () => {
  await sembrarDeporteA1('FUT-95');
  await assertFails(updateDoc(doc(estudiante(), 'deportes', 'FUT-95'), {
    nombre: 'Cambio no autorizado', actualizadoEn: new Date(),
  }));
});

test('A1: administrador no altera directamente contadores de cupos', async () => {
  await sembrarDeporteA1('FUT-96');
  await assertFails(updateDoc(doc(admin(), 'deportes', 'FUT-96'), {
    cuposOcupados: 5, actualizadoEn: new Date(),
  }));
});

test('A1: administrador no reduce cupo bajo ocupación existente', async () => {
  await sembrarDeporteA1('FUT-97', { cuposOcupados: 7, cuposConfirmados: 4 });
  await assertFails(updateDoc(doc(admin(), 'deportes', 'FUT-97'), {
    cupoMaximo: 6, actualizadoEn: new Date(),
  }));
});

test('A1: administrador no crea deporte con contador precargado', async () => {
  await assertFails(setDoc(doc(admin(), 'deportes', 'FUT-98'), {
    ...nuevoDeporteA1('FUT-98'), cuposOcupados: 1,
  }));
});

test('A1: ni siquiera el administrador puede falsificar el código del documento', async () => {
  await assertFails(setDoc(doc(admin(), 'deportes', 'FUT-99'), {
    ...nuevoDeporteA1('FUT-99'), codigo: 'FUT-01',
  }));
});
