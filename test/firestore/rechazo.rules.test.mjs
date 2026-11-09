
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test, before, beforeEach, after } from 'node:test';

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  writeBatch,
  Timestamp,
} from 'firebase/firestore';

const proyecto = 'demo-saman-inscripciones-permitidas';
const uid = 'est-rech-1';
const otroUid = 'est-rech-2';
const codigo = 'TEN-01';
const inscripcionId = `${uid}_${codigo}`;

let entorno;

function estudiante(id = uid) {
  return entorno.authenticatedContext(id).firestore();
}

function datosUsuario(id, estado = 'activo') {
  return {
    cedula: id === uid ? '28000001' : '28000002',
    nombre: id === uid ? 'Ana Perez' : 'Luis Perez',
    carnet: id === uid ? '20231001' : '20231002',
    correo: `${id}@correo.unimet.edu.ve`,
    rol: 'estudiante',
    estado,
  };
}

function datosDeporte() {
  return {
    codigo,
    nombre: 'Tenis',
    descripcion: 'Clases de tenis',
    disciplina: 'raqueta',
    costo: 15,
    imagenUrl: null,
    cupoMaximo: 3,
    cuposOcupados: 1,
    cuposConfirmados: 0,
    entrenadorUid: null,
    entrenadorNombre: null,
    entrenadorEspecialidad: null,
    horarios: [],
    dias: [],
    activo: true,
    promedioCalificacion: 0,
    totalResenas: 0,
    creadoEn: Timestamp.now(),
    actualizadoEn: null,
  };
}

function datosInscripcion() {
  const fecha = Timestamp.fromMillis(
    Date.now() - 60 * 60 * 1000
  );

  return {
    estudianteUid: uid,
    estudianteCedula: '28000001',
    estudianteNombre: 'Ana Perez',
    estudianteCarnet: '20231001',
    estudianteCorreo: 'est-rech-1@correo.unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: 'Tenis',
    entrenadorUid: null,
    estado: 'pendiente',
    motivo: null,
    fechaInscripcion: fecha,
    fechaLimitePago: Timestamp.fromMillis(
      Date.now() + 23 * 60 * 60 * 1000
    ),
    pagoId: null,
    historial: [
      {
        estado: 'pendiente',
        fecha,
        responsableUid: uid,
      },
    ],
  };
}

async function leerInscripcion() {
  let resultado;

  await entorno.withSecurityRulesDisabled(async (contexto) => {
    const documento = await getDoc(
      doc(contexto.firestore(), 'inscripciones', inscripcionId)
    );

    assert.equal(documento.exists(), true);
    resultado = documento.data();
  });

  return resultado;
}

function cambioRechazo(anterior) {
  return {
    estado: 'rechazada',
    motivo: 'estudiante_inactivo',
    historial: [
      ...anterior.historial,
      {
        estado: 'rechazada',
        fecha: Timestamp.now(),
        responsableUid: uid,
      },
    ],
  };
}

async function ejecutarRechazo(
  cambios,
  cuposRestantes = 0,
  actor = uid
) {
  const db = estudiante(actor);
  const lote = writeBatch(db);

  lote.update(
    doc(db, 'inscripciones', inscripcionId),
    cambios
  );

  lote.update(
    doc(db, 'deportes', codigo),
    { cuposOcupados: cuposRestantes }
  );

  return lote.commit();
}

async function verificarEstado(estado, cupos, historial) {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    const inscripcion = (
      await getDoc(doc(db, 'inscripciones', inscripcionId))
    ).data();

    const deporte = (
      await getDoc(doc(db, 'deportes', codigo))
    ).data();

    assert.equal(inscripcion.estado, estado);
    assert.equal(inscripcion.historial.length, historial);
    assert.equal(deporte.cuposOcupados, cupos);
    assert.equal(deporte.cuposConfirmados, 0);
  });
}

before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: proyecto,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await entorno.clearFirestore();

  await entorno.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    await setDoc(
      doc(db, 'usuarios', uid),
      datosUsuario(uid, 'inactivo')
    );

    await setDoc(
      doc(db, 'usuarios', otroUid),
      datosUsuario(otroUid)
    );

    await setDoc(doc(db, 'deportes', codigo), datosDeporte());

    await setDoc(
      doc(db, 'inscripciones', inscripcionId),
      datosInscripcion()
    );
  });
});

after(async () => {
  if (entorno) {
    await entorno.cleanup();
  }
});

// RECH-01: operacion permitida.
test(
  'RECH-01: estudiante inactivo rechaza su reserva y libera cupo',
  async () => {
    const anterior = await leerInscripcion();

    await assertSucceeds(
      ejecutarRechazo(cambioRechazo(anterior))
    );

    await verificarEstado('rechazada', 0, 2);

    const posterior = await leerInscripcion();

    assert.deepEqual(
      posterior.historial[0],
      anterior.historial[0]
    );
  }
);

// RECH-02: estudiante activo.
test(
  'RECH-02: estudiante activo no puede rechazar',
  async () => {
    const anterior = await leerInscripcion();

    await entorno.withSecurityRulesDisabled(async (contexto) => {
      await setDoc(
        doc(contexto.firestore(), 'usuarios', uid),
        datosUsuario(uid, 'activo')
      );
    });

    await assertFails(
      ejecutarRechazo(cambioRechazo(anterior))
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// RECH-03: no libera el cupo.
test(
  'RECH-03: no se puede rechazar sin liberar cupo',
  async () => {
    const anterior = await leerInscripcion();

    await assertFails(
      ejecutarRechazo(cambioRechazo(anterior), 1)
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// RECH-04: historial alterado.
test(
  'RECH-04: no permite borrar el historial',
  async () => {
    const anterior = await leerInscripcion();
    const cambios = cambioRechazo(anterior);

    cambios.historial = [cambios.historial.at(-1)];

    await assertFails(ejecutarRechazo(cambios));

    await verificarEstado('pendiente', 1, 1);
  }
);

// RECH-05: cambia la identidad.
test(
  'RECH-05: no permite cambiar identidad',
  async () => {
    const anterior = await leerInscripcion();

    await assertFails(
      ejecutarRechazo({
        ...cambioRechazo(anterior),
        estudianteNombre: 'Otra persona',
      })
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// RECH-06: intenta rechazar una reserva ajena.
test(
  'RECH-06: otro estudiante no puede rechazar',
  async () => {
    const anterior = await leerInscripcion();

    await assertFails(
      ejecutarRechazo(
        cambioRechazo(anterior),
        0,
        otroUid
      )
    );

    await verificarEstado('pendiente', 1, 1);
  }
);
