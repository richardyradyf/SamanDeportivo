'use strict';
const DIAS = new Set(['lunes','martes','miercoles','jueves','viernes','sabado','domingo']);
const HORA = /^([01]\d|2[0-3]):[0-5]\d$/;
const CODIGO = /^[A-Z]{3}-\d{2}$/;
function validarEntrenador(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Datos inválidos.');
  const nombre = String(data.nombre ?? '').trim();
  const correo = String(data.correo ?? '').trim().toLowerCase();
  const cedula = String(data.cedula ?? '').trim();
  const especialidad = String(data.especialidad ?? '').trim();
  const aniosExperiencia = data.aniosExperiencia;
  if (nombre.length < 3 || nombre.length > 100) throw new Error('Nombre inválido (3 a 100 caracteres).');
  if (correo.length > 150 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) throw new Error('Correo inválido.');
  if (!/^\d{5,20}$/.test(cedula)) throw new Error('Cédula inválida (5 a 20 dígitos).');
  if (especialidad.length < 2 || especialidad.length > 100) throw new Error('Especialidad inválida.');
  if (!Number.isInteger(aniosExperiencia) || aniosExperiencia < 0 || aniosExperiencia > 60) throw new Error('Años de experiencia inválidos (0 a 60).');
  return { nombre, correo, cedula, especialidad, aniosExperiencia };
}
function minutos(t) {return Number(t.slice(0,2))*60 + Number(t.slice(3,5));}
function normalizarHorarios(horarios) {
  if (!Array.isArray(horarios) || horarios.length > 21) throw new Error('Lista de horarios inválida (máximo 21).');
  const salida = horarios.map((h) => {
    if (!h || typeof h !== 'object' || Array.isArray(h)) throw new Error('Sesión inválida.');
    const {dia,horaInicio,horaFin} = h;
    const lugar = String(h.lugar ?? '').trim();
    if (!DIAS.has(dia) || typeof horaInicio !== 'string' || typeof horaFin !== 'string' ||
        !HORA.test(horaInicio) || !HORA.test(horaFin) || minutos(horaInicio) >= minutos(horaFin) ||
        lugar.length < 2 || lugar.length > 120) throw new Error('Horario inválido (día, HH:mm, intervalo y lugar).');
    return {dia,horaInicio,horaFin,lugar};
  });
  for (let i = 0; i < salida.length; i++) {
    for (let j = i+1; j < salida.length; j++) {
      if (seCruzan(salida[i],salida[j])) throw new Error('Horarios solapados en el mismo deporte.');
    }
  }
  return salida;
}
function seCruzan(a,b) {
  return a.dia === b.dia && minutos(a.horaInicio) < minutos(b.horaFin) && minutos(b.horaInicio) < minutos(a.horaFin);
}
function validarSolicitudAgenda(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Solicitud inválida.');
  const codigoDeporte = data.codigoDeporte;
  const entrenadorUid = data.entrenadorUid;
  if (typeof codigoDeporte !== 'string' || !CODIGO.test(codigoDeporte)) throw new Error('Código de deporte inválido.');
  if (entrenadorUid !== null && (typeof entrenadorUid !== 'string' || entrenadorUid.trim().length < 2 || entrenadorUid.length > 128)) throw new Error('Entrenador inválido.');
  if (data.expectedVersion !== null && (!Number.isSafeInteger(data.expectedVersion) || data.expectedVersion < 0)) throw new Error('Versión de agenda inválida.');
  return {codigoDeporte, entrenadorUid, horarios: normalizarHorarios(data.horarios), expectedVersion: data.expectedVersion};
}
module.exports = {validarEntrenador, normalizarHorarios, validarSolicitudAgenda, seCruzan};
