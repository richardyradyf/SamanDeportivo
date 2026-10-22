import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/widgets/boton_cerrar_sesion.dart';
import 'package:saman_deportivo/core/widgets/panel_bienvenida.dart';
import 'package:saman_deportivo/models/enums.dart';

Widget _enApp(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  group('PanelBienvenida', () {
    testWidgets('saluda con el primer nombre y muestra el rol', (tester) async {
      await tester.pumpWidget(
        _enApp(
          const PanelBienvenida(
            nombre: 'Ana María Pérez',
            rol: Rol.estudiante,
            mensaje: 'Bienvenida',
          ),
        ),
      );

      expect(find.text('¡Hola, Ana!'), findsOneWidget);
      expect(find.text('Estudiante'), findsOneWidget);
    });

    testWidgets('sin nombre saluda de forma genérica', (tester) async {
      await tester.pumpWidget(
        _enApp(
          const PanelBienvenida(
            nombre: '  ',
            rol: Rol.entrenador,
            mensaje: 'Bienvenido',
          ),
        ),
      );

      expect(find.text('¡Hola!'), findsOneWidget);
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
