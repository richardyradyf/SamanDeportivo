
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

  group('Validaciones del registro', () {
    test('Acepta datos válidos de un estudiante', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana Di Buongrazio',
        cedula: '30124915',
        carnet: '20260001',
        correo: 'estudiante@correo.unimet.edu.ve',
        contrasena: 'Clave123',
      );

      expect(resultado, isNull);
    });

    test('Rechaza un nombre sin apellido', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana',
        cedula: '30124915',
        carnet: '20260001',
        correo: 'estudiante@unimet.edu.ve',
        contrasena: 'Clave123',
      );

      expect(resultado, isNotNull);
    });

    test('Rechaza cedulas con letras', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana Perez',
        cedula: 'V30124915',
        carnet: '20260001',
        correo: 'estudiante@unimet.edu.ve',
        contrasena: 'Clave123',
      );

      expect(
        resultado,
        'La cédula debe contener solo números',
      );
    });

    test('Rechaza correos que no sean UNIMET', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana Perez',
        cedula: '30124915',
        carnet: '20260001',
        correo: 'estudiante@gmail.com',
        contrasena: 'Clave123',
      );

      expect(
        resultado,
        'Debes utilizar un correo institucional UNIMET',
      );
    });

    test('Acepta el dominio unimet.edu.ve', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana Perez',
        cedula: '30124915',
        carnet: '20260001',
        correo: 'estudiante@unimet.edu.ve',
        contrasena: 'Clave123',
      );

      expect(resultado, isNull);
    });

    test('Rechaza contrasenas menores a 6 caracteres', () {
      final resultado = controller.validarDatos(
        nombre: 'Mariana Perez',
        cedula: '30124915',
        carnet: '20260001',
        correo: 'estudiante@unimet.edu.ve',
        contrasena: '123',
      );

      expect(
        resultado,
        'La contraseña debe tener al menos 6 caracteres',
      );
    });
  });

  group('Estados del controlador', () {
    test('Inicia sin errores y sin cargar', () {
      expect(controller.cargando, false);
      expect(controller.error, isNull);
      expect(controller.registroExitoso, false);
    });

    test('Permite cambiar el estado de carga', () {
      controller.cambiarCargando(true);

      expect(controller.cargando, true);
    });

    test('Permite mostrar y limpiar errores', () {
      controller.mostrarError('Correo ya registrado');

      expect(controller.error, 'Correo ya registrado');

      controller.limpiarEstado();

      expect(controller.error, isNull);
    });

    test('Permite confirmar un registro exitoso', () {
      controller.cambiarCargando(true);
      controller.confirmarRegistro();

      expect(controller.registroExitoso, true);
      expect(controller.cargando, false);
      expect(controller.error, isNull);
    });
  });
}
