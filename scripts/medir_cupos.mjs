// Mide cuánto tarda en llegar un cambio de cupos a quien está escuchando
// el deporte (Hito 4: "cupos actualizados en menos de 2 s").
//
// Uso, con el emulador encendido (`npm run emulador`), en otra terminal:
//   node scripts/medir_cupos.mjs
//
// Qué hace: crea un deporte de prueba (MED-01), lo escucha en tiempo real
// como lo hace la pantalla de detalle, cambia sus cupos 20 veces y anota
// cuánto tarda cada cambio en llegar. Al final borra el deporte.
//
// Solo funciona contra el emulador local: nunca toca la base de datos real.

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';

if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST)) {
  console.error('Este script solo funciona contra el emulador local.');
  process.exit(1);
}

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');

initializeApp({ projectId: 'saman-deportivo' });
const db = getFirestore();

const MUESTRAS = 20;
const LIMITE_MS = 2000;
const deporte = db.collection('deportes').doc('MED-01');

await deporte.set({
  codigo: 'MED-01',
  nombre: 'Deporte de medición',
  descripcion: 'Creado por scripts/medir_cupos.mjs; se borra al terminar.',
  disciplina: 'colectivo',
  costo: 10,
  cupoMaximo: MUESTRAS + 1,
  cuposOcupados: 0,
  cuposConfirmados: 0,
  horarios: [],
  dias: [],
  activo: true,
  promedioCalificacion: 0,
  totalResenas: 0,
  creadoEn: Timestamp.now(),
  actualizadoEn: null,
});

// Cambios enviados que todavía no llegan: valor de cupos -> momento del envío.
const pendientes = new Map();
const tiempos = [];
let avisar = () => {};

const dejarDeEscuchar = deporte.onSnapshot((foto) => {
  const valor = foto.get('cuposOcupados');
  const enviado = pendientes.get(valor);
  if (enviado === undefined) return;
  pendientes.delete(valor);
  tiempos.push(performance.now() - enviado);
  avisar();
});

for (let i = 1; i <= MUESTRAS; i++) {
  const llego = new Promise((resolver) => { avisar = resolver; });
  pendientes.set(i, performance.now());
  await deporte.update({ cuposOcupados: i });
  await llego;
}

dejarDeEscuchar();
await deporte.delete();

const ordenados = [...tiempos].sort((a, b) => a - b);
const promedio = tiempos.reduce((suma, t) => suma + t, 0) / tiempos.length;
const p95 = ordenados[Math.ceil(ordenados.length * 0.95) - 1];
const maximo = ordenados[ordenados.length - 1];
const ms = (t) => `${t.toFixed(0)} ms`;

console.log(`Cambios de cupos medidos: ${tiempos.length}`);
console.log(`Promedio: ${ms(promedio)}  ·  95 %: ${ms(p95)}  ·  Máximo: ${ms(maximo)}`);
console.log(maximo < LIMITE_MS
  ? `Cumple: todos llegaron en menos de ${LIMITE_MS} ms.`
  : `No cumple: al menos uno tardó ${LIMITE_MS} ms o más.`);

process.exit(0);
