
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/screens/registro_screen.dart';

void main() {
  // PRUEBA 1: Verificar que aparecen los seis campos.
  testWidgets(
    'El registro muestra los campos del formulario',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistroScreen(),
        ),
      );

      expect(
        find.text('Registro de estudiante'),
        findsOneWidget,
      );

      expect(
        find.byType(TextFormField),
        findsNWidgets(6),
      );

      expect(
        find.text('Registrarme'),
        findsOneWidget,
      );
    },
  );

  // PRUEBA 2: Verificar que todos los campos son obligatorios.
  testWidgets(
    'El registro muestra errores si faltan datos',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistroScreen(),
        ),
      );

      final boton = find.text('Registrarme');

      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();

      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(
        find.text('Este campo es obligatorio'),
        findsNWidgets(6),
      );
    },
  );

  // PRUEBA 3: Rechazar correos que no sean de la UNIMET.
  testWidgets(
    'El registro rechaza un correo no institucional',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistroScreen(),
        ),
      );

      final campos = find.byType(TextFormField);

      await tester.enterText(campos.at(0), 'Mariana Perez');
      await tester.enterText(campos.at(1), '12345678');
      await tester.enterText(campos.at(2), '20260001');
      await tester.enterText(
        campos.at(3),
        'usuario@gmail.com',
      );
      await tester.enterText(campos.at(4), 'Clave123');
      await tester.enterText(campos.at(5), 'Clave123');

      final boton = find.text('Registrarme');

      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(
        find.text('Utiliza un correo institucional UNIMET'),
        findsOneWidget,
      );
    },
  );

  // PRUEBA 4: Verificar que las contraseñas coincidan.
  testWidgets(
    'El registro rechaza contrasenas diferentes',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistroScreen(),
        ),
      );

      final campos = find.byType(TextFormField);

      await tester.enterText(campos.at(0), 'Mariana Perez');
      await tester.enterText(campos.at(1), '12345678');
      await tester.enterText(campos.at(2), '20260001');
      await tester.enterText(
        campos.at(3),
        'estudiante@unimet.edu.ve',
      );
      await tester.enterText(campos.at(4), 'Clave123');
      await tester.enterText(campos.at(5), 'OtraClave123');

      final boton = find.text('Registrarme');

      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(
        find.text('Las contraseñas no coinciden'),
        findsOneWidget,
      );
    },
  );

  // PRUEBA 5: Verificar que el formulario acepte datos válidos.
  testWidgets(
    'El registro valida correctamente los datos',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistroScreen(),
        ),
      );

      final campos = find.byType(TextFormField);

      await tester.enterText(campos.at(0), 'Mariana Perez');
      await tester.enterText(campos.at(1), '12345678');
      await tester.enterText(campos.at(2), '20260001');
      await tester.enterText(
        campos.at(3),
        'estudiante@unimet.edu.ve',
      );
      await tester.enterText(campos.at(4), 'Clave123');
      await tester.enterText(campos.at(5), 'Clave123');

      final boton = find.text('Registrarme');

      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Datos validados. Registro en Firebase pendiente.',
        ),
        findsOneWidget,
      );
    },
  );
}
