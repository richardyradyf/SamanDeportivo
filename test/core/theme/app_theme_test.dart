import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';

/// Verifica que el tema respete el sistema de diseño del Figma (RNF-06).
void main() {
  final tema = AppTheme.claro;

  test('usa el verde primario del Figma', () {
    expect(tema.colorScheme.primary, AppColors.primario);
    expect(tema.colorScheme.primary, const Color(0xFF06452B));
  });

  test('usa el fondo y el color de error del Figma', () {
    expect(tema.scaffoldBackgroundColor, AppColors.fondo);
    expect(tema.colorScheme.error, AppColors.peligro);
  });

  test('usa la tipografía DM Sans', () {
    expect(tema.textTheme.bodyMedium?.fontFamily, AppTheme.fuente);
    expect(tema.textTheme.headlineLarge?.fontFamily, AppTheme.fuente);
  });

  test('el H1 mide 36 px y el cuerpo no baja de 16 px', () {
    expect(tema.textTheme.headlineLarge?.fontSize, 36);
    expect(tema.textTheme.bodyMedium?.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('un botón sin estilo propio toma el verde del tema', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Scaffold(
          body: ElevatedButton(onPressed: () {}, child: const Text('Entrar')),
        ),
      ),
    );

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final contexto = tester.element(find.byType(ElevatedButton));
    final fondo =
        boton.style?.backgroundColor?.resolve({}) ??
        Theme.of(contexto).elevatedButtonTheme.style?.backgroundColor
            ?.resolve({});

    expect(fondo, AppColors.primario);
  });
}
