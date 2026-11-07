import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

Deporte _conCupos(int maximo, int ocupados) => Deporte(
  codigo: 'FUT-01',
  nombre: 'Fútbol sala',
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: maximo,
  cuposOcupados: ocupados,
  creadoEn: DateTime(2026, 11, 1),
);

HorarioSesion _sesion(DiaSemana dia, String inicio) =>
    HorarioSesion(dia: dia, horaInicio: inicio, horaFin: '23:00', lugar: '');

void main() {
  group('Cupos', () {
    test('estado según los cupos libres', () {
      expect(EstadoCupos.de(_conCupos(20, 0)), EstadoCupos.disponible);
      expect(EstadoCupos.de(_conCupos(20, 17)), EstadoCupos.pocos);
      expect(EstadoCupos.de(_conCupos(20, 20)), EstadoCupos.completo);
    });

    test('texto en singular, plural y sin cupos', () {
      expect(textoCupos(_conCupos(20, 0)), '20 cupos disponibles');
      expect(textoCupos(_conCupos(20, 19)), '1 cupo disponible');
      expect(textoCupos(_conCupos(20, 20)), 'Sin cupos');
    });
  });

  group('Resumen de horarios', () {
    test('une los días en orden cuando empiezan a la misma hora', () {
      final resumen = resumenHorarios([
        _sesion(DiaSemana.miercoles, '16:00'),
        _sesion(DiaSemana.lunes, '16:00'),
      ]);

      expect(resumen, 'Lun / Mié · 16:00');
    });

    test('con horas distintas muestra la primera y "y más"', () {
      final resumen = resumenHorarios([
        _sesion(DiaSemana.jueves, '18:00'),
        _sesion(DiaSemana.martes, '17:00'),
      ]);

      expect(resumen, 'Mar / Jue · 17:00 y más');
    });

    test('sin sesiones avisa que falta el horario', () {
      expect(resumenHorarios(const []), 'Horario por definir');
    });
  });
}
