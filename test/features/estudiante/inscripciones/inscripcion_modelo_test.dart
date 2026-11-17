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
    test('La inscripción copia el teléfono del estudiante', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante.copyWith(telefono: '+584121234567'),
        deporte: deporte,
        ahora: fechaInicial,
      );

      expect(inscripcion.estudianteTelefono, '+584121234567');
      expect(inscripcion.toMap()['estudianteTelefono'], '+584121234567');
    });

    test('El teléfono se conserva al recuperar la inscripción', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante.copyWith(telefono: '+584121234567'),
        deporte: deporte,
        ahora: fechaInicial,
      );

      final recuperada = Inscripcion.fromMap(
        inscripcion.id,
        inscripcion.toMap(),
      );

      expect(recuperada.estudianteTelefono, '+584121234567');
    });

    test('Las inscripciones antiguas pueden no tener teléfono', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante,
        deporte: deporte,
        ahora: fechaInicial,
      );

      final datos = inscripcion.toMap();

      expect(datos.containsKey('estudianteTelefono'), false);

      final recuperada = Inscripcion.fromMap(inscripcion.id, datos);

      expect(recuperada.estudianteTelefono, isNull);
    });

    test('El teléfono se conserva al cambiar de estado', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante.copyWith(telefono: '+584121234567'),
        deporte: deporte,
        ahora: fechaInicial,
      );

      final confirmada = inscripcion.conEstado(
        EstadoInscripcion.confirmada,
        responsableUid: estudiante.uid,
      );

      expect(confirmada.estudianteTelefono, '+584121234567');
      expect(confirmada.id, inscripcion.id);
      expect(confirmada.estado, EstadoInscripcion.confirmada);
    });

    test('La reinscripción copia el teléfono actualizado', () {
      final inscripcion = Inscripcion.nueva(
        estudiante: estudiante.copyWith(telefono: '+584121234567'),
        deporte: deporte,
        ahora: fechaInicial,
      );

      final cancelada = inscripcion.conEstado(
        EstadoInscripcion.cancelada,
        responsableUid: estudiante.uid,
        fecha: fechaInicial.add(const Duration(hours: 1)),
      );

      final reinscripcion = cancelada.reinscribir(
        estudiante: estudiante.copyWith(telefono: '+584149876543'),
        deporte: deporte,
        ahora: fechaInicial.add(const Duration(days: 1)),
      );

      expect(reinscripcion.estudianteTelefono, '+584149876543');
      expect(reinscripcion.id, inscripcion.id);
      expect(reinscripcion.estado, EstadoInscripcion.pendiente);
      expect(reinscripcion.historial.length, 3);
    });

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
