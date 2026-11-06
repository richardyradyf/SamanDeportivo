import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/utils/validaciones_inscripcion.dart';

void main() {
  group('Pruebas del modulo de inscripciones', () {
    test('Permite la inscripcion si cumple los requisitos', () {
      final resultado = ValidacionesInscripcion.validar(
        estudianteActivo: true,
        estudianteSolvente: true,
        cuposDisponibles: 5,
        tieneInscripcionVigente: false,
      );

      expect(resultado, ResultadoInscripcion.permitida);
    });

    test('Rechaza estudiantes inactivos', () {
      final resultado = ValidacionesInscripcion.validar(
        estudianteActivo: false,
        estudianteSolvente: true,
        cuposDisponibles: 5,
        tieneInscripcionVigente: false,
      );

      expect(resultado, ResultadoInscripcion.estudianteInactivo);
    });

    test('Rechaza estudiantes insolventes', () {
      final resultado = ValidacionesInscripcion.validar(
        estudianteActivo: true,
        estudianteSolvente: false,
        cuposDisponibles: 5,
        tieneInscripcionVigente: false,
      );

      expect(resultado, ResultadoInscripcion.estudianteInsolvente);
    });

    test('Rechaza inscripciones cuando no hay cupos', () {
      final resultado = ValidacionesInscripcion.validar(
        estudianteActivo: true,
        estudianteSolvente: true,
        cuposDisponibles: 0,
        tieneInscripcionVigente: false,
      );

      expect(resultado, ResultadoInscripcion.sinCupos);
    });

    test('Rechaza inscripciones duplicadas', () {
      final resultado = ValidacionesInscripcion.validar(
        estudianteActivo: true,
        estudianteSolvente: true,
        cuposDisponibles: 5,
        tieneInscripcionVigente: true,
      );

      expect(resultado, ResultadoInscripcion.inscripcionDuplicada);
    });
  });
}
