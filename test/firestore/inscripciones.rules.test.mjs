import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

import {
  arrayUnion,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-saman-inscripciones',
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });

  // Crear datos iniciales sin aplicar las reglas.
  // Esto es exclusivo del entorno de pruebas.
  await env.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();

    await setDoc(doc(db, 'deportes', 'TEN-01'), {
      codigo: 'TEN-01',
      nombre: 'Tenis',
      costo: 10,
      cupoMaximo: 2,
      cuposOcupados: 2,
      cuposConfirmados: 0,
      activo: true,
    });

    await setDoc(
      doc(db, 'inscripciones', 'uid-b_TEN-01'),
      {
        estudianteUid: 'uid-b',
        deporteId: 'TEN-01',
        estado: 'pendiente',
      },
    );

    // Inscripción pendiente propia de uid-a, para las pruebas de pago.
    await setDoc(doc(db, 'inscripciones', 'uid-a_TEN-01'), {
      estudianteUid: 'uid-a',
      deporteId: 'TEN-01',
      estado: 'pendiente',
      pagoId: null,
      fechaLimitePago: Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
      historial: [],
    });

    await setDoc(doc(db, 'usuarios', 'uid-a'), {
      cedula: '12345678',
      nombre: 'Estudiante A',
      correo: 'a@unimet.edu.ve',
      carnet: '20261111',
      rol: 'estudiante',
      estado: 'activo',
    });
  });
});

after(async () => {
  if (env) {
    await env.cleanup();
  }
});

const estudiante = () =>
  env.authenticatedContext('uid-a', {
    email: 'a@unimet.edu.ve',
  }).firestore();

const anonimo = () =>
  env.unauthenticatedContext().firestore();

// Pago, confirmación y cupo en una sola escritura, como lo hace la app.
function pagarYConfirmar(db, { orden, monto }) {
  const lote = writeBatch(db);
  lote.set(doc(db, 'pagos', orden), {
    inscripcionId: 'uid-a_TEN-01',
    estudianteUid: 'uid-a',
    deporteId: 'TEN-01',
    deporteNombre: 'Tenis',
    paypalOrderId: orden,
    paypalCaptureId: `CAPTURA-${orden}`,
    monto,
    moneda: 'USD',
    estado: 'aprobado',
    fecha: Timestamp.now(),
  });
  lote.update(doc(db, 'inscripciones', 'uid-a_TEN-01'), {
    estado: 'confirmada',
    pagoId: orden,
    historial: arrayUnion({
      estado: 'confirmada',
      fecha: Timestamp.now(),
      responsableUid: 'uid-a',
    }),
  });
  lote.update(doc(db, 'deportes', 'TEN-01'), { cuposConfirmados: 1 });
  return lote.commit();
}

// SEG-01
test('Usuario sin sesion no puede crear inscripciones', async () => {
  const db = anonimo();

  await assertFails(
    setDoc(doc(db, 'inscripciones', 'anon_TEN-01'), {
      estudianteUid: 'anon',
      deporteId: 'TEN-01',
      estado: 'pendiente',
    }),
  );
});

// SEG-02
test('Estudiante no puede modificar inscripciones ajenas', async () => {
  const db = estudiante();

  await assertFails(
    updateDoc(doc(db, 'inscripciones', 'uid-b_TEN-01'), {
      estado: 'cancelada',
    }),
  );
});

// SEG-03
test('Estudiante no puede alterar manualmente los cupos', async () => {
  const db = estudiante();

  await assertFails(
    updateDoc(doc(db, 'deportes', 'TEN-01'), {
      cuposOcupados: 2,
    }),
  );
});

// SEG-04
test('Estudiante no puede confirmar sin un pago válido', async () => {
  const db = estudiante();

  // Su propia inscripción pendiente, con un pagoId que no existe.
  await assertFails(
    updateDoc(doc(db, 'inscripciones', 'uid-a_TEN-01'), {
      estado: 'confirmada',
      pagoId: 'PAGO_FALSO',
    }),
  );
});

// SEG-05
test('Estudiante no puede leer inscripciones ajenas', async () => {
  const db = estudiante();

  await assertFails(
    getDoc(doc(db, 'inscripciones', 'uid-b_TEN-01')),
  );
});

// SEG-06
test('Estudiante no puede pagar un monto distinto al costo del deporte', async () => {
  const db = estudiante();

  await assertFails(pagarYConfirmar(db, { orden: 'ORDEN-BARATA', monto: 1 }));
});

// SEG-07 (va de último: deja la inscripción confirmada)
test('Estudiante confirma su inscripción con un pago válido', async () => {
  const db = estudiante();

  await assertSucceeds(pagarYConfirmar(db, { orden: 'ORDEN-OK', monto: 10 }));
});