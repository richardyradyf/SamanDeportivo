import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/presentation/disponibilidad_view.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

class _DisponibilidadVacia implements DisponibilidadRepository {
  @override
  Stream<List<OcupacionEspacio>> observarOcupaciones({
    required String espacioId,
    required DateTime desde,
    required DateTime hasta,
  }) => Stream.value(const []);
}

void main() {
  for (final ancho in [360.0, 1280.0]) {
    testWidgets('rango horario no se divide en dos líneas a ${ancho}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: DisponibilidadView(
              espacios: [
                EspacioDeportivo(
                  id: 'cancha',
                  nombre: 'Cancha de tenis',
                  tipo: 'Raqueta',
                  creadoEn: DateTime.utc(2026, 11, 19),
                ),
              ],
              deportes: const [],
              disponibilidad: _DisponibilidadVacia(),
              rol: Rol.estudiante,
              reloj: () => DateTime.utc(2026, 11, 19, 12),
              onReservar: (_, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final horario = tester.widget<Text>(find.text('06:00 - 07:00'));
      expect(horario.maxLines, 1);
      expect(horario.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
