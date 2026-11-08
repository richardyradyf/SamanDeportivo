'use strict';

/** Lanza Error (en español) si la inscripción no se puede pagar ahora. */
function validarInscripcionPagable(insc, uid, ahora) {
  if (!insc || insc.estudianteUid !== uid) throw new Error('Esta inscripción no es tuya.');
  if (insc.estado !== 'pendiente') throw new Error('La inscripción ya no está pendiente.');
  const limite = insc.fechaLimitePago?.toDate?.();
  if (!limite || ahora > limite) throw new Error('El plazo de pago de esta inscripción venció.');
}

const montoValido = (costo) => typeof costo === 'number' && Number.isFinite(costo) && costo > 0;
const montoCoincide = (pagado, esperado) => Math.abs(pagado - esperado) < 0.005;

module.exports = { validarInscripcionPagable, montoValido, montoCoincide };