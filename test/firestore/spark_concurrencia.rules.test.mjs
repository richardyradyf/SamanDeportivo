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


// H4 Mariana: concurrencia y limites de seguridad de reservas.

async function prepararConcurrenciaReservasH4() {
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();

    await Promise.all([
      setDoc(doc(db, 'usuarios', 'res-est-1'), {
        rol: 'estudiante',
        nombre: 'Estudiante Uno',
        cedula: '28000001',
        carnet: '20260001',
        correo: 'uno@correo.unimet.edu.ve',
        estado: 'activo',
        telefono: '+584121234567',
      }),
      setDoc(doc(db, 'usuarios', 'res-est-2'), {
        rol: 'estudiante',
        nombre: 'Estudiante Dos',
        cedula: '28000002',
        carnet: '20260002',
        correo: 'dos@correo.unimet.edu.ve',
        estado: 'activo',
        telefono: '+584149876543',
      }),
      setDoc(doc(db, 'espacios', 'cancha-h4'), {
        nombre: 'Cancha de pruebas',
        tipo: 'Tenis',
        descripcion: '',
        activo: true,
        creadoEn: new Date(),
        actualizadoEn: new Date(),
      }),
    ]);
  });
}

function estudianteReservaH4(uid) {
  return env.authenticatedContext(uid, {
    email: uid === 'res-est-1'
      ? 'uno@correo.unimet.edu.ve'
      : 'dos@correo.unimet.edu.ve',
  }).firestore();
}

function loteReservaConcurrenteH4(db, uid, id, version, inicio, fin) {
  const lote = writeBatch(db);

  lote.set(doc(db, 'reservasEspacios', id), {
    espacioId: 'cancha-h4',
    usuarioUid: uid,
    rol: 'estudiante',
    inicio,
    fin,
    motivo: 'Practica deportiva',
    estado: 'activa',
    creadoEn: serverTimestamp(),
    actualizadoEn: null,
  });

  lote.set(doc(db, 'ocupacionesEspacios', id), {
    espacioId: 'cancha-h4',
    inicio,
    fin,
  });

  lote.set(doc(db, 'control', 'agenda'), {
    version,
    reservaId: id,
    accion: 'crear',
    actualizadoEn: serverTimestamp(),
  });

  return lote;
}

test('H4-CONC-01: dos estudiantes con la misma version no reservan ambos', async () => {
  await prepararConcurrenciaReservasH4();

  const a = estudianteReservaH4('res-est-1');
  const b = estudianteReservaH4('res-est-2');

  const inicio = new Date(Date.now() + 48 * 60 * 60 * 1000);
  const fin = new Date(inicio.getTime() + 2 * 60 * 60 * 1000);

  const resultados = await Promise.allSettled([
    loteReservaConcurrenteH4(
      a, 'res-est-1', 'reserva-a', 1, inicio, fin
    ).commit(),
    loteReservaConcurrenteH4(
      b, 'res-est-2', 'reserva-b', 1, inicio, fin
    ).commit(),
  ]);

  assert.equal(
    resultados.filter(r => r.status === 'fulfilled').length,
    1
  );

  assert.equal(
    resultados.filter(r => r.status === 'rejected').length,
    1
  );

  const rechazo = resultados.find(r => r.status === 'rejected');
  assert.equal(rechazo.reason.code, 'permission-denied');

  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();

    const reservas = await Promise.all([
      getDoc(doc(db, 'reservasEspacios', 'reserva-a')),
      getDoc(doc(db, 'reservasEspacios', 'reserva-b')),
    ]);

    const ocupaciones = await Promise.all([
      getDoc(doc(db, 'ocupacionesEspacios', 'reserva-a')),
      getDoc(doc(db, 'ocupacionesEspacios', 'reserva-b')),
    ]);

    assert.equal(reservas.filter(d => d.exists()).length, 1);
    assert.equal(ocupaciones.filter(d => d.exists()).length, 1);

    const control = await getDoc(doc(db, 'control', 'agenda'));
    assert.equal(control.data().version, 1);

    const reservaGanadora = reservas.find(d => d.exists());
    const ocupacionGanadora = ocupaciones.find(d => d.exists());

    assert.equal(reservaGanadora.id, ocupacionGanadora.id);
    assert.equal(control.data().reservaId, reservaGanadora.id);
  });
});

