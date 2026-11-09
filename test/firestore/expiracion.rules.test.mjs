
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
const uid = 'est-exp-1';
const otroUid = 'est-exp-2';
const codigo = 'TEN-01';
const inscripcionId = `${uid}_${codigo}`;

let entorno;

function estudiante(id = uid) {
  return entorno.authenticatedContext(id).firestore();
}

function datosUsuario(id) {
  return {
    cedula: id === uid ? '28000001' : '28000002',
    nombre: id === uid ? 'Ana Perez' : 'Luis Perez',
    carnet: id === uid ? '20231001' : '20231002',
    correo: `${id}@correo.unimet.edu.ve`,
    rol: 'estudiante',
    estado: 'activo',
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

function datosInscripcion(vencida = true) {
  const ahora = Date.now();

  const fechaInscripcion = Timestamp.fromMillis(
    ahora - 48 * 60 * 60 * 1000
  );

  const fechaLimitePago = Timestamp.fromMillis(
    vencida
      ? ahora - 24 * 60 * 60 * 1000
      : ahora + 24 * 60 * 60 * 1000
  );

  return {
    estudianteUid: uid,
    estudianteCedula: '28000001',
    estudianteNombre: 'Ana Perez',
    estudianteCarnet: '20231001',
    estudianteCorreo: 'est-exp-1@correo.unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: 'Tenis',
    entrenadorUid: null,
    estado: 'pendiente',
    motivo: null,
    fechaInscripcion,
    fechaLimitePago,
    pagoId: null,
    historial: [
      {
        estado: 'pendiente',
        fecha: fechaInscripcion,
        responsableUid: uid,
      },
    ],
  };
}

// Lee la inscripcion realmente almacenada en el emulador.
// Evita crear un historial con fechas diferentes al original.
async function leerInscripcionSembrada() {
  let inscripcion;

  await entorno.withSecurityRulesDisabled(async (contexto) => {
    const referencia = doc(
      contexto.firestore(),
      'inscripciones',
      inscripcionId
    );

    const documento = await getDoc(referencia);

    assert.equal(documento.exists(), true);

    inscripcion = documento.data();
  });

  return inscripcion;
}

function cambioExpiracion(anterior) {
  return {
    estado: 'expirada',
    motivo: 'plazo_vencido',
    historial: [
      ...anterior.historial,
      {
        estado: 'expirada',
        fecha: Timestamp.now(),
        responsableUid: uid,
      },
    ],
  };
}

// Actualiza la inscripcion y el deporte en un mismo lote atomico.
async function ejecutarExpiracion(
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

async function verificarEstado(
  estado,
  ocupados,
  longitudHistorial
) {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    const inscripcion = (
      await getDoc(
        doc(db, 'inscripciones', inscripcionId)
      )
    ).data();

    const deporte = (
      await getDoc(
        doc(db, 'deportes', codigo)
      )
    ).data();

    assert.equal(inscripcion.estado, estado);
    assert.equal(
      inscripcion.historial.length,
      longitudHistorial
    );
    assert.equal(deporte.cuposOcupados, ocupados);
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
      datosUsuario(uid)
    );

    await setDoc(
      doc(db, 'usuarios', otroUid),
      datosUsuario(otroUid)
    );

    await setDoc(
      doc(db, 'deportes', codigo),
      datosDeporte()
    );

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

// EXP-01: expiracion valida.
test(
  'EXP-01: reserva vencida libera un cupo',
  async () => {
    const anterior = await leerInscripcionSembrada();

    await assertSucceeds(
      ejecutarExpiracion(
        cambioExpiracion(anterior)
      )
    );

    await verificarEstado('expirada', 0, 2);

    const posterior = await leerInscripcionSembrada();

    // Se conserva exactamente el registro original.
    assert.deepEqual(
      posterior.historial[0],
      anterior.historial[0]
    );

    assert.equal(
      posterior.historial[1].estado,
      'expirada'
    );
  }
);

// EXP-02: no se libera el cupo.
test(
  'EXP-02: no puede expirar sin liberar cupo',
  async () => {
    const anterior = await leerInscripcionSembrada();

    await assertFails(
      ejecutarExpiracion(
        cambioExpiracion(anterior),
        1
      )
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// EXP-03: reserva que todavia no ha vencido.
test(
  'EXP-03: no puede expirar antes del plazo',
  async () => {
    const inscripcionFutura = datosInscripcion(false);

    await entorno.withSecurityRulesDisabled(
      async (contexto) => {
        await setDoc(
          doc(
            contexto.firestore(),
            'inscripciones',
            inscripcionId
          ),
          inscripcionFutura
        );
      }
    );

    const anterior = await leerInscripcionSembrada();

    await assertFails(
      ejecutarExpiracion(
        cambioExpiracion(anterior)
      )
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// EXP-04: historial anterior alterado.
test(
  'EXP-04: no permite borrar historial',
  async () => {
    const anterior = await leerInscripcionSembrada();
    const cambios = cambioExpiracion(anterior);

    cambios.historial = [
      cambios.historial.at(-1),
    ];

    await assertFails(
      ejecutarExpiracion(cambios)
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// EXP-05: liberacion de mas cupos de los permitidos.
test(
  'EXP-05: no permite liberar dos cupos',
  async () => {
    const anterior = await leerInscripcionSembrada();

    await assertFails(
      ejecutarExpiracion(
        cambioExpiracion(anterior),
        -1
      )
    );

    await verificarEstado('pendiente', 1, 1);
  }
);

// EXP-06: otro estudiante intenta expirar la reserva.
test(
  'EXP-06: otro estudiante no puede expirar la reserva',
  async () => {
    const anterior = await leerInscripcionSembrada();

    await assertFails(
      ejecutarExpiracion(
        cambioExpiracion(anterior),
        0,
        otroUid
      )
    );

    await verificarEstado('pendiente', 1, 1);
  }
);
