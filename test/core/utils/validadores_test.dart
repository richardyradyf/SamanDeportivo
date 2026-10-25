import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/utils/validadores.dart';

void main() {
  group('Validadores.correo', () {
    test('rechaza vacío, nulo y solo espacios', () {
      expect(Validadores.correo(null), 'Ingresa tu correo');
      expect(Validadores.correo(''), 'Ingresa tu correo');
      expect(Validadores.correo('   '), 'Ingresa tu correo');
    });

    test('rechaza correos sin forma de correo', () {
      expect(Validadores.correo('ana'), 'Ingresa un correo válido');
      expect(Validadores.correo('ana@'), 'Ingresa un correo válido');
      expect(Validadores.correo('ana@unimet'), 'Ingresa un correo válido');
      expect(Validadores.correo('ana perez@correo.unimet.edu.ve'),
          'Ingresa un correo válido');
    });

    test('acepta correos válidos, con espacios alrededor', () {
      expect(Validadores.correo('ana@correo.unimet.edu.ve'), isNull);
      expect(Validadores.correo('  ana@correo.unimet.edu.ve  '), isNull);
    });

    test('no exige dominio UNIMET (entrenadores y admin)', () {
      expect(Validadores.correo('entrenador@gmail.com'), isNull);
    });
  });

  group('Validadores.contrasenaLogin', () {
    test('rechaza vacío y nulo', () {
      expect(Validadores.contrasenaLogin(null), 'Ingresa tu contraseña');
      expect(Validadores.contrasenaLogin(''), 'Ingresa tu contraseña');
    });

    test('acepta cualquier texto no vacío', () {
      expect(Validadores.contrasenaLogin('abc'), isNull);
    });
  });
}