test('H4-CONC-02: una reserva no puede reutilizar una version anterior', async () => {
  await prepararConcurrenciaReservasH4();

  const a = estudianteReservaH4('res-est-1');
  const b = estudianteReservaH4('res-est-2');

  const inicio = new Date(Date.now() + 48 * 60 * 60 * 1000);
  const fin = new Date(inicio.getTime() + 60 * 60 * 1000);

  await assertSucceeds(
    loteReservaConcurrenteH4(
      a, 'res-est-1', 'reserva-a', 1, inicio, fin
    ).commit()
  );

  await assertFails(
    loteReservaConcurrenteH4(
      b, 'res-est-2', 'reserva-b', 1, inicio, fin
    ).commit()
  );

  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();

    assert.equal(
      (await getDoc(doc(db, 'reservasEspacios', 'reserva-b'))).exists(),
      false
    );

    assert.equal(
      (await getDoc(doc(db, 'ocupacionesEspacios', 'reserva-b'))).exists(),
      false
    );

    assert.equal(
      (await getDoc(doc(db, 'control', 'agenda'))).data().version,
      1
    );
  });
});

// Esta prueba caracteriza una limitacion, no certifica seguridad.
test('H4-LIM-01: cliente modificado puede crear un solape con version nueva', async () => {
  await prepararConcurrenciaReservasH4();

  const a = estudianteReservaH4('res-est-1');
  const b = estudianteReservaH4('res-est-2');

  const inicio = new Date(Date.now() + 48 * 60 * 60 * 1000);
  const fin = new Date(inicio.getTime() + 60 * 60 * 1000);

  await assertSucceeds(
    loteReservaConcurrenteH4(
      a, 'res-est-1', 'reserva-a', 1, inicio, fin
    ).commit()
  );

  await assertSucceeds(
    loteReservaConcurrenteH4(
      b, 'res-est-2', 'reserva-b', 2, inicio, fin
    ).commit()
  );

  const ocupacionA = await getDoc(
    doc(a, 'ocupacionesEspacios', 'reserva-a')
  );

  const ocupacionB = await getDoc(
    doc(b, 'ocupacionesEspacios', 'reserva-b')
  );

  assert.equal(ocupacionA.exists(), true);
  assert.equal(ocupacionB.exists(), true);

  assert.equal(
    ocupacionA.data().inicio.toMillis(),
    ocupacionB.data().inicio.toMillis()
  );

  assert.equal(
    ocupacionA.data().fin.toMillis(),
    ocupacionB.data().fin.toMillis()
  );
});


// H4 Mariana: seguridad y consistencia de cancelaciones.

async function prepararCancelacionH4() {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const id = 'reserva-cancelacion';
  const inicio = new Date(Date.now() + 48 * 60 * 60 * 1000);
  const fin = new Date(inicio.getTime() + 60 * 60 * 1000);

  await assertSucceeds(
    loteReservaConcurrenteH4(
      db, 'res-est-1', id, 1, inicio, fin
    ).commit()
  );

  return { db, id, inicio, fin };
}

function loteCancelacionH4(db, id, version, liberar = true) {
  const lote = writeBatch(db);

  lote.update(doc(db, 'reservasEspacios', id), {
    estado: 'cancelada',
    actualizadoEn: serverTimestamp(),
  });

  if (liberar) {
    lote.delete(doc(db, 'ocupacionesEspacios', id));
  }

  lote.set(doc(db, 'control', 'agenda'), {
    version,
    reservaId: id,
    accion: 'cancelar',
    actualizadoEn: serverTimestamp(),
  });

  return lote;
}

async function verificarReservaActivaH4(db, id) {
  const privada = await getDoc(doc(db, 'reservasEspacios', id));
  const publica = await getDoc(doc(db, 'ocupacionesEspacios', id));
  const control = await getDoc(doc(db, 'control', 'agenda'));

  assert.equal(privada.exists(), true);
  assert.equal(privada.data().estado, 'activa');
  assert.equal(publica.exists(), true);
  assert.equal(control.data().version, 1);
}

