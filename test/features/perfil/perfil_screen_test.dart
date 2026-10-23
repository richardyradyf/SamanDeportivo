import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Ajustar el nombre del paquete al `name:` real del pubspec.yaml de Richard.
import 'package:saman_deportivo/features/perfil/domain/perfil_usuario.dart';
import 'package:saman_deportivo/features/perfil/data/perfil_repository.dart';
import 'package:saman_deportivo/features/perfil/presentation/perfil_screen.dart';

class RepositorioFalso implements PerfilRepository {
  RepositorioFalso(this.perfil);

  PerfilUsuario perfil;
  String? nombreGuardado;
  String? carnetGuardado;

  @override
  Stream<PerfilUsuario?> observarPerfil(String uid) => Stream.value(perfil);

  @override
  Future<void> actualizarPerfil({
    required String uid,
    required String nombre,
    String? carnet,
  }) async {
    nombreGuardado = nombre;
    carnetGuardado = carnet;
  }
}

void main() {
  final perfil = PerfilUsuario.fromMap('uid-demo', {
    'cedula': '12345678', 'nombre': 'Alexander Ramírez',
    'correo': 'alexander@unimet.edu.ve', 'rol': 'estudiante',
    'carnet': '202611111', 'estado': 'activo',
  });

  testWidgets('muestra datos reales y no hardcodeados', (tester) async {
    final repo = RepositorioFalso(perfil);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PerfilScreen(
        uid: 'uid-demo', repository: repo, cerrarSesion: () async {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Alexander Ramírez'), findsWidgets);
    expect(find.text('202611111'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
  });

  testWidgets('guardar edicion invoca repositorio', (tester) async {
    final repo = RepositorioFalso(perfil);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PerfilScreen(
        uid: 'uid-demo', repository: repo, cerrarSesion: () async {},
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Nombre Actualizado');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repo.nombreGuardado, 'Nombre Actualizado');
    expect(repo.carnetGuardado, '202611111');
  });

  testWidgets('cerrar sesion exige confirmacion', (tester) async {
    var llamados = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PerfilScreen(
        uid: 'uid-demo', repository: RepositorioFalso(perfil),
        cerrarSesion: () async { llamados++; },
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').first);
    await tester.pumpAndSettle();
    expect(llamados, 0);
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(llamados, 1);
  });
}
