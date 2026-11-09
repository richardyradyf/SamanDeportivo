
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';

import {
  initializeTestEnvironment,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

// Esta prueba solo puede ejecutarse con el emulador.
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    'Esta prueba requiere el emulador de Firestore.'
  );
}

const projectId = 'demo-saman-inscripciones-permitidas';
const uid = 'estudiante-prueba';
const codigo = 'TEN-01';
const inscripcionId = `${uid}_${codigo}`;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });

  await env.clearFirestore();

  // Preparar datos iniciales exclusivamente en el emulador.
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

test(
  'INS-positiva: estudiante se inscribe y luego cancela liberando el cupo',
  async () => {
    const db = env.authenticatedContext(uid, {
      email: 'prueba@unimet.edu.ve',
    }).firestore();

    const referenciaDeporte = doc(
      db,
      'deportes',
      codigo
    );

    const referenciaInscripcion = doc(
      db,
      'inscripciones',
      inscripcionId
    );

    // ==========================================
    // PARTE 1: INSCRIPCION INICIAL
    // ==========================================

    const fechaActual = new Date();

    const fechaLimite = new Date(
      fechaActual.getTime() + 24 * 60 * 60 * 1000
    );

    const loteInscripcion = writeBatch(db);

    loteInscripcion.set(referenciaInscripcion, {
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
      fechaLimitePago: fechaLimite,
      pagoId: null,
      historial: [
        {
          estado: 'pendiente',
          fecha: fechaActual,
          responsableUid: uid,
        },
      ],
    });

    // Reservar un cupo en la misma operacion atomica.
    loteInscripcion.update(referenciaDeporte, {
      cuposOcupados: 1,
    });

    await assertSucceeds(loteInscripcion.commit());

    // Comprobar que la inscripcion fue exitosa.
    const inscripcionAntes = await getDoc(
      referenciaInscripcion
    );

    assert.equal(inscripcionAntes.exists(), true);
    assert.equal(inscripcionAntes.data().estado, 'pendiente');
    assert.equal(inscripcionAntes.data().estudianteUid, uid);

    const deporteAntes = await getDoc(
      referenciaDeporte
    );

    assert.equal(deporteAntes.data().cuposOcupados, 1);
    assert.equal(deporteAntes.data().cuposConfirmados, 0);

    // ==========================================
    // PARTE 2: CANCELACION DE LA INSCRIPCION
    // ==========================================

    const fechaCancelacion = new Date();

    const historialAnterior =
      inscripcionAntes.data().historial;

    const loteCancelacion = writeBatch(db);

    // Cambiar el estado de la inscripcion.
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

    // Liberar exactamente un cupo.
    loteCancelacion.update(referenciaDeporte, {
      cuposOcupados: 0,
    });

    // Las dos actualizaciones deben estar autorizadas.
    await assertSucceeds(loteCancelacion.commit());

    // ==========================================
    // PARTE 3: VERIFICACION FINAL
    // ==========================================

    await env.withSecurityRulesDisabled(
      async (contexto) => {
        const dbVerificacion = contexto.firestore();

        const inscripcionFinal = await getDoc(
          doc(
            dbVerificacion,
            'inscripciones',
            inscripcionId
          )
        );

        const deporteFinal = await getDoc(
          doc(
            dbVerificacion,
            'deportes',
            codigo
          )
        );

        // La inscripcion debe estar cancelada.
        assert.equal(inscripcionFinal.exists(), true);
        assert.equal(
          inscripcionFinal.data().estado,
          'cancelada'
        );

        // El historial debe conservar ambas operaciones.
        const historialFinal =
          inscripcionFinal.data().historial;

        assert.equal(historialFinal.length, 2);

        assert.equal(
          historialFinal[0].estado,
          'pendiente'
        );

        assert.equal(
          historialFinal[1].estado,
          'cancelada'
        );

        assert.equal(
          historialFinal[1].responsableUid,
          uid
        );

        assert.equal(
          inscripcionFinal.data().motivo,
          null
        );

        // Los cupos deben regresar al estado inicial.
        assert.equal(
          deporteFinal.data().cuposOcupados,
          0
        );

        assert.equal(
          deporteFinal.data().cuposConfirmados,
          0
        );
      }
    );
  }
);
