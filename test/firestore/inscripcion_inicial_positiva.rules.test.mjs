
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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
} from 'firebase/firestore';

// Nunca ejecutar estas pruebas contra Firebase de producción.
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Esta prueba requiere el emulador de Firestore.');
}

const projectId = 'demo-saman-inscripciones-permitidas';
const uid = 'estudiante-prueba';
const uidAjeno = 'otro-estudiante';
const codigo = 'TEN-01';
const inscripcionId = `${uid}_${codigo}`;

let env;

function datosInscripcion(fechaActual) {
  return {
    estudianteUid: uid,
    estudianteCedula: '12345678',
    estudianteNombre: 'Estudiante de Prueba',
    estudianteCarnet: '20261111',
    estudianteCorreo: 'prueba@unimet.edu.ve',
    deporteId: codigo,
    deporteNombre: 'Tenis',
    entrenadorUid: null,
    estado: 'pendiente',
    motivo: null,
    fechaInscripcion: fechaActual,
    fechaLimitePago: new Date(
      fechaActual.getTime() + 24 * 60 * 60 * 1000
    ),
    pagoId: null,
    historial: [
      {
        estado: 'pendiente',
        fecha: fechaActual,
        responsableUid: uid,
      },
    ],
  };
}

function dbPropietario() {
  return env.authenticatedContext(uid, {
    email: 'prueba@unimet.edu.ve',
  }).firestore();
}

async function crearInscripcion(db) {
  const fechaActual = new Date();

  const lote = writeBatch(db);

  lote.set(
    doc(db, 'inscripciones', inscripcionId),
    datosInscripcion(fechaActual)
  );

  lote.update(doc(db, 'deportes', codigo), {
    cuposOcupados: 1,
  });

  await assertSucceeds(lote.commit());
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();

  // Preparar datos de prueba sin aplicar las reglas.
  // Esto solo funciona dentro del emulador.
  await env.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    await setDoc(doc(db, 'usuarios', uid), {
      cedula: '12345678',
      nombre: 'Estudiante de Prueba',
      correo: 'prueba@unimet.edu.ve',
      carnet: '20261111',
      rol: 'estudiante',
      estado: 'activo',
    });

    await setDoc(doc(db, 'usuarios', uidAjeno), {
      cedula: '87654321',
      nombre: 'Otro Estudiante',
      correo: 'otro@unimet.edu.ve',
      carnet: '20262222',
      rol: 'estudiante',
      estado: 'activo',
    });

    await setDoc(doc(db, 'deportes', codigo), {
      codigo,
      nombre: 'Tenis',
      descripcion: 'Deporte utilizado para comprobar inscripciones',
      disciplina: 'raqueta',
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
  });
});

after(async () => {
  if (env) {
    await env.cleanup();
  }
});

// ==============================================
// PRUEBA 1: INSCRIPCION Y CANCELACION
// ==============================================

test(
  'INS-positiva: estudiante se inscribe y luego cancela liberando el cupo',
  async () => {
    const db = dbPropietario();

    const referenciaInscripcion = doc(
      db, 'inscripciones', inscripcionId
    );

    const referenciaDeporte = doc(
      db, 'deportes', codigo
    );

    // Crear la inscripción y reservar un cupo.
    await crearInscripcion(db);

    const inscripcionAntes = await getDoc(referenciaInscripcion);
    const deporteAntes = await getDoc(referenciaDeporte);

    assert.equal(inscripcionAntes.exists(), true);
    assert.equal(inscripcionAntes.data().estado, 'pendiente');
    assert.equal(inscripcionAntes.data().estudianteUid, uid);
    assert.equal(deporteAntes.data().cuposOcupados, 1);
    assert.equal(deporteAntes.data().cuposConfirmados, 0);

    // Cancelar la inscripción y liberar el cupo.
    const fechaCancelacion = new Date();
    const historialAnterior = inscripcionAntes.data().historial;

    const loteCancelacion = writeBatch(db);

    loteCancelacion.update(referenciaInscripcion, {
      estado: 'cancelada',
      motivo: null,
      historial: [
        ...historialAnterior,
        {
          estado: 'cancelada',
          fecha: fechaCancelacion,
          responsableUid: uid,
        },
      ],
    });

    loteCancelacion.update(referenciaDeporte, {
      cuposOcupados: 0,
    });

    await assertSucceeds(loteCancelacion.commit());

    // Verificar el resultado final.
    await env.withSecurityRulesDisabled(async (contexto) => {
      const dbVerificacion = contexto.firestore();

      const inscripcionFinal = await getDoc(
        doc(dbVerificacion, 'inscripciones', inscripcionId)
      );

      const deporteFinal = await getDoc(
        doc(dbVerificacion, 'deportes', codigo)
      );

      const datos = inscripcionFinal.data();

      assert.equal(datos.estado, 'cancelada');
      assert.equal(datos.motivo, null);
      assert.equal(datos.historial.length, 2);
      assert.equal(datos.historial[0].estado, 'pendiente');
      assert.equal(datos.historial[1].estado, 'cancelada');
      assert.equal(datos.historial[1].responsableUid, uid);

      assert.equal(deporteFinal.data().cuposOcupados, 0);
      assert.equal(deporteFinal.data().cuposConfirmados, 0);
    });
  }
);

// ==============================================
// PRUEBA 2: SEGURIDAD DE INSCRIPCION AJENA
// ==============================================

test(
  'SEG-ajena: otro estudiante no puede modificar una inscripcion completa',
  async () => {
    const db = dbPropietario();

    // Crear primero una inscripción completamente válida.
    await crearInscripcion(db);

    const dbAjeno = env.authenticatedContext(uidAjeno, {
      email: 'otro@unimet.edu.ve',
    }).firestore();

    const referenciaAjena = doc(
      dbAjeno, 'inscripciones', inscripcionId
    );

    // Intentar cancelar una inscripción que no le pertenece.
    await assertFails(
      updateDoc(referenciaAjena, {
        estado: 'cancelada',
      })
    );

    // Verificar que la operación rechazada no cambió los datos.
    await env.withSecurityRulesDisabled(async (contexto) => {
      const dbVerificacion = contexto.firestore();

      const inscripcion = await getDoc(
        doc(dbVerificacion, 'inscripciones', inscripcionId)
      );

      const deporte = await getDoc(
        doc(dbVerificacion, 'deportes', codigo)
      );

      assert.equal(inscripcion.data().estado, 'pendiente');
      assert.equal(inscripcion.data().historial.length, 1);
      assert.equal(deporte.data().cuposOcupados, 1);
      assert.equal(deporte.data().cuposConfirmados, 0);
    });
  }
);
