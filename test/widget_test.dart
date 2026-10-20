
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/main.dart';

void main() {
  testWidgets('Mostrar pantalla inicial de Samán Deportivo',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SamanDeportivoApp());

    expect(find.text('Samán Deportivo'), findsOneWidget);

    expect(
      find.text('¡Bienvenido a Samán Deportivo!'),
      findsOneWidget,
    );

    expect(find.byType(Scaffold), findsOneWidget);
  });
}