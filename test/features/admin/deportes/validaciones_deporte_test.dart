import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/deportes/data/validaciones_deporte.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

void main() {
  final base = deportesDePrueba().first;

  test('deporte válido supera las validaciones', () {
    expect(() => ValidacionesDeporte.validarCreacion(base), returnsNormally);
  });

  test('rechaza un código con formato inválido', () {
    final invalido = Deporte.fromMap('fut-01', base.toMap());
    expect(() => ValidacionesDeporte.validar(invalido), throwsArgumentError);
  });

  test('rechaza nombre vacío', () {
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(nombre: '  ')),
      throwsArgumentError,
    );
  });

  test('rechaza cupos cero', () {
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(cupoMaximo: 0)),
      throwsArgumentError,
    );
  });

  test('rechaza costo negativo', () {
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(costo: -2)),
      throwsArgumentError,
    );
  });

  test('rechaza contador de confirmadas mayor que ocupadas', () {
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(cuposConfirmados: 1)),
      throwsArgumentError,
    );
  });

  test('rechaza horarios con fin anterior al inicio', () {
    final horario = const HorarioSesion(
      dia: DiaSemana.lunes,
      horaInicio: '18:00',
      horaFin: '17:00',
      lugar: 'Cancha',
    );
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(horarios: [horario])),
      throwsArgumentError,
    );
  });

  test('rechaza horarios que se cruzan el mismo día', () {
    final horarios = [
      const HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'A',
      ),
      const HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '17:00',
        horaFin: '19:00',
        lugar: 'B',
      ),
    ];
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(horarios: horarios)),
      throwsArgumentError,
    );
  });

  test('acepta horarios contiguos el mismo día', () {
    final horarios = [
      const HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'A',
      ),
      const HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '18:00',
        horaFin: '19:00',
        lugar: 'B',
      ),
    ];
    expect(
      () => ValidacionesDeporte.validar(base.copyWith(horarios: horarios)),
      returnsNormally,
    );
  });

  test('rechaza cupos ocupados al crear un deporte', () {
    expect(
      () =>
          ValidacionesDeporte.validarCreacion(base.copyWith(cuposOcupados: 1)),
      throwsArgumentError,
    );
  });
}
