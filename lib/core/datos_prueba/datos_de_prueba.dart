import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/deporte.dart';
import '../../models/entrenador.dart';
import '../../models/enums.dart';
import '../../models/horario_sesion.dart';
import '../../models/persona.dart';

/// Datos de prueba del Hito 3.
///
/// - [deportesDePrueba] sirve para armar pantallas sin conectarse a Firebase.
/// - [subirDatosDePrueba] carga esos deportes en Firestore. Se ejecuta UNA vez,
///   con sesión de administrador, porque reinicia los cupos a 0.
///
/// TEN-01 tiene cupo 2 para probar "sin cupos".
List<Deporte> deportesDePrueba({List<Entrenador> entrenadores = const []}) {
  final ahora = DateTime.now();

  final base = <Deporte>[
    Deporte(
      codigo: 'FUT-01',
      nombre: 'Fútbol sala',
      descripcion: 'Entrenamientos de fútbol sala para todos los niveles.',
      disciplina: Disciplina.colectivo,
      costo: 10,
      cupoMaximo: 20,
      creadoEn: ahora,
      horarios: const [
        HorarioSesion(dia: DiaSemana.lunes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha techada'),
        HorarioSesion(dia: DiaSemana.miercoles, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha techada'),
      ],
    ),
    Deporte(
      codigo: 'BAL-01',
      nombre: 'Baloncesto',
      descripcion: 'Fundamentos, táctica y partidos internos.',
      disciplina: Disciplina.colectivo,
      costo: 10,
      cupoMaximo: 15,
      creadoEn: ahora,
      horarios: const [
        HorarioSesion(dia: DiaSemana.martes, horaInicio: '17:00', horaFin: '19:00', lugar: 'Gimnasio cubierto'),
        HorarioSesion(dia: DiaSemana.jueves, horaInicio: '17:00', horaFin: '19:00', lugar: 'Gimnasio cubierto'),
      ],
    ),
    Deporte(
      codigo: 'TEN-01',
      nombre: 'Tenis',
      descripcion: 'Clases de tenis en grupos pequeños.',
      disciplina: Disciplina.raqueta,
      costo: 15,
      cupoMaximo: 2,
      creadoEn: ahora,
      horarios: const [
        HorarioSesion(dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '17:30', lugar: 'Canchas de tenis'),
        HorarioSesion(dia: DiaSemana.jueves, horaInicio: '16:00', horaFin: '17:30', lugar: 'Canchas de tenis'),
      ],
    ),
    Deporte(
      codigo: 'NAT-01',
      nombre: 'Natación',
      descripcion: 'Técnica de los cuatro estilos y resistencia.',
      disciplina: Disciplina.acuatico,
      costo: 12,
      cupoMaximo: 12,
      creadoEn: ahora,
      horarios: const [
        HorarioSesion(dia: DiaSemana.viernes, horaInicio: '07:00', horaFin: '09:00', lugar: 'Piscina'),
      ],
    ),
    Deporte(
      codigo: 'KAR-01',
      nombre: 'Karate',
      descripcion: 'Kata, kumite y preparación física.',
      disciplina: Disciplina.combate,
      costo: 8,
      cupoMaximo: 10,
      creadoEn: ahora,
      horarios: const [
        HorarioSesion(dia: DiaSemana.sabado, horaInicio: '09:00', horaFin: '11:00', lugar: 'Sala de combate'),
      ],
    ),
  ];

  if (entrenadores.isEmpty) return base;

  // Reparte los entrenadores en orden; los horarios ya están pensados
  // para que no se solapen con dos entrenadores.
  return [
    for (var i = 0; i < base.length; i++)
      base[i].copyWith(
        entrenadorUid: entrenadores[i % entrenadores.length].uid,
        entrenadorNombre: entrenadores[i % entrenadores.length].nombre,
        entrenadorEspecialidad: entrenadores[i % entrenadores.length].especialidad,
      ),
  ];
}

/// Sube los deportes de prueba a Firestore y les asigna los entrenadores
/// que existan en `usuarios`. Requiere sesión de administrador.
Future<void> subirDatosDePrueba(FirebaseFirestore db) async {
  final consulta = await db
      .collection('usuarios')
      .where('rol', isEqualTo: Rol.entrenador.name)
      .get();

  final entrenadores = consulta.docs
      .map((doc) => Persona.fromMap(doc.id, doc.data()))
      .whereType<Entrenador>()
      .toList();

  final lote = db.batch();
  for (final deporte in deportesDePrueba(entrenadores: entrenadores)) {
    lote.set(db.collection('deportes').doc(deporte.codigo), deporte.toMap());
  }
  await lote.commit();
}
