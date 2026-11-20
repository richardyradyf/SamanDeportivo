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
  DateTime? creadoEn,
}) {
  return Deporte(
    codigo: codigo,
    nombre: codigo,
    descripcion: '',
    disciplina: Disciplina.colectivo,
    costo: 10,
    cupoMaximo: 20,
    cuposConfirmados: confirmados,
    activo: activo,
    horarios: horarios,
    creadoEn: creadoEn ?? DateTime(2026, 1, 1),
    entrenadorUid: 'ent1',
  );
}

HorarioSesion sesion(DiaSemana dia, String inicio, String fin) =>
    HorarioSesion(dia: dia, horaInicio: inicio, horaFin: fin, lugar: 'Cancha');

Asistencia registro(
  DateTime fecha,
  EstadoAsistencia estado,
  String uid, {
  String deporte = 'FUT-01',
}) {
  return Asistencia.registrar(
    inscripcionId: '${uid}_$deporte',
    estudianteUid: uid,
    estudianteNombre: uid,
    deporteId: deporte,
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

  test('el porcentaje usa los últimos 3 meses', () {
    // Hace 3 meses desde el 16/11 es el 16/08.
    final r = ResumenEntrenador.calcular(
      deportes: [futbol],
      asistencias: [
        registro(DateTime(2026, 11, 9), EstadoAsistencia.presente, 'a'),
        registro(DateTime(2026, 11, 2), EstadoAsistencia.ausente, 'b'),
        registro(DateTime(2026, 9, 1), EstadoAsistencia.presente, 'a'),
        // Antes del 16/08: se ignora.
        registro(DateTime(2026, 8, 10), EstadoAsistencia.ausente, 'a'),
      ],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, 67); // 2 de 3
  });

  test('no cuenta registros anteriores a la creación del deporte', () {
    final nuevo = deporte('BAL-01', creadoEn: DateTime(2026, 11, 1));
    final r = ResumenEntrenador.calcular(
      deportes: [nuevo],
      asistencias: [
        registro(
          DateTime(2026, 11, 9),
          EstadoAsistencia.presente,
          'a',
          deporte: 'BAL-01',
        ),
        // Antes de que existiera el deporte: se ignora.
        registro(
          DateTime(2026, 10, 20),
          EstadoAsistencia.ausente,
          'a',
          deporte: 'BAL-01',
        ),
      ],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, 100);
  });

  test('ignora registros de deportes que no son suyos o están inactivos', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol, inactivo],
      asistencias: [
        registro(DateTime(2026, 11, 9), EstadoAsistencia.presente, 'a'),
        registro(
          DateTime(2026, 11, 9),
          EstadoAsistencia.ausente,
          'a',
          deporte: 'VOL-01',
        ),
        registro(
          DateTime(2026, 11, 9),
          EstadoAsistencia.ausente,
          'a',
          deporte: 'NAT-99',
        ),
      ],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, 100);
  });

  test('sin registros el porcentaje es 0', () {
    final r = ResumenEntrenador.calcular(
      deportes: [futbol],
      asistencias: const [],
      ahora: ahora,
    );
    expect(r.porcentajeAsistencia, 0);
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
