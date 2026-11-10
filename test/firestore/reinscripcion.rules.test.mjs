
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test, { before, beforeEach, after } from 'node:test';

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
  Timestamp,
} from 'firebase/firestore';

// Datos de prueba
const projectId = 'demo-saman-inscripciones-permitidas';
const uid = 'est-1';
const codigo = 'TEN-01';
const inscripcionId = `${uid}_${codigo}`;
const correo = 'estudiante1@correo.unimet.edu.ve';

let env;

// Acceso como estudiante
function estudiante() {
  return env.authenticatedContext(uid, { email: correo }).firestore();
}

// Usuario de prueba
function datosUsuario() {
  return {
    cedula: '28000001',
    nombre: 'Ana Perez',
    correo,
    carnet: '20231001',
    rol: 'estudiante',
    estado: 'activo',
  };
}

// Deporte con dos cupos disponibles
function datosDeporte() {
  return {
    codigo,
    nombre: 'Tenis',
    descripcion: 'Clases de tenis',
    disciplina: 'raqueta',
    costo: 15,
    imagenUrl: null,
    cupoMaximo: 2,
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
    creadoEn: Timestamp.now(),
    actualizadoEn: null,
  };
}

// Inscripcion que ya termino en cancelada, expirada o rechazada
function inscripcionTerminal(estado) {
  const fecha = Timestamp.fromMillis(
    Date.now() - 2 * 60 * 60 * 1000
  );

  const fechaTerminal = Timestamp.fromMillis(
    fecha.toMillis() + 30 * 60 * 1000
  );

  return {
    estudianteUid: uid,
    estudianteCedula: '28000001',
    estudianteNombre: 'Ana Perez',
    estudianteCarnet: '20231001',
    estudianteCorreo: correo,
    deporteId: codigo,
    deporteNombre: 'Tenis',
    entrenadorUid: null,
    estado,
    motivo: null,
    fechaInscripcion: fecha,
    fechaLimitePago: Timestamp.fromMillis(
      fecha.toMillis() + 24 * 60 * 60 * 1000
    ),
    pagoId: null,
    historial: [
      {
        estado: 'pendiente',
        fecha,
        responsableUid: uid,
      },
      {
        estado,
        fecha: fechaTerminal,
        responsableUid: uid,
      },
    ],
  };
}

// Datos que se actualizan al volver a inscribirse
function nuevaSolicitud(anterior) {
  const fecha = Timestamp.now();

  return {
    estado: 'pendiente',
    motivo: null,
    pagoId: null,
    fechaInscripcion: fecha,
    fechaLimitePago: Timestamp.fromMillis(
      fecha.toMillis() + 24 * 60 * 60 * 1000
    ),
    historial: [
      ...anterior.historial,
      {
        estado: 'pendiente',
        fecha,
        responsableUid: uid,
      },
    ],
  };
}

// Crear una inscripcion previa sin aplicar las reglas
async function sembrarInscripcion(estado) {
  const registro = inscripcionTerminal(estado);

  await env.withSecurityRulesDisabled(async (contexto) => {
    await setDoc(
      doc(contexto.firestore(), 'inscripciones', inscripcionId),
      registro
    );
  });

  return registro;
}

// Reinscribir y reservar cupo en una operacion atomica
async function intentarReinscripcion(cambios, cupos = 1) {
  const db = estudiante();
  const batch = writeBatch(db);

  batch.update(
    doc(db, 'inscripciones', inscripcionId),
    cambios
  );

  batch.update(
    doc(db, 'deportes', codigo),
    { cuposOcupados: cupos }
  );

  return batch.commit();
}

// Comprobar el estado final de los documentos
async function verificarEstado(estado, ocupados, historialTamano) {
  await env.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    const insc = (
      await getDoc(doc(db, 'inscripciones', inscripcionId))
    ).data();

    const deporte = (
      await getDoc(doc(db, 'deportes', codigo))
    ).data();

    assert.equal(insc.estado, estado);
    assert.equal(insc.historial.length, historialTamano);
    assert.equal(deporte.cuposOcupados, ocupados);
    assert.equal(deporte.cuposConfirmados, 0);
  });
}