test('H4-CAN-01: otro estudiante no puede cancelar una reserva ajena', async () => {
  const { db, id } = await prepararCancelacionH4();
  const otro = estudianteReservaH4('res-est-2');

  await assertFails(
    loteCancelacionH4(otro, id, 2).commit()
  );

  await verificarReservaActivaH4(db, id);
});

test('H4-CAN-02: administrador puede leer pero no cancelar reserva ajena', async () => {
  const { db, id } = await prepararCancelacionH4();
  const admin = dbAdmin('admin-1');

  const lectura = await assertSucceeds(
    getDoc(doc(admin, 'reservasEspacios', id))
  );

  assert.equal(lectura.exists(), true);

  await assertFails(
    loteCancelacionH4(admin, id, 2).commit()
  );

  await verificarReservaActivaH4(db, id);
});

test('H4-CAN-03: propietario no puede cancelar sin liberar ocupacion', async () => {
  const { db, id } = await prepararCancelacionH4();

  await assertFails(
    loteCancelacionH4(db, id, 2, false).commit()
  );

  await verificarReservaActivaH4(db, id);
});

test('H4-CAN-04: propietario no puede eliminar su registro privado', async () => {
  const { db, id } = await prepararCancelacionH4();

  const lote = writeBatch(db);
  lote.delete(doc(db, 'reservasEspacios', id));

  await assertFails(lote.commit());

  await verificarReservaActivaH4(db, id);
});

test('H4-CAN-05: cancelar conserva los datos originales de la reserva', async () => {
  const { db, id } = await prepararCancelacionH4();

  const antes = (
    await getDoc(doc(db, 'reservasEspacios', id))
  ).data();

  await assertSucceeds(
    loteCancelacionH4(db, id, 2).commit()
  );

  const despues = (
    await getDoc(doc(db, 'reservasEspacios', id))
  ).data();

  assert.equal(despues.estado, 'cancelada');
  assert.ok(despues.actualizadoEn);

  for (const campo of Object.keys(antes)) {
    if (campo !== 'estado' && campo !== 'actualizadoEn') {
      assert.deepEqual(despues[campo], antes[campo]);
    }
  }

  const publica = await getDoc(
    doc(db, 'ocupacionesEspacios', id)
  );

  assert.equal(publica.exists(), false);

  const control = (
    await getDoc(doc(db, 'control', 'agenda'))
  ).data();

  assert.equal(control.version, 2);
  assert.equal(control.accion, 'cancelar');
  assert.equal(control.reservaId, id);
});

test('H4-CAN-06: otro usuario puede reservar el horario liberado', async () => {
  const { db, id, inicio, fin } = await prepararCancelacionH4();

  await assertSucceeds(
    loteCancelacionH4(db, id, 2).commit()
  );

  const otro = estudianteReservaH4('res-est-2');

  await assertSucceeds(
    loteReservaConcurrenteH4(
      otro, 'res-est-2', 'reserva-nueva', 3, inicio, fin
    ).commit()
  );

  const original = await getDoc(
    doc(db, 'reservasEspacios', id)
  );

  const nueva = await getDoc(
    doc(otro, 'reservasEspacios', 'reserva-nueva')
  );

  assert.equal(original.data().estado, 'cancelada');
  assert.equal(nueva.data().estado, 'activa');

  assert.equal(
    (await getDoc(doc(db, 'ocupacionesEspacios', id))).exists(),
    false
  );

  assert.equal(
    (await getDoc(doc(otro, 'ocupacionesEspacios', 'reserva-nueva'))).exists(),
    true
  );

  assert.equal(
    (await getDoc(doc(otro, 'control', 'agenda'))).data().version,
    3
  );
});


// H4 Mariana: conflictos entre clases y reservas.

function horarioConflictoH4() {
  const inicio = new Date(Date.now() + 48 * 60 * 60 * 1000);
  inicio.setUTCHours(20, 0, 0, 0);

  const fin = new Date(inicio.getTime() + 60 * 60 * 1000);

  const dias = [
    'domingo', 'lunes', 'martes', 'miercoles',
    'jueves', 'viernes', 'sabado'
  ];

  const horario = {
    dia: dias[inicio.getUTCDay()],
    horaInicio: '16:00',
    horaFin: '18:00',
    lugar: 'Cancha de pruebas',
    espacioId: 'cancha-h4',
  };

  return { inicio, fin, horario };
}

