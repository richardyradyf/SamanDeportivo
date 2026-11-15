import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_entrenador.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

// Lunes 16/11/2026 a las 10:00. Fijo, para que las pruebas no dependan
// del día en que se corren.
final ahora = DateTime(2026, 11, 16, 10);

Deporte deporte(
  String codigo, {
  int confirmados = 0,
  bool activo = true,
  List<HorarioSesion> horarios = const [],
}) {
  return Deporte(
    codigo: codigo,
    nombre: codigo,
    descripcion: '',
    disciplina: Disciplina.colectivo,
    costo: 10,
    cupoMaximo: 20,
    creadoEn: DateTime(2026, 10, 1),
    cuposConfirmados: confirmados,
    activo: activo,
    horarios: horarios,
    entrenadorUid: 'ent1',
  );
}

HorarioSesion sesion(DiaSemana dia, String inicio, String fin) =>
    HorarioSesion(dia: dia, horaInicio: inicio, horaFin: fin, lugar: 'Cancha');

Asistencia registro(DateTime fecha, EstadoAsistencia estado, String uid) {
  return Asistencia.registrar(
    inscripcionId: '${uid}_FUT-01',
    estudianteUid: uid,
    estudianteNombre: uid,
    deporteId: 'FUT-01',
    entrenadorUid: 'ent1',
    fecha: fecha,
    estado: estado,
  );
}

void main() {
  final futbol = deporte(
    'FUT-01',
    confirmados: 8,
    horarios: [
      sesion(DiaSemana.lunes, '16:00', '18:00'),
      sesion(DiaSemana.jueves, '16:00', '18:00'),
    ],
  );
  final natacion = deporte(
    'NAT-01',
    confirmados: 5,
    horarios: [sesion(DiaSemana.miercoles, '08:00', '09:00')],
  );
  // Inactivo y con una sesión hoy a las 12:00: no debe contar en nada.
  final inactivo = deporte(
    'VOL-01',
    confirmados: 9,
    activo: false,
    horarios: [sesion(DiaSemana.lunes, '12:00', '13:00')],
  );

  test('suma solo los deportes activos', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol, natacion, inactivo],
      asistencias: const [],
      ahora: ahora,
    );
    expect(r.disciplinas, 2);
    expect(r.inscritosConfirmados, 13);
    expect(r.sesionesPorSemana, 3);
  });

  test('el porcentaje usa solo los últimos 30 días', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol],
      asistencias: [
        registro(DateTime(2026, 11, 9), EstadoAsistencia.presente, 'a'),
        registro(DateTime(2026, 11, 9), EstadoAsistencia.presente, 'b'),
        registro(DateTime(2026, 11, 2), EstadoAsistencia.presente, 'a'),
        registro(DateTime(2026, 11, 2), EstadoAsistencia.ausente, 'b'),
        registro(DateTime(2026, 10, 1), EstadoAsistencia.ausente, 'a'),
      ],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, 75);
  });

  test('sin registros el porcentaje es null, no 0', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol],
      asistencias: const [],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, isNull);
  });

  test('la próxima sesión ignora los deportes inactivos', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol, natacion, inactivo],
      asistencias: const [],
      ahora: ahora,
    );
    expect(r.proxima!.deporte.codigo, 'FUT-01');
    expect(r.proxima!.inicio, DateTime(2026, 11, 16, 16));
  });

  test('sin deportes todo queda en cero', () {
    final r = ResumenEntrenador.calcular(
      deportes: const [],
      asistencias: const [],
      ahora: ahora,
    );
    expect(r.disciplinas, 0);
    expect(r.inscritosConfirmados, 0);
    expect(r.proxima, isNull);
  });
}
