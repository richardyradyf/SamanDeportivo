
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/controllers/registro_controller.dart';

void main() {
  late RegistroController controller;

  setUp(() {
    controller = RegistroController();
  });

  tearDown(() {
    controller.dispose();
  });

  // Datos válidos utilizados como punto de partida.
  String? validar({
    String nombre = 'Mariana Perez',
    String cedula = '12345678',
    String carnet = '20260001',
    String correo = 'estudiante@unimet.edu.ve',
    String contrasena = 'Clave123',
  }) {
    return controller.validarDatos(
      nombre: nombre,
      cedula: cedula,
      carnet: carnet,
      correo: correo,
      contrasena: contrasena,
    );
  }

  group('Validaciones compatibles con Firestore', () {
    test('Acepta datos válidos', () {
      expect(validar(), isNull);
    });

    test('Rechaza cédula con menos de 5 dígitos', () {
      expect(
        validar(cedula: '1234'),
        'La cédula debe tener entre 5 y 20 dígitos',
      );
    });

    test('Rechaza cédula con más de 20 dígitos', () {
      expect(
        validar(cedula: '123456789012345678901'),
        'La cédula debe tener entre 5 y 20 dígitos',
      );
    });

    test('Acepta cédula de exactamente 5 dígitos', () {
      expect(validar(cedula: '12345'), isNull);
    });

    test('Rechaza carnet demasiado corto', () {
      expect(
        validar(carnet: '123'),
        contains('entre 4 y 24 caracteres'),
      );
    });

    test('Rechaza carnet demasiado largo', () {
      expect(
        validar(carnet: '1234567890123456789012345'),
        contains('entre 4 y 24 caracteres'),
      );
    });

    test('Rechaza caracteres especiales en el carnet', () {
      expect(
        validar(carnet: '2026/001'),
        contains('letras, números o guiones'),
      );
    });

    test('Acepta carnet con letras y guiones', () {
      expect(validar(carnet: 'UNI-2026'), isNull);
    });

    test('Rechaza nombre de más de 100 caracteres', () {
      expect(
        validar(nombre: 'Mariana ${'Perez' * 20}'),
        'El nombre no puede superar los 100 caracteres',
      );
    });

    test('Acepta correo institucional en mayúsculas', () {
      expect(
        validar(correo: 'ESTUDIANTE@UNIMET.EDU.VE'),
        isNull,
      );
    });
  });
}
