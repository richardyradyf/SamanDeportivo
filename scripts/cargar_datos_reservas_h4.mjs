// Datos exclusivos para pruebas de integracion H4.

if (
  process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080' ||
  process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099'
) {
  throw new Error('Este script requiere los emuladores locales.');
}

const { initializeApp } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getFirestore } = await import('firebase-admin/firestore');

initializeApp({
  projectId: 'demo-saman-reservas-h4',
});

const auth = getAuth();
const db = getFirestore();

const usuarios = [
  {
    uid: 'est-qa-1',
    correo: 'qa1@correo.unimet.edu.ve',
    nombre: 'Estudiante QA Uno',
    cedula: '28000001',
    carnet: '20260001',
    rol: 'estudiante',
    estado: 'activo',
    telefono: '+584121234567',
  },
  {
    uid: 'est-qa-2',
    correo: 'qa2@correo.unimet.edu.ve',
    nombre: 'Estudiante QA Dos',
    cedula: '28000002',
    carnet: '20260002',
    rol: 'estudiante',
    estado: 'activo',
    telefono: '+584149876543',
  },
  {
    uid: 'ent-qa-1',
    correo: 'entrenador@saman.test',
    nombre: 'Entrenador QA',
    cedula: '28000003',
    rol: 'entrenador',
    especialidad: 'Tenis',
    aniosExperiencia: 5,
    estado: 'activo',
  },
  {
    uid: 'admin-qa-1',
    correo: 'admin@saman.test',
    nombre: 'Administrador QA',
    cedula: '28000004',
    rol: 'administrador',
    estado: 'activo',
  },
];

for (const { uid, ...datos } of usuarios) {
  try {
    await auth.createUser({
      uid,
      email: datos.correo,
      password: 'Prueba123!',
      emailVerified: true,
    });
  } catch (error) {
    if (error.code !== 'auth/uid-already-exists') {
      throw error;
    }
  }

  await db.doc(`usuarios/${uid}`).set(datos);
}

await db.doc('espacios/cancha-qa').set({
  nombre: 'Cancha QA',
  tipo: 'Tenis',
  descripcion: 'Instalacion de pruebas',
  activo: true,
  creadoEn: new Date(),
  actualizadoEn: new Date(),
});

await db.doc('deportes/TEN-01').set({
  codigo: 'TEN-01',
  nombre: 'Tenis',
  descripcion: 'Deporte de pruebas H4',
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
  creadoEn: new Date(),
  actualizadoEn: null,
});

console.log('4 usuarios de prueba creados.');
console.log('Instalacion cancha-qa creada.');
console.log('Deporte TEN-01 creado.');
console.log('Datos de integracion H4 preparados.');


// Reservas historicas para comprobar la restriccion temporal.

const ahoraQA = Date.now();

const reservasTemporales = [
  {
    id: 'qa-reserva-en-curso',
    inicio: new Date(ahoraQA - 30 * 60000),
    fin: new Date(ahoraQA + 30 * 60000),
  },
  {
    id: 'qa-reserva-finalizada',
    inicio: new Date(ahoraQA - 120 * 60000),
    fin: new Date(ahoraQA - 60 * 60000),
  },
];

const loteTemporal = db.batch();

for (const { id, inicio, fin } of reservasTemporales) {
  loteTemporal.set(db.doc(`reservasEspacios/${id}`), {
    espacioId: 'cancha-qa',
    usuarioUid: 'est-qa-1',
    rol: 'estudiante',
    inicio,
    fin,
    motivo: 'Prueba temporal QA',
    estado: 'activa',
    creadoEn: new Date(ahoraQA - 86400000),
    actualizadoEn: null,
  });

  loteTemporal.set(db.doc(`ocupacionesEspacios/${id}`), {
    espacioId: 'cancha-qa',
    inicio,
    fin,
  });
}

await loteTemporal.commit();

console.log('Dos reservas temporales preparadas.');
