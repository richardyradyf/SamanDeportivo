import 'package:flutter_test/flutter_test.dart';
// Ajustar el nombre del paquete al `name:` real del pubspec.yaml de Richard.
import 'package:saman_deportivo/features/perfil/domain/perfil_usuario.dart';

void main() {
  final base = <String, dynamic>{
    'cedula': '12345678',
    'nombre': 'Alexander Ramírez',
    'correo': 'alexander@unimet.edu.ve',
    'rol': 'estudiante',
    'carnet': '202611111',
    'estado': 'activo',
  };

  test('crea un estudiante y calcula iniciales', () {
    final perfil = PerfilUsuario.fromMap('uid-1', base);
    expect(perfil.rol, RolPerfil.estudiante);
    expect(perfil.iniciales, 'AR');
    expect(perfil.carnet, '202611111');
  });

  test('rechaza rol desconocido sin otorgar privilegios', () {
    expect(
      () => PerfilUsuario.fromMap('uid-1', {...base, 'rol': 'superadmin'}),
      throwsFormatException,
    );
  });

  test('rechaza estudiante sin carnet', () {
    expect(
      () => PerfilUsuario.fromMap('uid-1', {...base}..remove('carnet')),
      throwsFormatException,
    );
  });

  test('acepta perfil de entrenador', () {
    final perfil = PerfilUsuario.fromMap('uid-entrenador', {
      'cedula': '12345679',
      'nombre': 'María Pérez',
      'correo': 'maria@unimet.edu.ve',
      'rol': 'entrenador',
      'especialidad': 'Baloncesto',
      'aniosExperiencia': 5,
    });
    expect(perfil.nombreRol, 'Entrenador');
    expect(perfil.aniosExperiencia, 5);
  });
}
