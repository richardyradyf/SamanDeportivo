// Carga datos de prueba del Hito 3 en el EMULADOR de Firebase.
//
// Uso (con el emulador ya encendido con `npm run emulador`):
//   npm run emulador:datos
//
// Nunca toca la base de datos real: fija las variables del emulador antes de
// iniciar firebase-admin y se detiene si apuntan a otro lugar.
// Las contraseñas son solo para el emulador.

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

const esLocal = (host) => /^(127\.0\.0\.1|localhost):\d+$/.test(host);
if (!esLocal(process.env.FIRESTORE_EMULATOR_HOST) || !esLocal(process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  console.error('Este script solo funciona contra el emulador local.');
  process.exit(1);
}

const { initializeApp } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');

initializeApp({ projectId: 'saman-deportivo' });
const auth = getAuth();
const db = getFirestore();

const CONTRASENA = 'Prueba123!';
const ahora = Timestamp.now();

const usuarios = [
  { uid: 'admin-1', correo: 'admin@saman.test', datos: {
    cedula: '10000001', nombre: 'Administración Samán', rol: 'administrador' } },
  { uid: 'ent-1', correo: 'entrenador1@saman.test', datos: {
    cedula: '10000002', nombre: 'Carlos Rojas', rol: 'entrenador',
    especialidad: 'Fútbol', aniosExperiencia: 8 } },
  { uid: 'ent-2', correo: 'entrenador2@saman.test', datos: {
    cedula: '10000003', nombre: 'Laura Méndez', rol: 'entrenador',
    especialidad: 'Baloncesto', aniosExperiencia: 5 } },
  { uid: 'est-1', correo: 'estudiante1@correo.unimet.edu.ve', datos: {
    cedula: '28000001', nombre: 'Ana Pérez', rol: 'estudiante',
    carnet: '20231001', estado: 'activo' } },
  { uid: 'est-2', correo: 'estudiante2@correo.unimet.edu.ve', datos: {
    cedula: '28000002', nombre: 'Luis Gómez', rol: 'estudiante',
    carnet: '20231002', estado: 'activo' } },
  // Inactivo: para probar el rechazo por solvencia (RF-10).
  { uid: 'est-3', correo: 'estudiante3@correo.unimet.edu.ve', datos: {
    cedula: '28000003', nombre: 'María Torres', rol: 'estudiante',
    carnet: '20231003', estado: 'inactivo' } },
];

const sesion = (dia, horaInicio, horaFin, lugar) => ({ dia, horaInicio, horaFin, lugar });

// Mismos deportes que lib/core/datos_prueba/datos_de_prueba.dart.
// TEN-01 tiene cupo 2 para probar "sin cupos".
const deportes = [
  { codigo: 'FUT-01', nombre: 'Fútbol sala', disciplina: 'colectivo', costo: 10, cupoMaximo: 20,
    descripcion: 'Entrenamientos de fútbol sala para todos los niveles.', entrenador: 'ent-1',
    horarios: [sesion('lunes', '16:00', '18:00', 'Cancha techada'), sesion('miercoles', '16:00', '18:00', 'Cancha techada')] },
  { codigo: 'BAL-01', nombre: 'Baloncesto', disciplina: 'colectivo', costo: 10, cupoMaximo: 15,
    descripcion: 'Fundamentos, táctica y partidos internos.', entrenador: 'ent-2',
    horarios: [sesion('martes', '17:00', '19:00', 'Gimnasio cubierto'), sesion('jueves', '17:00', '19:00', 'Gimnasio cubierto')] },
  { codigo: 'TEN-01', nombre: 'Tenis', disciplina: 'raqueta', costo: 15, cupoMaximo: 2,
    descripcion: 'Clases de tenis en grupos pequeños.', entrenador: 'ent-1',
    horarios: [sesion('martes', '16:00', '17:30', 'Canchas de tenis'), sesion('jueves', '16:00', '17:30', 'Canchas de tenis')] },
  { codigo: 'NAT-01', nombre: 'Natación', disciplina: 'acuatico', costo: 12, cupoMaximo: 12,
    descripcion: 'Técnica de los cuatro estilos y resistencia.', entrenador: 'ent-2',
    horarios: [sesion('viernes', '07:00', '09:00', 'Piscina')] },
  { codigo: 'KAR-01', nombre: 'Karate', disciplina: 'combate', costo: 8, cupoMaximo: 10,
    descripcion: 'Kata, kumite y preparación física.', entrenador: null,
    horarios: [sesion('sabado', '09:00', '11:00', 'Sala de combate')] },
];

async function crearUsuario({ uid, correo, datos }) {
  try {
    await auth.createUser({ uid, email: correo, password: CONTRASENA, displayName: datos.nombre });
  } catch (error) {
    if (error.code !== 'auth/uid-already-exists' && error.code !== 'auth/email-already-exists') throw error;
    await auth.updateUser(uid, { email: correo, password: CONTRASENA, displayName: datos.nombre });
  }
  await db.doc(`usuarios/${uid}`).set({ ...datos, correo });
  if (datos.rol === 'estudiante') {
    await db.doc(`cedulas/${datos.cedula}`).set({ uid });
    await db.doc(`carnets/${datos.carnet}`).set({ uid });
  }
}

for (const usuario of usuarios) {
  await crearUsuario(usuario);
}

const porUid = Object.fromEntries(usuarios.map((u) => [u.uid, u.datos]));
const lote = db.batch();
for (const { entrenador, horarios, ...deporte } of deportes) {
  const datosEntrenador = entrenador ? porUid[entrenador] : null;
  lote.set(db.doc(`deportes/${deporte.codigo}`), {
    ...deporte,
    imagenUrl: null,
    cuposOcupados: 0,
    cuposConfirmados: 0,
    entrenadorUid: entrenador,
    entrenadorNombre: datosEntrenador?.nombre ?? null,
    entrenadorEspecialidad: datosEntrenador?.especialidad ?? null,
    horarios,
    dias: [...new Set(horarios.map((h) => h.dia))],
    activo: true,
    promedioCalificacion: 0,
    totalResenas: 0,
    creadoEn: ahora,
    actualizadoEn: null,
  });
}
await lote.commit();

console.log(`Listo: ${usuarios.length} usuarios y ${deportes.length} deportes en el emulador.`);
console.log(`Contraseña de todas las cuentas de prueba: la constante CONTRASENA de este script.`);
console.log('Interfaz del emulador: http://127.0.0.1:4000');