test('H4-AGE-01: clase y reserva simultaneas no confirman ambas', async () => {
  await prepararConcurrenciaReservasH4();

  const admin = dbAdmin('admin-1');
  const estudiante = estudianteReservaH4('res-est-1');
  const { inicio, fin, horario } = horarioConflictoH4();

  const resultados = await Promise.allSettled([
    loteAgenda(
      admin, 'FUT-01', horario, 1, 'admin-1'
    ).commit(),

    loteReservaConcurrenteH4(
      estudiante, 'res-est-1', 'reserva-clase',
      1, inicio, fin
    ).commit(),
  ]);

  assert.equal(
    resultados.filter(r => r.status === 'fulfilled').length,
    1
  );

  assert.equal(
    resultados.filter(r => r.status === 'rejected').length,
    1
  );

  assert.equal(
    resultados.find(r => r.status === 'rejected').reason.code,
    'permission-denied'
  );

  const control = await getDoc(doc(admin, 'control', 'agenda'));
  assert.equal(control.data().version, 1);

  const clase = await getDoc(doc(admin, 'deportes', 'FUT-01'));

  let reserva;

  await env.withSecurityRulesDisabled(async ctx => {
    reserva = await getDoc(
      doc(ctx.firestore(), 'reservasEspacios', 'reserva-clase')
    );
  });

  const ocupacion = await getDoc(
    doc(estudiante, 'ocupacionesEspacios', 'reserva-clase')
  );

  assert.equal(
    Number(clase.data().horarios.length > 0) +
    Number(reserva.exists()),
    1
  );

  assert.equal(reserva.exists(), ocupacion.exists());
});

test('H4-AGE-02: reserva no usa version anterior a cambio de agenda', async () => {
  await prepararConcurrenciaReservasH4();

  const admin = dbAdmin('admin-1');
  const estudiante = estudianteReservaH4('res-est-1');
  const { inicio, fin, horario } = horarioConflictoH4();

  await assertSucceeds(
    loteAgenda(
      admin, 'FUT-01', horario, 1, 'admin-1'
    ).commit()
  );

  await assertFails(
    loteReservaConcurrenteH4(
      estudiante, 'res-est-1', 'reserva-rezagada',
      1, inicio, fin
    ).commit()
  );

  assert.equal(
    (await getDoc(
      doc(estudiante, 'ocupacionesEspacios', 'reserva-rezagada')
    )).exists(),
    false
  );

  assert.equal(
    (await getDoc(doc(admin, 'control', 'agenda'))).data().version,
    1
  );
});

// Pruebas de caracterizacion de limitaciones.
// No constituyen una certificacion de seguridad.

test('H4-LIM-02: escritura directa puede reservar sobre clase existente', async () => {
  await prepararConcurrenciaReservasH4();

  const admin = dbAdmin('admin-1');
  const estudiante = estudianteReservaH4('res-est-1');
  const { inicio, fin, horario } = horarioConflictoH4();

  await assertSucceeds(
    loteAgenda(
      admin, 'FUT-01', horario, 1, 'admin-1'
    ).commit()
  );

  await assertSucceeds(
    loteReservaConcurrenteH4(
      estudiante, 'res-est-1', 'reserva-solapada',
      2, inicio, fin
    ).commit()
  );

  const clase = await getDoc(doc(admin, 'deportes', 'FUT-01'));

  assert.equal(clase.data().horarios[0].espacioId, 'cancha-h4');

  assert.equal(
    (await getDoc(
      doc(estudiante, 'ocupacionesEspacios', 'reserva-solapada')
    )).exists(),
    true
  );

  assert.equal(
    (await getDoc(doc(admin, 'control', 'agenda'))).data().version,
    2
  );
});

