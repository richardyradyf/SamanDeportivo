'use strict';

/**
 * A3.7 — Indicadores derivados SOLO de reseñas visibles y válidas.
 * Una reseña mal formada se ignora para los indicadores; no bloquea el resto.
 * La puntuación es entera de 1 a 5 (contrato Resena). La ausencia de
 * `oculta` se interpreta como visible, igual que Resena.fromMap.
 *
 * @param {Array<object | {data:Function}>} documentos
 * @returns {{promedioCalificacion:number,totalResenas:number,invalidas:number}}
 */
function calcularIndicadoresResenas(documentos) {
  if (!Array.isArray(documentos)) throw new TypeError('Se esperaba una lista de reseñas.');
  let suma = 0;
  let total = 0;
  let invalidas = 0;
  for (const doc of documentos) {
    const datos = doc && typeof doc.data === 'function' ? doc.data() : doc;
    if (datos?.oculta === true) continue;
    if (!datos || !Number.isInteger(datos.puntuacion) ||
        datos.puntuacion < 1 || datos.puntuacion > 5) {
      invalidas++;
      continue;
    }
    suma += datos.puntuacion;
    total++;
  }
  return {
    promedioCalificacion: total === 0 ? 0 : suma / total,
    totalResenas: total,
    invalidas,
  };
}

/**
 * Relee el conjunto completo de reseñas en una transacción, de manera que
 * notificaciones duplicadas o retrasadas produzcan la misma cifra final.
 *
 * Solo actualiza los DOS indicadores. En particular, no cambia
 * `actualizadoEn`, que A2 utiliza como versión optimista de la agenda.
 *
 * Importante: el disparador es asincrónico: la reseña puede hacerse visible
 * antes de que estos agregados se actualicen.
 */
async function recalcularIndicadoresResenas(db, codigo) {
  if (typeof codigo !== 'string' || !/^[A-Z]{3}-\d{2}$/.test(codigo)) {
    throw new TypeError('Código de deporte inválido.');
  }
  const deporteRef = db.collection('deportes').doc(codigo);
  return db.runTransaction(async (tx) => {
    // Todas las lecturas preceden a la escritura. La lectura de la consulta
    // permite obtener el estado vigente y no depender del payload del evento.
    const deporte = await tx.get(deporteRef);
    if (!deporte.exists) return { omitido: true, motivo: 'deporte-no-existe' };
    const resenas = await tx.get(deporteRef.collection('resenas'));
    const calculado = calcularIndicadoresResenas(resenas.docs);
    const original = deporte.data() || {};
    const requiereCambio =
      original.promedioCalificacion !== calculado.promedioCalificacion ||
      original.totalResenas !== calculado.totalResenas;
    if (requiereCambio) {
      tx.update(deporteRef, {
        promedioCalificacion: calculado.promedioCalificacion,
        totalResenas: calculado.totalResenas,
      });
    }
    return { ...calculado, actualizado: requiereCambio };
  });
}

module.exports = { calcularIndicadoresResenas, recalcularIndicadoresResenas };
