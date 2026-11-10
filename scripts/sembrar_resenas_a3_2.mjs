// Exclusivamente para el EMULADOR local de Firebase. NO desplegar ni ejecutar
// contra Firebase real. No se ejecuta automáticamente al iniciar la app.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^(127\.0\.0\.1|localhost):8080$/.test(host)) {
  throw new Error('Solo se permite Firestore Emulator local en el puerto 8080.');
}
const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
initializeApp({ projectId: 'saman-deportivo' });
const db = getFirestore();
const deporte = await db.doc('deportes/FUT-01').get();
if (!deporte.exists) {
  throw new Error('Primero carga los datos base con npm run emulador:datos.');
}
const ejemplos = [
  { id: 'est-1', deporte: 'FUT-01', nombre: 'Ana Pérez', puntuacion: 5,
    comentario: 'Excelente entrenamiento de fútbol.', oculta: false },
  { id: 'est-2', deporte: 'FUT-01', nombre: 'Luis Gómez', puntuacion: 3,
    comentario: 'Los ejercicios fueron interesantes.', oculta: false },
  { id: 'est-1', deporte: 'BAL-01', nombre: 'Ana Pérez', puntuacion: 4,
    comentario: 'Muy buena actividad deportiva.', oculta: false },
];
let creadas = 0;
for (const ejemplo of ejemplos) {
  const ref = db.doc(`deportes/${ejemplo.deporte}/resenas/${ejemplo.id}`);
  if (!(await ref.get()).exists) {
    await ref.set({
      estudianteNombre: ejemplo.nombre,
      puntuacion: ejemplo.puntuacion,
      comentario: ejemplo.comentario,
      oculta: ejemplo.oculta,
      fecha: Timestamp.now(),
    });
    creadas++;
  }
}
console.log(`Reseñas de demostración creadas: ${creadas}. Solo en emulator ${host}`);
