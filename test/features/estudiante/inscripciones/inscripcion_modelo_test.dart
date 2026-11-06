import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

void main() {
  late Estudiante estudiante;
  late Deporte deporte;
  late DateTime fechaInicial;

  setUp(() {
    fechaInicial = DateTime(2026, 11, 6, 10);

    estudiante = const Estudiante(
      uid: 'EST001',
      cedula: '12345678',
      nombre: 'Estudiante Prueba',
      correo: 'prueba@unimet.edu.ve',
      carnet: '20260001',
    );

    deporte = Deporte(
      codigo: 'TEN-01',
      nombre: 'Tenis',
      descripcion: 'Clases de tenis',
      disciplina: Disciplina.raqueta,
      costo: 15,
      cupoMaximo: 2,
      creadoEn: fechaInicial,
    );
  });

  group('Reglas del modelo oficial de inscripciones', () {
    test('Genera un identificador único por estudiante y deporte', () {
      final id = Inscripcion.idPara(estudiante.uid, deporte.codigo);

      expect(id, 'EST001_TEN-01');
    });

    test('Una inscripción nueva comienza pendiente', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante,
        deporte: deporte,
        ahora: fechaInicial,
      );

      expect(inscripcion.estado, EstadoInscripcion.pendiente);
      expect(inscripcion.ocupaCupo, true);
      expect(inscripcion.permiteReinscripcion, false);
    });

    test('El plazo inicial de pago es de 24 horas', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante,
        deporte: deporte,
        ahora: fechaInicial,
      );

      expect(
        inscripcion.fechaLimitePago,
        fechaInicial.add(const Duration(hours: 24)),
      );
    });

    test('Una inscripción pendiente se considera vencida', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante,
        deporte: deporte,
        ahora: fechaInicial,
      );

      final fechaPosterior = fechaInicial.add(const Duration(hours: 25));

      expect(inscripcion.estaVencida(fechaPosterior), true);
    });

    test('Una inscripción cancelada permite reinscribirse', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante,
        deporte: deporte,
        ahora: fechaInicial,
      );

      final cancelada = inscripcion.conEstado(
        EstadoInscripcion.cancelada,
        responsableUid: estudiante.uid,
      );

      expect(cancelada.ocupaCupo, false);
      expect(cancelada.permiteReinscripcion, true);
    });
  });
}