test('H4-LIM-03: escritura directa de agenda puede invadir reserva activa', async () => {
  await prepararConcurrenciaReservasH4();

  const admin = dbAdmin('admin-1');
  const estudiante = estudianteReservaH4('res-est-1');
  const { inicio, fin, horario } = horarioConflictoH4();

  await assertSucceeds(
    loteReservaConcurrenteH4(
      estudiante, 'res-est-1', 'reserva-previa',
      1, inicio, fin
    ).commit()
  );

  await assertSucceeds(
    loteAgenda(
      admin, 'FUT-01', horario, 2, 'admin-1'
    ).commit()
  );

  const clase = await getDoc(doc(admin, 'deportes', 'FUT-01'));

  const reserva = await getDoc(
    doc(estudiante, 'reservasEspacios', 'reserva-previa')
  );

  assert.equal(clase.data().horarios[0].espacioId, 'cancha-h4');
  assert.equal(reserva.data().estado, 'activa');

  assert.equal(
    (await getDoc(doc(admin, 'control', 'agenda'))).data().version,
    2
  );
});


// H4 Mariana: restricciones por rol y disponibilidad.

function loteReservaRolH4(
  db, uid, rol, id, inicio, fin, version = 1
) {
  const lote = writeBatch(db);

  lote.set(doc(db, 'reservasEspacios', id), {
    espacioId: 'cancha-h4',
    usuarioUid: uid,
    rol,
    inicio,
    fin,
    motivo: 'Practica deportiva',
    estado: 'activa',
    creadoEn: serverTimestamp(),
    actualizadoEn: null,
  });

  lote.set(doc(db, 'ocupacionesEspacios', id), {
    espacioId: 'cancha-h4',
    inicio,
    fin,
  });

  lote.set(doc(db, 'control', 'agenda'), {
    version,
    reservaId: id,
    accion: 'crear',
    actualizadoEn: serverTimestamp(),
  });

  return lote;
}

function fechaReservaRolH4(dias, horas) {
  const inicio = new Date(
    Date.now() + dias * 24 * 60 * 60 * 1000
  );

  const fin = new Date(
    inicio.getTime() + horas * 60 * 60 * 1000
  );

  return { inicio, fin };
}

test('H4-ROL-01: estudiante puede reservar exactamente dos horas', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 2);

  await assertSucceeds(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-01', inicio, fin
    ).commit()
  );
});

test('H4-ROL-02: estudiante no puede superar dos horas', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 2.01);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-02', inicio, fin
    ).commit()
  );
});

test('H4-ROL-03: estudiante no puede superar 21 dias', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(22, 1);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-03', inicio, fin
    ).commit()
  );
});

test('H4-ROL-04: entrenador puede reservar tres horas', async () => {
  await prepararConcurrenciaReservasH4();

  const db = env.authenticatedContext('coach-1', {
    email: 'coach1@unimet.edu.ve',
  }).firestore();

  const { inicio, fin } = fechaReservaRolH4(2, 3);

  await assertSucceeds(
    loteReservaRolH4(
      db, 'coach-1', 'entrenador',
      'rol-04', inicio, fin
    ).commit()
  );
});

test('H4-ROL-05: administrador puede reservar despues de 21 dias', async () => {
  await prepararConcurrenciaReservasH4();

  const db = dbAdmin('admin-1');
  const { inicio, fin } = fechaReservaRolH4(30, 3);

  await assertSucceeds(
    loteReservaRolH4(
      db, 'admin-1', 'administrador',
      'rol-05', inicio, fin
    ).commit()
  );
});

test('H4-ROL-06: estudiante no puede falsificar su rol', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 1);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'administrador',
      'rol-06', inicio, fin
    ).commit()
  );
});

test('H4-ROL-07: no se permiten reservas en el pasado', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(-2, 1);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-07', inicio, fin
    ).commit()
  );
});

test('H4-ROL-08: fin debe ser posterior al inicio', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 0);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-08', inicio, fin
    ).commit()
  );
});

test('H4-ROL-09: no se puede reservar un espacio inactivo', async () => {
  await prepararConcurrenciaReservasH4();

  await env.withSecurityRulesDisabled(async ctx => {
    await updateDoc(
      doc(ctx.firestore(), 'espacios', 'cancha-h4'),
      { activo: false }
    );
  });

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 1);

  await assertFails(
    loteReservaRolH4(
      db, 'res-est-1', 'estudiante',
      'rol-09', inicio, fin
    ).commit()
  );
});


