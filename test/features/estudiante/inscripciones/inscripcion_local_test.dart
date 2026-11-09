import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/models/inscripcion_local.dart';

void main() {
  late InscripcionLocal inscripcion;
  late DateTime fechaInicial;

  setUp(() {
    fechaInicial = DateTime(2026, 11, 6);

    inscripcion = InscripcionLocal.nueva(
      id: 'INS001',
      estudianteId: 'EST001',
      deporteId: 'FUT001',
      fecha: fechaInicial,
    );
  });

  group('Estados de inscripción', () {
    test('Una inscripción nueva comienza pendiente', () {
      expect(inscripcion.estado, EstadoInscripcion.pendiente);
      expect(inscripcion.estaVigente, true);
      expect(inscripcion.historial.length, 1);
    });

    test('Permite confirmar una inscripción pendiente', () {
      final confirmada = inscripcion.cambiarEstado(
        nuevoEstado: EstadoInscripcion.confirmada,
        fecha: fechaInicial.add(const Duration(minutes: 5)),
      );

      expect(confirmada.estado, EstadoInscripcion.confirmada);
      expect(confirmada.historial.length, 2);
    });

    test('Permite cancelar y registra el historial', () {
      final cancelada = inscripcion.cancelar(
        fechaInicial.add(const Duration(minutes: 10)),
      );

      expect(cancelada.estado, EstadoInscripcion.cancelada);
      expect(cancelada.estaVigente, false);
      expect(cancelada.historial.length, 2);
      expect(cancelada.historial.last.anterior, EstadoInscripcion.pendiente);
    });

    test('Permite expirar una inscripción pendiente', () {
      final expirada = inscripcion.expirar(
        fechaInicial.add(const Duration(minutes: 30)),
      );

      expect(expirada.estado, EstadoInscripcion.expirada);
      expect(expirada.estaVigente, false);
    });

    test('No permite cancelar dos veces', () {
      final cancelada = inscripcion.cancelar(
        fechaInicial.add(const Duration(minutes: 1)),
      );

      expect(
        () => cancelada.cancelar(fechaInicial.add(const Duration(minutes: 2))),
        throwsStateError,
      );
    });

    test('No permite confirmar una inscripción expirada', () {
      final expirada = inscripcion.expirar(
        fechaInicial.add(const Duration(minutes: 30)),
      );

      expect(
        () => expirada.cambiarEstado(
          nuevoEstado: EstadoInscripcion.confirmada,
          fecha: fechaInicial.add(const Duration(minutes: 31)),
        ),
        throwsStateError,
      );
    });
  });
}
