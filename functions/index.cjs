'use strict';
const {onCall,HttpsError} = require('firebase-functions/v2/https');
const {initializeApp,getApps} = require('firebase-admin/app');
const {getFirestore,FieldValue} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {validarEntrenador,validarSolicitudAgenda,seCruzan} = require('./lib/validaciones.cjs');
if (getApps().length === 0) initializeApp();
const db = getFirestore();
const callableOptions = {region:'us-central1', maxInstances:10};

async function exigirAdministrador(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated','Inicia sesión.');
  const doc = await db.collection('usuarios').doc(request.auth.uid).get();
  if (!doc.exists || doc.get('rol') !== 'administrador') throw new HttpsError('permission-denied','Solo administradores pueden realizar esta operación.');
}
function errorNegocio(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof Error && /inválid|inval|solapad|exist|ocupa|modificada|sesión|duplicad|registrad|cédula|email|correo/i.test(error.message)) {
    return new HttpsError('failed-precondition',error.message);
  }
  console.error('Operación administrativa fallida:', error);
  return new HttpsError('internal','No se pudo completar la operación.');
}

/** Crea usuario Auth + perfil de entrenador e índice de cédula. El enlace no se envía por email automáticamente. */
exports.crearEntrenador = onCall(callableOptions, async (request) => {
  await exigirAdministrador(request);
  let input;
  try { input = validarEntrenador(request.data); } catch (err) {throw new HttpsError('invalid-argument',err.message);}
  let creado;
  try {
    creado = await getAuth().createUser({email:input.correo,displayName:input.nombre,emailVerified:false});
    const indexRef = db.collection('cedulas').doc(input.cedula);
    const userRef = db.collection('usuarios').doc(creado.uid);
    await db.runTransaction(async (tx) => {
      const existente = await tx.get(indexRef);
      if (existente.exists) throw new HttpsError('already-exists','La cédula ya está registrada.');
      tx.create(indexRef,{uid:creado.uid});
      tx.create(userRef,{
        nombre:input.nombre,cedula:input.cedula,correo:input.correo,
        rol:'entrenador',especialidad:input.especialidad,aniosExperiencia:input.aniosExperiencia,
      });
    });
  } catch (error) {
    if (creado) {
      try {await getAuth().deleteUser(creado.uid);} catch (rollbackError) {console.error('Revisar rollback de usuario:',rollbackError);}
    }
    if (error.code === 'auth/email-already-exists') throw new HttpsError('already-exists','El correo ya está registrado.');
    throw errorNegocio(error);
  }
  // El Auth Emulator puede devolver links de acción locales. No imprimirlos en logs.
  let enlaceInvitacion = null;
  try {enlaceInvitacion = await getAuth().generatePasswordResetLink(input.correo);}
  catch (e) {console.warn('No se pudo generar invitación; utilizar recuperar contraseña.');}
  return {uid:creado.uid,enlaceInvitacion};
});

/** Permite volver a generar una invitación en caso de falla del primer intento. */
exports.generarInvitacionEntrenador = onCall(callableOptions,async (request)=>{
  await exigirAdministrador(request);
  const uid=request.data?.uid;
  if (typeof uid !== 'string' || uid.length < 2 || uid.length > 128) throw new HttpsError('invalid-argument','UID inválido.');
  const usuario=await db.collection('usuarios').doc(uid).get();
  if (!usuario.exists || usuario.get('rol') !== 'entrenador') throw new HttpsError('not-found','Entrenador no encontrado.');
  try {return {enlaceInvitacion:await getAuth().generatePasswordResetLink(usuario.get('correo'))};}
  catch (_) {throw new HttpsError('unavailable','No se pudo generar la invitación.');}
});

/** Altera entrenador + horarios de un deporte dentro de una única transacción serializada.
 * Todas las operaciones de agenda leen y escriben el mismo documento de bloqueo.
 * Firestore reintenta las operaciones concurrentes, y la segunda vuelve a validar conflictos.
 */
exports.guardarAgendaDeporte = onCall(callableOptions, async (request) => {
  await exigirAdministrador(request);
  let input;
  try {input=validarSolicitudAgenda(request.data);} catch(e) {throw new HttpsError('invalid-argument',e.message);}
  const sportRef=db.collection('deportes').doc(input.codigoDeporte);
  const lockRef=db.collection('configuracion').doc('agendaEntrenadores');
  try {
    await db.runTransaction(async tx => {
      // TODAS las lecturas antes de escribir.
      await tx.get(lockRef);
      const sport=await tx.get(sportRef);
      if (!sport.exists) throw new HttpsError('not-found','El deporte no existe.');
      const timestamp=sport.get('actualizadoEn');
      const version=timestamp && typeof timestamp.toMillis === 'function' ? timestamp.toMillis():null;
      if (version !== input.expectedVersion) throw new HttpsError('aborted','La agenda fue modificada; actualiza la pantalla e inténtalo de nuevo.');
      let coach=null;
      let others=[];
      if (input.entrenadorUid !== null) {
        const coachDoc=await tx.get(db.collection('usuarios').doc(input.entrenadorUid));
        if (!coachDoc.exists || coachDoc.get('rol') !== 'entrenador') throw new HttpsError('failed-precondition','El usuario no es un entrenador válido.');
        coach=coachDoc.data();
        const agenda=await tx.get(db.collection('deportes').where('entrenadorUid','==',input.entrenadorUid));
        others=agenda.docs.filter(d=>d.id!==input.codigoDeporte);
      }
      for (const other of others) {
        for(const proposed of input.horarios) {
          for(const existing of (other.get('horarios') || [])) {
            if (seCruzan(proposed,existing)) throw new HttpsError('failed-precondition',`El entrenador ya tiene una sesión en ${other.get('nombre')||other.id}.`);
          }
        }
      }
      tx.set(lockRef,{version:FieldValue.increment(1),actualizadoEn:FieldValue.serverTimestamp()},{merge:true});
      tx.update(sportRef,{
        entrenadorUid:input.entrenadorUid,
        entrenadorNombre:coach?.nombre ?? null,
        entrenadorEspecialidad:coach?.especialidad ?? null,
        horarios:input.horarios,
        dias:[...new Set(input.horarios.map(h=>h.dia))],
        actualizadoEn:FieldValue.serverTimestamp(),
      });
    });
    return {ok:true};
  } catch(error) {throw errorNegocio(error);}
});