// H4 Mariana: privacidad y proteccion de documentos.

test('H4-SEG-01: visitante no puede leer reserva privada', async () => {
  const { id } = await prepararCancelacionH4();
  const anon = env.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(anon, 'reservasEspacios', id))
  );
});

test('H4-SEG-02: visitante puede consultar disponibilidad publica', async () => {
  const { id } = await prepararCancelacionH4();
  const anon = env.unauthenticatedContext().firestore();

  const ocupacion = await assertSucceeds(
    getDoc(doc(anon, 'ocupacionesEspacios', id))
  );

  assert.equal(ocupacion.exists(), true);

  assert.deepEqual(
    Object.keys(ocupacion.data()).sort(),
    ['espacioId', 'fin', 'inicio']
  );
});

test('H4-SEG-03: entrenador no puede leer reserva privada ajena', async () => {
  const { id } = await prepararCancelacionH4();

  const coach = env.authenticatedContext('coach-1', {
    email: 'coach1@unimet.edu.ve',
  }).firestore();

  await assertFails(
    getDoc(doc(coach, 'reservasEspacios', id))
  );
});

test('H4-SEG-04: propietario no puede modificar ocupacion directamente', async () => {
  const { db, id, fin } = await prepararCancelacionH4();

  await assertFails(
    updateDoc(doc(db, 'ocupacionesEspacios', id), {
      fin: new Date(fin.getTime() + 3600000),
    })
  );

  await verificarReservaActivaH4(db, id);
});

test('H4-SEG-05: propietario no puede publicar datos personales', async () => {
  const { db, id } = await prepararCancelacionH4();

  await assertFails(
    updateDoc(doc(db, 'ocupacionesEspacios', id), {
      usuarioUid: 'res-est-1',
      telefono: '+584121234567',
      motivo: 'Informacion privada',
    })
  );

  const publica = await getDoc(
    doc(db, 'ocupacionesEspacios', id)
  );

  assert.deepEqual(
    Object.keys(publica.data()).sort(),
    ['espacioId', 'fin', 'inicio']
  );
});

test('H4-SEG-06: estudiante no puede avanzar control sin operacion real', async () => {
  const { db, id } = await prepararCancelacionH4();

  await assertFails(
    setDoc(doc(db, 'control', 'agenda'), {
      version: 2,
      reservaId: id,
      accion: 'crear',
      actualizadoEn: serverTimestamp(),
    })
  );

  await verificarReservaActivaH4(db, id);
});

test('H4-SEG-07: reserva y ocupacion no se crean sin control de agenda', async () => {
  await prepararConcurrenciaReservasH4();

  const db = estudianteReservaH4('res-est-1');
  const { inicio, fin } = fechaReservaRolH4(2, 1);
  const id = 'reserva-sin-control';

  const lote = writeBatch(db);

  lote.set(doc(db, 'reservasEspacios', id), {
    espacioId: 'cancha-h4',
    usuarioUid: 'res-est-1',
    rol: 'estudiante',
    inicio,
    fin,
    motivo: 'Practica deportiva',
    estado: 'activa',
    creadoEn: serverTimestamp(),
    actualizadoEn: null,
  });

  lote.set(doc(db, 'ocupacionesEspacios', id), {
    espacioId: 'cancha-h4',
    inicio,
    fin,
  });

  await assertFails(lote.commit());

  await env.withSecurityRulesDisabled(async ctx => {
    const adminDb = ctx.firestore();

    for (const coleccion of [
      'reservasEspacios', 'ocupacionesEspacios'
    ]) {
      const documento = await getDoc(
        doc(adminDb, coleccion, id)
      );

      assert.equal(documento.exists(), false);
    }

    const control = await getDoc(
      doc(adminDb, 'control', 'agenda')
    );

    assert.equal(control.exists(), false);
  });
});

test('H4-SEG-08: usuario no puede eliminar control de agenda', async () => {
  const { db, id } = await prepararCancelacionH4();

  const lote = writeBatch(db);
  lote.delete(doc(db, 'control', 'agenda'));

  await assertFails(lote.commit());

  await verificarReservaActivaH4(db, id);
});

