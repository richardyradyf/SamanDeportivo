import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, query, where } from 'firebase/firestore';

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

// A2.3: toda modificación de entrenador y agenda pasa por Cloud Functions.
test('A2.3: administrador no puede cambiar entrenador directamente', async () => {
  await sembrarDeporteA1('FUT-81');
  await assertFails(updateDoc(doc(admin(), 'deportes', 'FUT-81'), {
    entrenadorUid: 'coach-1', entrenadorNombre:'Coach', actualizadoEn:new Date(),
  }));
});
test('A2.3: administrador no puede modificar horarios directamente', async () => {
  await sembrarDeporteA1('FUT-82');
  await assertFails(updateDoc(doc(admin(), 'deportes', 'FUT-82'), {
    horarios:[{dia:'lunes',horaInicio:'16:00',horaFin:'18:00',lugar:'Cancha A'}],
    dias:['lunes'], actualizadoEn:new Date(),
  }));
});
test('A2.3: administrador no puede crear deporte con agenda precargada', async () => {
  await assertFails(setDoc(doc(admin(), 'deportes', 'FUT-83'), {
    ...nuevoDeporteA1('FUT-83'), entrenadorUid:'ent-1',
  }));
});

// A3.2: PRUEBAS DE MODERACIÓN Y ESTADO DE ESTUDIANTES
// Integrar con el test existente: usa env, admin(), estudiante() y sembrarDeporteA1().

async function sembrarResenaA3(codigo = 'FUT-81') {
  await sembrarDeporteA1(codigo);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'deportes', codigo, 'resenas', 'uid-a'), {
      estudianteNombre: 'Estudiante Uno', puntuacion: 5,
      comentario: 'Buen entrenamiento', oculta: false,
      fecha: new Date('2026-11-06T12:00:00Z'),
    });
  });
}

test('A3.2: administrador puede desactivar estudiante', async () => {
  await assertSucceeds(updateDoc(doc(admin(), 'usuarios', 'uid-b'), { estado: 'inactivo' }));
});

test('A3.2: administrador puede reactivar estudiante', async () => {
  await assertSucceeds(updateDoc(doc(admin(), 'usuarios', 'uid-b'), { estado: 'activo' }));
});

test('A3.2: estudiante no puede cambiar su propio estado', async () => {
  await assertFails(updateDoc(doc(estudiante(), 'usuarios', 'uid-a'), { estado: 'inactivo' }));
});

test('A3.2: administrador no puede cambiar rol junto con estado', async () => {
  await assertFails(updateDoc(doc(admin(), 'usuarios', 'uid-b'), {
    estado: 'inactivo', rol: 'administrador',
  }));
});

test('A3.2: administrador no puede cambiar estado de entrenadores', async () => {
  await prepararEntrenador('uid-coach-a3');
  await assertFails(updateDoc(doc(admin(), 'usuarios', 'uid-coach-a3'), {
    estado: 'inactivo',
  }));
});

test('A3.2: administrador no puede poner un estado inválido', async () => {
  await assertFails(updateDoc(doc(admin(), 'usuarios', 'uid-b'), { estado: 'suspendido' }));
});

test('A3.2: administrador puede consultar reseñas de un deporte', async () => {
  await sembrarResenaA3('FUT-81');
  await assertSucceeds(getDocs(collection(admin(), 'deportes', 'FUT-81', 'resenas')));
});

test('A3.2: estudiante no puede consultar reseñas administrativas', async () => {
  await assertFails(getDocs(collection(estudiante(), 'deportes', 'FUT-81', 'resenas')));
});

test('A3.2: administrador puede ocultar y volver a mostrar una reseña', async () => {
  await assertSucceeds(updateDoc(doc(admin(), 'deportes', 'FUT-81', 'resenas', 'uid-a'), { oculta: true }));
  await assertSucceeds(updateDoc(doc(admin(), 'deportes', 'FUT-81', 'resenas', 'uid-a'), { oculta: false }));
});

