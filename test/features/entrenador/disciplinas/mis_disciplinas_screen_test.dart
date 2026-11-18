import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/entrenador/disciplinas/mis_disciplinas_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

Deporte deporte(String codigo, String nombre, {bool activo = true}) {
  return Deporte(
    codigo: codigo,
    nombre: nombre,
    descripcion: '',
    disciplina: Disciplina.colectivo,
    costo: 10,
    cupoMaximo: 20,
    cuposOcupados: 17,
    cuposConfirmados: 15,
    creadoEn: DateTime(2026, 10, 1),
    activo: activo,
    horarios: const [
      HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'Cancha techada',
      ),
    ],
  );
}

/// Dibuja la pantalla con un ancho de ventana dado (400 = teléfono).
Future<void> mostrar(
  WidgetTester tester,
  Stream<List<Deporte>> deportes, {
  double ancho = 400,
  ValueChanged<Deporte>? onAbrir,
}) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MisDisciplinasScreen(deportes: deportes, onAbrir: onAbrir),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final futbol = deporte('FUT-01', 'Fútbol sala');
  final tenis = deporte('TEN-01', 'Tenis');
  final inactivo = deporte('VOL-01', 'Voleibol', activo: false);

  testWidgets('muestra solo los deportes activos con horarios y cupos', (
    tester,
  ) async {
    await mostrar(tester, Stream.value([futbol, tenis, inactivo]));

    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('Tenis'), findsOneWidget);
    expect(find.text('Voleibol'), findsNothing);
    expect(find.text('Lun · 16:00 - 18:00 · Cancha techada'), findsNWidgets(2));
    expect(find.text('15 confirmados · 3 disponibles de 20'), findsNWidgets(2));
  });

  testWidgets('sin deportes muestra un mensaje', (tester) async {
    await mostrar(tester, Stream.value(const []));
    expect(
      find.text('Todavía no tienes disciplinas asignadas.'),
      findsOneWidget,
    );
  });

  testWidgets('si falla la carga muestra un error', (tester) async {
    await mostrar(tester, Stream.error(Exception('sin red')));
    expect(find.text('No se pudieron cargar tus disciplinas.'), findsOneWidget);
  });

  testWidgets('al tocar una tarjeta avisa cuál deporte se eligió', (
    tester,
  ) async {
    Deporte? elegido;
    await mostrar(
      tester,
      Stream.value([futbol, tenis]),
      onAbrir: (d) => elegido = d,
    );
    await tester.tap(find.text('Tenis'));
    expect(elegido?.codigo, 'TEN-01');
  });

  testWidgets('en teléfono va una columna y en computadora, varias', (
    tester,
  ) async {
    await mostrar(tester, Stream.value([futbol, tenis]));
    expect(
      tester.getTopLeft(find.text('Tenis')).dy,
      greaterThan(tester.getTopLeft(find.text('Fútbol sala')).dy),
    );

    await mostrar(tester, Stream.value([futbol, tenis]), ancho: 1200);
    expect(
      tester.getTopLeft(find.text('Tenis')).dy,
      tester.getTopLeft(find.text('Fútbol sala')).dy,
    );
  });
}
