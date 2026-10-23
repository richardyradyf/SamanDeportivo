import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';

Widget _enApp(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  group('PanelBienvenida', () {
    test('el saludo cambia según la hora del día', () {
      expect(
        PanelBienvenida.saludoSegunHora(DateTime(2026, 10, 22, 9)),
        'Buenos días',
      );
      expect(
        PanelBienvenida.saludoSegunHora(DateTime(2026, 10, 22, 15)),
        'Buenas tardes',
      );
      expect(
        PanelBienvenida.saludoSegunHora(DateTime(2026, 10, 22, 20)),
        'Buenas noches',
      );
    });

    test('usa solo el primer nombre, y sin nombre deja el saludo solo', () {
      expect(PanelBienvenida.componer('Hola', 'María Pérez'), 'Hola, María');
      expect(PanelBienvenida.componer('Hola', '   '), 'Hola');
    });

    testWidgets('muestra el saludo y el contenido de debajo', (tester) async {
      await tester.pumpWidget(
        _enApp(
          const PanelBienvenida(
            saludo: 'Hola, Ana',
            contenido: Text('Contenido del rol'),
          ),
        ),
      );

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('Contenido del rol'), findsOneWidget);
    });
  });

  group('BotonCerrarSesion', () {
    testWidgets('cierra sesión solo si se confirma', (tester) async {
      var veces = 0;
      await tester.pumpWidget(
        _enApp(BotonCerrarSesion(onConfirmar: () => veces++)),
      );

      // Cancelar no cierra la sesión.
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(veces, 0);

      // Confirmar sí.
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(veces, 1);
    });
  });
}
