import assert from 'node:assert/strict';
import {before, test} from 'node:test';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';

// TEST EXCLUSIVAMENTE DE EMULADOR: se niega a ejecutar si falta alguna variable.
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const dbHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!authHost || !dbHost) throw new Error('Ejecuta con npm run test:a2:emulator: se requieren Auth y Firestore Emulator.');
const project = process.env.GCLOUD_PROJECT ?? 'demo-saman-perfil';
const app = initializeApp({projectId:project},'pruebas-a2-backend');
const auth = getAuth(app);
const db = getFirestore(app);
const pass='Prueba123!';
const base = `http://127.0.0.1:5001/${project}/us-central1`;
const h=(dia,horaInicio,horaFin,lugar='Cancha A')=>({dia,horaInicio,horaFin,lugar});
const sport=(codigo, nombre)=>({
 codigo,nombre,descripcion:'Deporte de prueba',disciplina:'colectivo',costo:0,imagenUrl:null,
 cupoMaximo:20,cuposOcupados:0,cuposConfirmados:0,entrenadorUid:null,
 entrenadorNombre:null,entrenadorEspecialidad:null,horarios:[],dias:[],activo:true,
 promedioCalificacion:0,totalResenas:0,creadoEn:Timestamp.now(),actualizadoEn:null,
});
async function signIn(email) {
  const r=await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,{
    method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({email,password:pass,returnSecureToken:true}),
  });
  const data=await r.json();
  assert.ok(r.ok,JSON.stringify(data));
  return data.idToken;
}
async function call(name,data,token) {
  const r=await fetch(`${base}/${name}`,{
    method:'POST',headers:{'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},
    body:JSON.stringify({data}),
  });
  return {status:r.status,body:await r.json()};
}
let adminToken,studentToken;
before(async()=>{
  await auth.createUser({uid:'admin-a2',email:'admin-a2@test.local',password:pass});
  await auth.createUser({uid:'student-a2',email:'student-a2@test.local',password:pass});
  await auth.createUser({uid:'coach-a2',email:'coach-a2@test.local',password:pass});
  await db.doc('usuarios/admin-a2').set({nombre:'Admin',correo:'admin-a2@test.local',rol:'administrador'});
  await db.doc('usuarios/student-a2').set({nombre:'Estudiante',correo:'student-a2@test.local',rol:'estudiante'});
  await db.doc('usuarios/coach-a2').set({nombre:'Coach A2',correo:'coach-a2@test.local',rol:'entrenador',cedula:'90000114',especialidad:'Fútbol',aniosExperiencia:3});
  await db.doc('cedulas/90000114').set({uid:'coach-a2'});
  await db.doc('deportes/FUT-11').set(sport('FUT-11','Fútbol sala'));
  await db.doc('deportes/TEN-11').set(sport('TEN-11','Tenis'));
  adminToken=await signIn('admin-a2@test.local');
  studentToken=await signIn('student-a2@test.local');
});

test('sin autenticación no crea entrenador',async()=>{
 const r=await call('crearEntrenador',{nombre:'Nuevo Coach',correo:'nuevo1@test.local',cedula:'90000111',especialidad:'Tenis',aniosExperiencia:2});
 assert.equal(r.body.error?.status,'UNAUTHENTICATED');
});
test('estudiante no crea entrenador',async()=>{
 const r=await call('crearEntrenador',{nombre:'Nuevo Coach',correo:'nuevo2@test.local',cedula:'90000112',especialidad:'Tenis',aniosExperiencia:2},studentToken);
 assert.equal(r.body.error?.status,'PERMISSION_DENIED');
});
test('administrador crea entrenador con UID, rol e índice de cédula',async()=>{
 const r=await call('crearEntrenador',{nombre:'Nuevo Coach',correo:'nuevo3@test.local',cedula:'90000113',especialidad:'Tenis',aniosExperiencia:2},adminToken);
 assert.equal(r.status,200,JSON.stringify(r.body));
 const uid=r.body.result.uid;
 assert.ok(uid);
 assert.equal((await db.doc(`usuarios/${uid}`).get()).get('rol'),'entrenador');
 assert.equal((await db.doc('cedulas/90000113').get()).get('uid'),uid);
 assert.ok((await auth.getUser(uid)).email==='nuevo3@test.local');
});
test('rechaza duplicación de cédula (incluso con correo diferente)',async()=>{
 const r=await call('crearEntrenador',{nombre:'Coach Segundo',correo:'nuevo4@test.local',cedula:'90000113',especialidad:'Tenis',aniosExperiencia:2},adminToken);
 assert.equal(r.body.error?.status,'ALREADY_EXISTS');
});
test('rechaza la cédula de un entrenador preexistente',async()=>{
 const r=await call('crearEntrenador',{
  nombre:'Coach Repetido',correo:'entrenador-repetido@test.local',
  cedula:'90000114',especialidad:'Natación',aniosExperiencia:1
 },adminToken);
 assert.equal(r.body.error?.status,'ALREADY_EXISTS');
});
test('estudiante no modifica agendas vía callable',async()=>{
 const r=await call('guardarAgendaDeporte',{codigoDeporte:'FUT-11',entrenadorUid:'coach-a2',horarios:[h('lunes','16:00','18:00')],expectedVersion:null},studentToken);
 assert.equal(r.body.error?.status,'PERMISSION_DENIED');
});
test('dos cambios simultáneos que se solapan: exactamente uno se acepta',async()=>{
 const payload=codigo=>({codigoDeporte:codigo,entrenadorUid:'coach-a2',horarios:[h('lunes','16:00','18:00')],expectedVersion:null});
 const results=await Promise.all([call('guardarAgendaDeporte',payload('FUT-11'),adminToken),call('guardarAgendaDeporte',payload('TEN-11'),adminToken)]);
 assert.equal(results.filter(x=>x.status===200).length,1,JSON.stringify(results));
 const sports=await Promise.all(['FUT-11','TEN-11'].map(c=>db.doc(`deportes/${c}`).get()));
 assert.equal(sports.filter(s=>s.get('entrenadorUid')==='coach-a2').length,1);
});