test('A3.2: administrador no puede alterar puntuación ni comentario', async () => {
  await assertFails(updateDoc(doc(admin(), 'deportes', 'FUT-81', 'resenas', 'uid-a'), {
    puntuacion: 1, comentario: 'Editado sin autorización',
  }));
});

test('A3.2: estudiante no puede ocultar reseñas de terceros', async () => {
  await assertFails(updateDoc(doc(estudiante(), 'deportes', 'FUT-81', 'resenas', 'uid-a'), {
    oculta: true,
  }));
});

test('A3.2: administrador no puede crear reseñas', async () => {
  await assertFails(setDoc(doc(admin(), 'deportes', 'FUT-81', 'resenas', 'uid-admin'), {
    estudianteNombre: 'Administradora', puntuacion: 5,
    comentario: 'Reseña fraudulenta', oculta: false, fecha: new Date(),
  }));
});

// A3.5 — PRUEBAS DE LECTURA ADMINISTRATIVA DE FUENTES OPERATIVAS
// Requiere los helpers existentes env, admin(), estudiante() y prepararEntrenador().
// No introduce permisos de escritura para ningún rol.
const fuentesA35 = ['inscripciones', 'pagos', 'busquedas'];

async function sembrarFuenteA35(nombre) {
  const id = `a35_seguridad_${nombre}`;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), nombre, id), {
      origen: 'prueba-reglas-a35',
      fecha: new Date('2026-11-06T15:00:00Z'),
    });
  });
  return id;
}

for (const nombre of fuentesA35) {
  test(`A3.5: administrador puede leer un documento de ${nombre}`, async () => {
    const id = await sembrarFuenteA35(nombre);
    await assertSucceeds(getDoc(doc(admin(), nombre, id)));
  });

  test(`A3.5: administrador puede listar ${nombre}`, async () => {
    await sembrarFuenteA35(nombre);
    await assertSucceeds(getDocs(collection(admin(), nombre)));
  });

  test(`A3.5: estudiante NO puede leer un documento de ${nombre}`, async () => {
    const id = await sembrarFuenteA35(nombre);
    await assertFails(getDoc(doc(estudiante(), nombre, id)));
  });

  test(`A3.5: estudiante NO puede listar ${nombre}`, async () => {
    await assertFails(getDocs(collection(estudiante(), nombre)));
  });

  test(`A3.5: entrenador NO puede listar ${nombre}`, async () => {
    const coach = await prepararEntrenador(`a35-coach-${nombre}`);
    await assertFails(getDocs(collection(coach, nombre)));
  });

  test(`A3.5: visitante NO puede leer ${nombre}`, async () => {
    const id = await sembrarFuenteA35(nombre);
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, nombre, id)));
  });

  test(`A3.5: administrador NO puede crear ${nombre}`, async () => {
    await assertFails(setDoc(doc(admin(), nombre, `a35_creacion_${nombre}`), {
      origen: 'no-autorizado',
    }));
  });

  test(`A3.5: administrador NO puede modificar ${nombre}`, async () => {
    const id = await sembrarFuenteA35(nombre);
    await assertFails(updateDoc(doc(admin(), nombre, id), {
      origen: 'modificado',
    }));
  });

  test(`A3.5: administrador NO puede borrar ${nombre}`, async () => {
    const id = await sembrarFuenteA35(nombre);
    await assertFails(deleteDoc(doc(admin(), nombre, id)));
  });
}

// A3.6: PRUEBAS DE RESEÑAS VISIBLES Y BÚSQUEDAS DEL CATÁLOGO
// Reutiliza env, admin(), estudiante(), sembrarDeporteA1() de la suite.

