import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

void main() {
  final estudiante = const Estudiante(
    uid: 'est1',
    cedula: '28000000',
    nombre: 'Ana Pérez',
    correo: 'ana@correo.unimet.edu.ve',
    carnet: '20231234',
  );

  group('HorarioSesion', () {
    const lunes16a18 = HorarioSesion(
      dia: DiaSemana.lunes, horaInicio: '16:00', horaFin: '18:00', lugar: 'A');

    test('detecta horarios solapados el mismo día', () {
      const lunes17a19 = HorarioSesion(
        dia: DiaSemana.lunes, horaInicio: '17:00', horaFin: '19:00', lugar: 'B');
      expect(lunes16a18.seCruzaCon(lunes17a19), isTrue);
    });

    test('no hay cruce si uno empieza cuando el otro termina', () {
      const lunes18a20 = HorarioSesion(
        dia: DiaSemana.lunes, horaInicio: '18:00', horaFin: '20:00', lugar: 'B');
      expect(lunes16a18.seCruzaCon(lunes18a20), isFalse);
    });

    test('no hay cruce en días distintos', () {
      const martes16a18 = HorarioSesion(
        dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'A');
      expect(lunes16a18.seCruzaCon(martes16a18), isFalse);
    });
  });

  group('Deporte', () {
    test('toMap y fromMap conservan los datos', () {
      final original = deportesDePrueba().first;
      final copia = Deporte.fromMap(original.codigo, original.toMap());

      expect(copia.codigo, original.codigo);
      expect(copia.nombre, original.nombre);
      expect(copia.cupoMaximo, original.cupoMaximo);
      expect(copia.horarios.length, original.horarios.length);
      expect(copia.toMap()['dias'], ['lunes', 'miercoles']);
    });

    test('calcula los cupos disponibles', () {
      final tenis = deportesDePrueba().firstWhere((d) => d.codigo == 'TEN-01');
      expect(tenis.cuposDisponibles, 2);
      expect(tenis.copyWith(cuposOcupados: 2).tieneCupo, isFalse);
    });

    test('los códigos de prueba tienen el formato correcto', () {
      for (final deporte in deportesDePrueba()) {
        expect(Deporte.formatoCodigo.hasMatch(deporte.codigo), isTrue);
      }
    });
  });

  group('Inscripcion', () {
    final deporte = deportesDePrueba().first;
    final ahora = DateTime(2026, 11, 5, 10);

    test('nace pendiente, con ID compuesto y plazo de 24 h', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante, deporte: deporte, ahora: ahora);

      expect(inscripcion.id, 'est1_FUT-01');
      expect(inscripcion.estado, EstadoInscripcion.pendiente);
      expect(inscripcion.ocupaCupo, isTrue);
      expect(inscripcion.fechaLimitePago, DateTime(2026, 11, 6, 10));
      expect(inscripcion.historial.length, 1);
    });

    test('vence solo si sigue pendiente después del plazo', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante, deporte: deporte, ahora: ahora);
      final despues = DateTime(2026, 11, 6, 11);

      expect(inscripcion.estaVencida(despues), isTrue);
      final confirmada = inscripcion.conEstado(
        EstadoInscripcion.confirmada, responsableUid: 'est1', pagoId: 'p1');
      expect(confirmada.estaVencida(despues), isFalse);
    });

    test('cada cambio de estado queda en el historial', () {
      final cancelada = Inscripcion.nueva(
              estudiante: estudiante, deporte: deporte, ahora: ahora)
          .conEstado(EstadoInscripcion.cancelada, responsableUid: 'est1');

      expect(cancelada.ocupaCupo, isFalse);
      expect(cancelada.historial.map((c) => c.estado), [
        EstadoInscripcion.pendiente,
        EstadoInscripcion.cancelada,
      ]);

      final copia = Inscripcion.fromMap(cancelada.id, cancelada.toMap());
      expect(copia.historial.length, 2);
    });
  });

  test('Asistencia usa un ID por deporte, día y estudiante', () {
    final asistencia = Asistencia.registrar(
      inscripcionId: 'est1_FUT-01',
      estudianteUid: 'est1',
      estudianteNombre: 'Ana Pérez',
      deporteId: 'FUT-01',
      entrenadorUid: 'ent1',
      fecha: DateTime(2026, 11, 9, 16, 30),
      estado: EstadoAsistencia.presente,
    );

    expect(asistencia.id, 'FUT-01_2026-11-09_est1');
    expect(asistencia.fecha, DateTime(2026, 11, 9));
  });
}
