import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/operaciones_dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/presentation/panel_indicadores_operativos.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

class RepositorioFalso implements OperacionesDashboardRepository {
  RepositorioFalso({this.errorInscripciones = false});

  final bool errorInscripciones;

  @override
  Stream<List<Inscripcion>> observarInscripciones() => errorInscripciones
      ? Stream<List<Inscripcion>>.error(StateError('permission-denied'))
      : Stream.value(<Inscripcion>[]);

  @override
  Stream<List<Pago>> observarPagos() => Stream.value(<Pago>[]);

  @override
  Stream<List<Busqueda>> observarBusquedasRecientes() =>
      Stream.value(<Busqueda>[]);
}

Future<void> mostrar(WidgetTester tester, {RepositorioFalso? repo}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PanelIndicadoresOperativos(repositorio: repo),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin Firebase ni repositorio indica fuente no conectada', (
    tester,
  ) async {
    await mostrar(tester);
    expect(
      find.byKey(const Key('a34-no-conectada-inscripciones')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('a34-monto-aprobado')), findsNothing);
  });

  testWidgets('con permiso y colección vacía muestra cero real', (
    tester,
  ) async {
    await mostrar(tester, repo: RepositorioFalso());
    expect(
      find.text('Consulta permitida; colección sin registros.'),
      findsNWidgets(3),
    );
    expect(find.text('USD 0.00'), findsOneWidget);
  });

  testWidgets('lectura denegada indica indisponibilidad, no cero', (
    tester,
  ) async {
    await mostrar(tester, repo: RepositorioFalso(errorInscripciones: true));
    expect(
      find.byKey(const Key('a34-no-disponible-inscripciones')),
      findsOneWidget,
    );
    expect(find.text('USD 0.00'), findsOneWidget);
  });
  testWidgets('A3.8: muestra descartes sin inventar fuente sin permisos', (
    tester,
  ) async {
    await mostrar(tester, repo: RepositorioDiagnosticoFalso());
    expect(find.byKey(const Key('a38-omitidos-inscripciones')), findsOneWidget);
    expect(
      find.text('Se omitieron 2 registros con datos inválidos.'),
      findsOneWidget,
    );
    expect(
      find.text('No hay registros válidos para calcular indicadores.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('a34-no-disponible-inscripciones')),
      findsNothing,
    );
    expect(
      find.text('Consulta permitida; colección sin registros.'),
      findsNWidgets(2),
    );
  });
}

/// Prueba del contrato ampliado sin alterar el contrato histórico.
class RepositorioDiagnosticoFalso extends RepositorioFalso
    implements OperacionesDashboardDiagnosticoRepository {
  @override
  Stream<LecturaOperativa<Inscripcion>> observarInscripcionesConDiagnostico() =>
      Stream.value(
        const LecturaOperativa(registros: <Inscripcion>[], omitidos: 2),
      );

  @override
  Stream<LecturaOperativa<Pago>> observarPagosConDiagnostico() =>
      Stream.value(const LecturaOperativa(registros: <Pago>[], omitidos: 0));

  @override
  Stream<LecturaOperativa<Busqueda>> observarBusquedasConDiagnostico() =>
      Stream.value(
        const LecturaOperativa(registros: <Busqueda>[], omitidos: 0),
      );
}