test('H4-SEG-09: propietario no puede modificar motivo de reserva activa', async () => {
  const { db, id } = await prepararCancelacionH4();

  const referencia = doc(db, 'reservasEspacios', id);
  const antes = (await getDoc(referencia)).data();

  await assertFails(
    updateDoc(referencia, {
      motivo: 'Motivo modificado',
    })
  );

  const despues = (await getDoc(referencia)).data();

  assert.deepEqual(despues, antes);
});


// H4: cancelaciones permitidas solamente antes del inicio.

async function prepararReservaTemporalH4(
  uid,
  rol,
  minutosInicio,
  minutosFin
) {
  await prepararConcurrenciaReservasH4();

  const id = 'reserva-temporal-h4';
  const ahora = Date.now();
  const inicio = new Date(ahora + minutosInicio * 60000);
  const fin = new Date(ahora + minutosFin * 60000);

  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const lote = writeBatch(db);

    lote.set(doc(db, 'reservasEspacios', id), {
      espacioId: 'cancha-h4',
      usuarioUid: uid,
      rol,
      inicio,
      fin,
      motivo: 'Prueba cancelacion temporal H4',
      estado: 'activa',
      creadoEn: new Date(ahora - 86400000),
      actualizadoEn: null,
    });

    lote.set(doc(db, 'ocupacionesEspacios', id), {
      espacioId: 'cancha-h4',
      inicio,
      fin,
    });

    lote.set(doc(db, 'control', 'agenda'), {
      version: 1,
      reservaId: id,
      accion: 'crear',
      actualizadoEn: serverTimestamp(),
    });

    await lote.commit();
  });

  const db = env.authenticatedContext(uid).firestore();

  return { db, id };
}

async function verificarCancelacionDenegadaH4(db, id) {
  const referencias = [
    doc(db, 'reservasEspacios', id),
    doc(db, 'ocupacionesEspacios', id),
    doc(db, 'control', 'agenda'),
  ];

  const antes = await Promise.all(
    referencias.map((ref) => getDoc(ref))
  );

  await assertFails(
    loteCancelacionH4(db, id, 2).commit()
  );

  const despues = await Promise.all(
    referencias.map((ref) => getDoc(ref))
  );

  for (let i = 0; i < referencias.length; i++) {
    assert.equal(despues[i].exists(), true);
    assert.deepEqual(despues[i].data(), antes[i].data());
  }

  await verificarReservaActivaH4(db, id);
}

test('H4-TEMP-01: propietario cancela antes del inicio', async () => {
  const { db, id } = await prepararReservaTemporalH4(
    'res-est-1', 'estudiante', 60, 120
  );

  await assertSucceeds(
    loteCancelacionH4(db, id, 2).commit()
  );

  const privada = await getDoc(doc(db, 'reservasEspacios', id));
  const publica = await getDoc(doc(db, 'ocupacionesEspacios', id));
  const control = await getDoc(doc(db, 'control', 'agenda'));

  assert.equal(privada.data().estado, 'cancelada');
  assert.equal(publica.exists(), false);
  assert.equal(control.data().version, 2);
});

test('H4-TEMP-02: estudiante no cancela reserva en curso', async () => {
  const { db, id } = await prepararReservaTemporalH4(
    'res-est-1', 'estudiante', -30, 30
  );

  await verificarCancelacionDenegadaH4(db, id);
});

test('H4-TEMP-03: estudiante no cancela reserva finalizada', async () => {
  const { db, id } = await prepararReservaTemporalH4(
    'res-est-1', 'estudiante', -120, -60
  );

  await verificarCancelacionDenegadaH4(db, id);
});

test('H4-TEMP-04: administrador no cancela reserva propia iniciada', async () => {
  const { db, id } = await prepararReservaTemporalH4(
    'admin-1', 'administrador', -30, 30
  );

  await verificarCancelacionDenegadaH4(db, id);
});

test('H4-TEMP-05: entrenador no cancela reserva propia iniciada', async () => {
  const { db, id } = await prepararReservaTemporalH4(
    'coach-1', 'entrenador', -30, 30
  );

  await verificarCancelacionDenegadaH4(db, id);
});
