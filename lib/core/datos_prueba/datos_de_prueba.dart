import '../../models/deporte.dart';
import '../../models/entrenador.dart';
import '../../models/enums.dart';
import '../../models/horario_sesion.dart';

/// Datos de prueba del Hito 3, en memoria, para armar pantallas y pruebas
/// sin conectarse a Firebase.
///
/// Para tenerlos en Firestore se usa SOLO el emulador:
/// `npm run emulador` y `npm run emulador:datos`
/// (script `scripts/cargar_datos_emulador.mjs`, con los mismos deportes).
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