async function sembrarRevisionA36(codigo, uid = 'uid-a', oculta = false) {
  await sembrarDeporteA1(codigo);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'deportes', codigo, 'resenas', uid), {
      estudianteNombre: 'Estudiante Uno', puntuacion: 4,
      comentario: 'Clase de prueba', oculta, fecha: new Date(),
    });
  });
}

async function sembrarInscripcionA36(codigo, estado = 'confirmada', uid = 'uid-a') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'inscripciones', `${uid}_${codigo}`), {
      estudianteUid: uid, deporteId: codigo, estado,
    });
  });
}

const revisionA36 = (oculta = false) => ({
  estudianteNombre: 'Estudiante Uno', puntuacion: 5,
  comentario: 'Excelente clase', oculta, fecha: new Date(),
});

const busquedaA36 = (usuarioUid = null) => ({
  termino: 'tenis', filtros: { disciplina: 'raqueta', turno: 'tarde', soloConCupo: true },
  deporteIds: ['TEN-01'], usuarioUid, fecha: new Date(),
});

const anonimoA36 = () => env.unauthenticatedContext().firestore();

test('A3.6: visitante puede leer reseña visible', async () => {
  await sembrarRevisionA36('REV-01');
  await assertSucceeds(getDoc(doc(anonimoA36(), 'deportes', 'REV-01', 'resenas', 'uid-a')));
});

test('A3.6: visitante no puede leer reseña oculta', async () => {
  await sembrarRevisionA36('REV-02', 'uid-a', true);
  await assertFails(getDoc(doc(anonimoA36(), 'deportes', 'REV-02', 'resenas', 'uid-a')));
});

test('A3.6: administrador puede consultar reseña oculta', async () => {
  await sembrarRevisionA36('REV-14', 'uid-a', true);
  await assertSucceeds(getDoc(doc(admin(), 'deportes', 'REV-14', 'resenas', 'uid-a')));
});

test('A3.6: visitante lista solamente reseñas con filtro oculta false', async () => {
  await sembrarRevisionA36('REV-03');
  await assertSucceeds(getDocs(query(
    collection(anonimoA36(), 'deportes', 'REV-03', 'resenas'),
    where('oculta', '==', false),
  )));
});

test('A3.6: visitante no puede listar reseñas sin filtrar', async () => {
  await assertFails(getDocs(collection(anonimoA36(), 'deportes', 'REV-03', 'resenas')));
});

test('A3.6: alumno con inscripción confirmada crea su reseña', async () => {
  await sembrarDeporteA1('REV-04');
  await sembrarInscripcionA36('REV-04');
  await assertSucceeds(setDoc(doc(estudiante(), 'deportes', 'REV-04', 'resenas', 'uid-a'), revisionA36()));
});

test('A3.6: alumno con inscripción pendiente no puede reseñar', async () => {
  await sembrarDeporteA1('REV-05');
  await sembrarInscripcionA36('REV-05', 'pendiente');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-05', 'resenas', 'uid-a'), revisionA36()));
});

test('A3.6: alumno sin inscripción no puede reseñar', async () => {
  await sembrarDeporteA1('REV-06');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-06', 'resenas', 'uid-a'), revisionA36()));
});

test('A3.6: alumno no puede crear reseña en el documento de otro UID', async () => {
  await sembrarDeporteA1('REV-07');
  await sembrarInscripcionA36('REV-07');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-07', 'resenas', 'uid-b'), revisionA36()));
});

test('A3.6: alumno no puede crear reseña ocultada', async () => {
  await sembrarDeporteA1('REV-08');
  await sembrarInscripcionA36('REV-08');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-08', 'resenas', 'uid-a'), revisionA36(true)));
});

test('A3.6: alumno no puede crear reseña con nota inválida', async () => {
  await sembrarDeporteA1('REV-09');
  await sembrarInscripcionA36('REV-09');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-09', 'resenas', 'uid-a'), {
    ...revisionA36(), puntuacion: 6,
  }));
});

