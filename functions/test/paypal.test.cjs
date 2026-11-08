'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validarInscripcionPagable, montoValido, montoCoincide } = require('../lib/pago.cjs');

const limite = new Date('2026-11-08T12:00:00Z');
const antes = new Date('2026-11-08T10:00:00Z');
const despues = new Date('2026-11-08T13:00:00Z');
const insc = (extra = {}) => ({
  estudianteUid: 'u1', estado: 'pendiente', fechaLimitePago: { toDate: () => limite }, ...extra,
});

test('acepta una inscripción propia, pendiente y vigente', () => {
  assert.doesNotThrow(() => validarInscripcionPagable(insc(), 'u1', antes));
});
test('rechaza una inscripción de otro estudiante', () => {
  assert.throws(() => validarInscripcionPagable(insc(), 'u2', antes), /no es tuya/);
});
test('rechaza una inscripción que ya no está pendiente', () => {
  assert.throws(() => validarInscripcionPagable(insc({ estado: 'confirmada' }), 'u1', antes), /pendiente/);
});
test('rechaza una inscripción vencida', () => {
  assert.throws(() => validarInscripcionPagable(insc(), 'u1', despues), /venció/);
});
test('rechaza una inscripción inexistente', () => {
  assert.throws(() => validarInscripcionPagable(undefined, 'u1', antes), /no es tuya/);
});
test('montoValido solo acepta números positivos', () => {
  assert.equal(montoValido(5), true);
  for (const malo of [0, -1, NaN, '5', null, undefined]) assert.equal(montoValido(malo), false);
});
test('montoCoincide tolera redondeo de centavos', () => {
  assert.equal(montoCoincide(5, 5.0), true);
  assert.equal(montoCoincide(5.001, 5), true);
  assert.equal(montoCoincide(4, 5), false);
});