import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/screens/inicio_estudiante_screen.dart';

Widget pantalla(Future<int> Function() expirar) => MaterialApp(
  home: InicioEstudianteScreen(
    nombre: 'Ana Pérez',
    onCerrarSesion: () {},
    expirarVencidas: expirar,
  ),
);

void main() {
  testWidgets('al entrar expira las vencidas una sola vez', (tester) async {
    var llamadas = 0;
    Future<int> expirar() async => ++llamadas;

    await tester.pumpWidget(pantalla(expirar));
    await tester.pump();
    await tester.pumpWidget(pantalla(expirar));
    await tester.pump();

    expect(llamadas, 1);
  });

  testWidgets('si falla la expiración la pantalla sigue funcionando', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla(() async => throw Exception('sin red')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(InicioEstudianteScreen), findsOneWidget);
  });
}