test('A3.6: alumno no puede crear comentario excesivo', async () => {
  await sembrarDeporteA1('REV-10');
  await sembrarInscripcionA36('REV-10');
  await assertFails(setDoc(doc(estudiante(), 'deportes', 'REV-10', 'resenas', 'uid-a'), {
    ...revisionA36(), comentario: 'x'.repeat(301),
  }));
});

test('A3.6: alumno confirmado modifica su comentario', async () => {
  await sembrarRevisionA36('REV-11');
  await sembrarInscripcionA36('REV-11');
  await assertSucceeds(updateDoc(doc(estudiante(), 'deportes', 'REV-11', 'resenas', 'uid-a'), {
    comentario: 'Comentario corregido', puntuacion: 3,
  }));
});

test('A3.6: alumno no puede cambiar oculta', async () => {
  await sembrarRevisionA36('REV-12');
  await sembrarInscripcionA36('REV-12');
  await assertFails(updateDoc(doc(estudiante(), 'deportes', 'REV-12', 'resenas', 'uid-a'), { oculta: true }));
});

test('A3.6: ni el estudiante confirmado puede falsificar promedio del deporte', async () => {
  await sembrarDeporteA1('REV-13');
  await sembrarInscripcionA36('REV-13');
  await assertFails(updateDoc(doc(estudiante(), 'deportes', 'REV-13'), {
    promedioCalificacion: 5, totalResenas: 500,
  }));
});

test('A3.6: visitante anónimo puede registrar búsqueda sin UID', async () => {
  await assertSucceeds(setDoc(doc(anonimoA36(), 'busquedas', 'a36-anon'), busquedaA36()));
});

test('A3.6: usuario autenticado puede registrar búsqueda con UID propio', async () => {
  await assertSucceeds(setDoc(doc(estudiante(), 'busquedas', 'a36-owner'), busquedaA36('uid-a')));
});

test('A3.6: usuario autenticado puede registrar búsqueda sin UID', async () => {
  await assertSucceeds(setDoc(doc(estudiante(), 'busquedas', 'a36-authanon'), busquedaA36()));
});

test('A3.6: visitante no puede atribuir una búsqueda a un usuario', async () => {
  await assertFails(setDoc(doc(anonimoA36(), 'busquedas', 'a36-fake-anon'), busquedaA36('uid-a')));
});

test('A3.6: usuario no puede atribuir búsqueda a otro UID', async () => {
  await assertFails(setDoc(doc(estudiante(), 'busquedas', 'a36-fake-owner'), busquedaA36('uid-b')));
});

test('A3.6: búsqueda con fecha demasiado antigua es rechazada', async () => {
  await assertFails(setDoc(doc(anonimoA36(), 'busquedas', 'a36-old'), {
    ...busquedaA36(), fecha: new Date('2020-01-01T00:00:00Z'),
  }));
});

test('A3.6: búsqueda con filtro de tipo incorrecto se rechaza', async () => {
  await assertFails(setDoc(doc(anonimoA36(), 'busquedas', 'a36-filter'), {
    ...busquedaA36(), filtros: { soloConCupo: 'si' },
  }));
});

test('A3.6: búsqueda con lista enorme se rechaza', async () => {
  await assertFails(setDoc(doc(anonimoA36(), 'busquedas', 'a36-big'), {
    ...busquedaA36(), deporteIds: Array.from({ length: 51 }, (_, i) => `DEP-${i}`),
  }));
});

test('A3.6: visitante no puede leer búsquedas', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'busquedas', 'a36-read-deny'), busquedaA36());
  });
  await assertFails(getDoc(doc(anonimoA36(), 'busquedas', 'a36-read-deny')));
});

test('A3.6: estudiante no puede editar búsquedas existentes', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'busquedas', 'a36-update-deny'), busquedaA36('uid-a'));
  });
  await assertFails(updateDoc(doc(estudiante(), 'busquedas', 'a36-update-deny'), { termino: 'otra' }));
});
