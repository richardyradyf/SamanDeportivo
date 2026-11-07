'use strict';
const BASE = 'https://api-m.sandbox.paypal.com';

async function obtenerToken(clientId, secret) {
  const r = await fetch(`${BASE}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + Buffer.from(`${clientId}:${secret}`).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  if (!r.ok) throw new Error('No se pudo autenticar con PayPal.');
  return (await r.json()).access_token;
}

async function crearOrden(token, { inscripcionId, descripcion, monto, urlRetorno }) {
  const r = await fetch(`${BASE}/v2/checkout/orders`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      intent: 'CAPTURE',
      purchase_units: [{
        custom_id: inscripcionId,
        description: descripcion,
        amount: { currency_code: 'USD', value: monto.toFixed(2) },
      }],
      payment_source: { paypal: { experience_context: {
        return_url: `${urlRetorno}?estado=aprobado`,
        cancel_url: `${urlRetorno}?estado=cancelado`,
        user_action: 'PAY_NOW',
        shipping_preference: 'NO_SHIPPING',
      } } },
    }),
  });
  const orden = await r.json();
  if (!r.ok) throw new Error('PayPal no creó la orden.');
  const enlace = orden.links.find((l) => l.rel === 'payer-action' || l.rel === 'approve');
  return { orderId: orden.id, urlAprobacion: enlace.href };
}

/** Devuelve { completado, captureId, monto } o lanza 'ORDER_NOT_APPROVED'. */
async function capturarOrden(token, orderId) {
  const r = await fetch(`${BASE}/v2/checkout/orders/${orderId}/capture`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: '{}',
  });
  const datos = await r.json();
  if (!r.ok) throw new Error(datos.details?.[0]?.issue ?? 'ERROR_PAYPAL');
  const captura = datos.purchase_units[0].payments.captures[0];
  return {
    completado: datos.status === 'COMPLETED' && captura.status === 'COMPLETED',
    captureId: captura.id,
    monto: Number(captura.amount.value),
  };
}

module.exports = { obtenerToken, crearOrden, capturarOrden };