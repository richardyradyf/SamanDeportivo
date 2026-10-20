import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/main.dart';

void main() {
  testWidgets('Abrir el formulario de registro',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SamanDeportivoApp());

    expect(
      find.text('¡Bienvenido a Samán Deportivo!'),
      findsOneWidget,
    );

    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de estudiante'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
  });
}
