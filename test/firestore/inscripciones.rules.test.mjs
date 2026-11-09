
import { readFileSync } from 'node:fs';
import test, { before, after } from 'node:test';

import {
  initializeTestEnvironment,
  assertFails,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
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
      cupoMaximo: 2,
      cuposOcupados: 1,
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
test('Estudiante no puede confirmar pagos manualmente', async () => {
  const db = estudiante();

  await assertFails(
    updateDoc(doc(db, 'inscripciones', 'uid-b_TEN-01'), {
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
