'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  calcularIndicadoresResenas,
  recalcularIndicadoresResenas,
} = require('../lib/indicadores_resenas.cjs');

test('A3.7: promedio solo de reseñas visibles', () => {
  assert.deepEqual(calcularIndicadoresResenas([
    { puntuacion: 5, oculta: false },
    { puntuacion: 1, oculta: true },
    { puntuacion: 3, oculta: false },
  ]), { promedioCalificacion: 4, totalResenas: 2, invalidas: 0 });
});

test('A3.7: ocultar todas deja 0 reseñas y promedio 0', () => {
  assert.deepEqual(calcularIndicadoresResenas([
    { puntuacion: 5, oculta: true },
    { puntuacion: 1, oculta: true },
  ]), { promedioCalificacion: 0, totalResenas: 0, invalidas: 0 });
});

test('A3.7: reseña histórica sin oculta se considera visible', () => {
  assert.equal(calcularIndicadoresResenas([{ puntuacion: 4 }]).totalResenas, 1);
});

test('A3.7: puntuaciones ausentes o inválidas se omiten', () => {
  assert.deepEqual(calcularIndicadoresResenas([
    { puntuacion: 5 }, { puntuacion: 9 }, { puntuacion: 3.5 },
    { puntuacion: null }, null,
  ]), { promedioCalificacion: 5, totalResenas: 1, invalidas: 4 });
});

test('A3.7: acepta DocumentSnapshot de Firestore', () => {
  assert.equal(calcularIndicadoresResenas([{ data: () => ({puntuacion: 2}) }]).promedioCalificacion, 2);
});

test('A3.7: conserva precisión de 1/3 de estrellas', () => {
  assert.equal(calcularIndicadoresResenas([
    {puntuacion: 1}, {puntuacion: 1}, {puntuacion: 2},
  ]).promedioCalificacion, 4 / 3);
});

test('A3.7: lista vacía representa 0 y no una fuente sin permisos', () => {
  assert.deepEqual(calcularIndicadoresResenas([]), {
    promedioCalificacion: 0, totalResenas: 0, invalidas: 0,
  });
});

function fakeDB({existe = true, original = {}, reseñas = []} = {}) {
  const updates = [];
  const resenasQuery = {query: 'resenas'};
  const deporteRef = {collection: (nombre) => {
    assert.equal(nombre, 'resenas');
    return resenasQuery;
  }};
  const db = {
    collection(nombre) {
      assert.equal(nombre, 'deportes');
      return {doc(codigo) {
        assert.equal(codigo, 'FUT-01');
        return deporteRef;
      }};
    },
    async runTransaction(f) {
      const tx = {
        async get(ref) {
          if (ref === deporteRef) return {exists: existe, data: () => original};
          if (ref === resenasQuery) return {docs: reseñas.map(x => ({data: () => x}))};
          throw new Error('Referencia inesperada');
        },
        update(ref, cambios) {
          assert.equal(ref, deporteRef);
          updates.push(cambios);
        },
      };
      return f(tx);
    },
  };
  return {db, updates};
}

test('A3.7: transacción actualiza solo indicadores y no versión de agenda', async () => {
  const {db,updates} = fakeDB({original: {
    promedioCalificacion: 5, totalResenas: 1,
    actualizadoEn: 'version-a2-no-tocar',
  },reseñas: [{puntuacion:5},{puntuacion:3}]});
  const resultado=await recalcularIndicadoresResenas(db,'FUT-01');
  assert.equal(resultado.actualizado,true);
  assert.deepEqual(updates,[{promedioCalificacion:4,totalResenas:2}]);
});

test('A3.7: cálculo repetido es idempotente', async () => {
  const {db,updates} = fakeDB({original: {
    promedioCalificacion: 4, totalResenas: 2,
  },reseñas:[{puntuacion:5},{puntuacion:3}]});
  const resultado=await recalcularIndicadoresResenas(db,'FUT-01');
  assert.equal(resultado.actualizado,false);
  assert.deepEqual(updates,[]);
});

test('A3.7: deporte eliminado no causa escrituras', async () => {
  const {db,updates} = fakeDB({existe:false});
  assert.deepEqual(await recalcularIndicadoresResenas(db,'FUT-01'), {
    omitido:true,motivo:'deporte-no-existe',
  });
  assert.deepEqual(updates,[]);
});

test('A3.7: código inválido se rechaza antes de tocar Firestore', async () => {
  await assert.rejects(recalcularIndicadoresResenas({},'../../../usuarios'), /inválido/);
});
