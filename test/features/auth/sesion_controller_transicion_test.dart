import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/controllers/sesion_controller.dart';

void main() {
  const gracia = Duration(seconds: 5);

  Map<String, dynamic> datosEstudiante(String nombre) => {
    'rol': 'estudiante',
    'cedula': '28123456',
    'nombre': nombre,
    'correo': 'estudiante@correo.unimet.edu.ve',
    'carnet': '20260001',
    'estado': 'activo',
  };

  testWidgets('un perfil que aparece después de Auth nunca muestra error', (
    tester,
  ) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = StreamController<Map<String, dynamic>?>.broadcast(
      sync: true,
    );
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (_) => perfiles.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      await perfiles.close();
    });

    auth.add('uid-nuevo');
    perfiles.add(null); // El perfil aún no termina de guardarse.
    await tester.pump(const Duration(seconds: 3));
    expect(sesion.estado, EstadoSesion.cargando);
    expect(sesion.error, isNull);

    perfiles.add(datosEstudiante('Estudiante Nuevo'));
    await tester.pump();
    expect(sesion.estado, EstadoSesion.autenticado);
    expect(sesion.persona?.nombre, 'Estudiante Nuevo');

    await tester.pump(const Duration(seconds: 8));
    expect(sesion.estado, EstadoSesion.autenticado);
  });

  testWidgets('si realmente falta el perfil muestra error después de gracia', (
    tester,
  ) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = StreamController<Map<String, dynamic>?>.broadcast(
      sync: true,
    );
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (_) => perfiles.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      await perfiles.close();
    });

    auth.add('uid-sin-perfil');
    perfiles.add(null);
    await tester.pump(const Duration(seconds: 4));
    expect(sesion.estado, EstadoSesion.cargando);

    await tester.pump(const Duration(seconds: 1));
    expect(sesion.estado, EstadoSesion.sinPerfil);
    expect(sesion.error, contains('aún no tiene un perfil'));
  });

  testWidgets('si el perfil llega tarde, la sesión se recupera', (
    tester,
  ) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = StreamController<Map<String, dynamic>?>.broadcast(
      sync: true,
    );
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (_) => perfiles.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      await perfiles.close();
    });

    auth.add('uid-lento');
    perfiles.add(null);
    await tester.pump(gracia);
    expect(sesion.estado, EstadoSesion.sinPerfil);

    perfiles.add(datosEstudiante('Estudiante Recuperado'));
    await tester.pump();
    expect(sesion.estado, EstadoSesion.autenticado);
    expect(sesion.error, isNull);
    expect(sesion.persona?.nombre, 'Estudiante Recuperado');
  });

  testWidgets('al cambiar de usuario no se ejecutan temporizadores viejos', (
    tester,
  ) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = <String, StreamController<Map<String, dynamic>?>>{
      'uid-1': StreamController<Map<String, dynamic>?>.broadcast(sync: true),
      'uid-2': StreamController<Map<String, dynamic>?>.broadcast(sync: true),
    };
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (uid) => perfiles[uid]!.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      for (final controlador in perfiles.values) {
        await controlador.close();
      }
    });

    auth.add('uid-1');
    perfiles['uid-1']!.add(null);
    await tester.pump(const Duration(seconds: 3));
    auth.add('uid-2');
    perfiles['uid-2']!.add(datosEstudiante('Estudiante Dos'));
    await tester.pump(const Duration(seconds: 8));

    expect(sesion.estado, EstadoSesion.autenticado);
    expect(sesion.persona?.uid, 'uid-2');
  });

  testWidgets('cerrar sesión cancela la espera por el perfil', (tester) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = StreamController<Map<String, dynamic>?>.broadcast(
      sync: true,
    );
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (_) => perfiles.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      await perfiles.close();
    });

    auth.add('uid-1');
    perfiles.add(null);
    auth.add(null);
    await tester.pump(const Duration(seconds: 8));

    expect(sesion.estado, EstadoSesion.sinSesion);
    expect(sesion.error, isNull);
  });

  testWidgets('un perfil corrupto sí muestra error inmediato', (tester) async {
    final auth = StreamController<String?>.broadcast(sync: true);
    final perfiles = StreamController<Map<String, dynamic>?>.broadcast(
      sync: true,
    );
    final sesion = SesionController(
      cambiosUid: auth.stream,
      observarDatosPerfil: (_) => perfiles.stream,
      cerrarSesion: () async {},
      graciaPerfil: gracia,
    );
    addTearDown(() async {
      sesion.dispose();
      await auth.close();
      await perfiles.close();
    });

    auth.add('uid-corrupto');
    perfiles.add({'rol': 'desconocido'});
    await tester.pump();

    expect(sesion.estado, EstadoSesion.sinPerfil);
    expect(sesion.error, contains('datos inválidos'));
  });
}
