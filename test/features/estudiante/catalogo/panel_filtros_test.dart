import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/panel_filtros.dart';

class _FiltrosInteractivos extends StatefulWidget {
  const _FiltrosInteractivos();

  @override
  State<_FiltrosInteractivos> createState() => _FiltrosInteractivosState();
}

class _FiltrosInteractivosState extends State<_FiltrosInteractivos> {
  FiltroCatalogo _filtro = const FiltroCatalogo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 380,
            child: PanelFiltros(
              filtro: _filtro,
              especialidades: const ['Natación'],
              onCambio: (filtro) => setState(() => _filtro = filtro),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('ningún filtro usa un check que ensanche los chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _FiltrosInteractivos());
    await tester.pumpAndSettle();

    final colectivo = find.widgetWithText(ChoiceChip, 'Colectivo');
    final individual = find.widgetWithText(ChoiceChip, 'Individual');
    final anchoAntes = tester.getSize(colectivo).width;
    final siguienteAntes = tester.getTopLeft(individual);

    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
    }

    await tester.tap(colectivo);
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(colectivo).selected, isTrue);
    expect(tester.getSize(colectivo).width, anchoAntes);
    expect(tester.getTopLeft(individual), siguienteAntes);

    // El mismo chip se puede deseleccionar sin mover a los demás.
    await tester.tap(colectivo);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(colectivo).selected, isFalse);
    expect(tester.getSize(colectivo).width, anchoAntes);
  });
}