// Inicializacion
before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

// Preparar datos limpios antes de cada prueba
beforeEach(async () => {
  await env.clearFirestore();

  await env.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    await setDoc(
      doc(db, 'usuarios', uid),
      datosUsuario()
    );

    await setDoc(
      doc(db, 'deportes', codigo),
      datosDeporte()
    );
  });
});

// Cerrar el entorno al terminar
after(async () => {
  if (env) {
    await env.cleanup();
  }
});

// PRUEBAS POSITIVAS: tres estados anteriores
for (const estado of ['cancelada', 'expirada', 'rechazada']) {
  test(
    `REINS-${estado}: vuelve a pendiente y reserva exactamente un cupo`,
    async () => {
      const original = await sembrarInscripcion(estado);

      await assertSucceeds(
        intentarReinscripcion(nuevaSolicitud(original))
      );

      await verificarEstado('pendiente', 1, 3);

      await env.withSecurityRulesDisabled(async (contexto) => {
        const insc = (
          await getDoc(
            doc(
              contexto.firestore(),
              'inscripciones',
              inscripcionId
            )
          )
        ).data();

        assert.deepEqual(
          insc.historial.slice(0, 2),
          original.historial
        );

        assert.equal(insc.historial[2].estado, 'pendiente');
      });
    }
  );
}

// PRUEBA NEGATIVA 1
test(
  'REINS-negativa: no admite reinscripcion sin actualizar cupos',
  async () => {
    const original = await sembrarInscripcion('cancelada');

    await assertFails(
      updateDoc(
        doc(estudiante(), 'inscripciones', inscripcionId),
        nuevaSolicitud(original)
      )
    );

    await verificarEstado('cancelada', 0, 2);
  }
);

// PRUEBA NEGATIVA 2
test(
  'REINS-negativa: no permite borrar historial anterior',
  async () => {
    const original = await sembrarInscripcion('cancelada');
    const cambios = nuevaSolicitud(original);

    cambios.historial = [
      cambios.historial.at(-1),
    ];

    await assertFails(
      intentarReinscripcion(cambios)
    );

    await verificarEstado('cancelada', 0, 2);
  }
);

// PRUEBA NEGATIVA 3
test(
  'REINS-negativa: estudiante inactivo no puede reinscribirse',
  async () => {
    const original = await sembrarInscripcion('cancelada');

    await env.withSecurityRulesDisabled(async (contexto) => {
      await updateDoc(
        doc(contexto.firestore(), 'usuarios', uid),
        { estado: 'inactivo' }
      );
    });

    await assertFails(
      intentarReinscripcion(nuevaSolicitud(original))
    );

    await verificarEstado('cancelada', 0, 2);
  }
);

// PRUEBA NEGATIVA 4
test(
  'REINS-negativa: no permite reinscripcion si el deporte esta lleno',
  async () => {
    const original = await sembrarInscripcion('expirada');

    await env.withSecurityRulesDisabled(async (contexto) => {
      await updateDoc(
        doc(contexto.firestore(), 'deportes', codigo),
        { cuposOcupados: 2 }
      );
    });

    await assertFails(
      intentarReinscripcion(nuevaSolicitud(original), 3)
    );

    await verificarEstado('expirada', 2, 2);
  }
);

// PRUEBA NEGATIVA 5
test(
  'REINS-negativa: no puede modificar identidad durante la reinscripcion',
  async () => {
    const original = await sembrarInscripcion('rechazada');

    await assertFails(
      intentarReinscripcion({
        ...nuevaSolicitud(original),
        estudianteNombre: 'Otra persona',
      })
    );

    await verificarEstado('rechazada', 0, 2);
  }
);
