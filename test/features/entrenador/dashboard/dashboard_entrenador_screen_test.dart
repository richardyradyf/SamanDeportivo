import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/widgets/layout_responsivo.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/dashboard_entrenador_screen.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_entrenador.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/proxima_sesion.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

// Lunes 16/11/2026 a las 10:00.
final ahora = DateTime(2026, 11, 16, 10);

const lunes = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '16:00',
  horaFin: '18:00',
  lugar: 'Cancha techada',
);

final futbol = Deporte(
  codigo: 'FUT-01',
  nombre: 'Fútbol sala',
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 1, 1),
  horarios: const [lunes],
);

ResumenEntrenador resumen({ProximaSesion? proxima}) => ResumenEntrenador(
  disciplinas: 2,
  inscritosConfirmados: 13,
  sesionesPorSemana: 3,
  porcentajeAsistencia: 67,
  proxima: proxima,
);

Future<void> mostrar(WidgetTester tester, Stream<ResumenEntrenador> datos) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardEntrenadorScreen(
          nombre: 'Carlos Rojas',
          resumen: datos,
          ahora: ahora,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el saludo, la próxima sesión y los números', (
    tester,
  ) async {
    final proxima = ProximaSesion(
      deporte: futbol,
      horario: lunes,
      inicio: DateTime(2026, 11, 16, 16),
    );
    await mostrar(tester, Stream.value(resumen(proxima: proxima)));
    await tester.pump();

    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('Hoy · 16:00'), findsOneWidget);
    expect(find.text('16:00 - 18:00 · Cancha techada'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('67 %'), findsOneWidget);
    expect(find.text('Últimos 3 meses'), findsOneWidget);
  });

  testWidgets('sin horarios avisa que no hay sesiones', (tester) async {
    await mostrar(tester, Stream.value(resumen()));
    await tester.pump();
    expect(find.text('No tienes sesiones programadas.'), findsOneWidget);
  });

  testWidgets('mientras carga muestra el indicador', (tester) async {
    await mostrar(tester, const Stream.empty());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('si falla la carga muestra un error', (tester) async {
    await mostrar(tester, Stream.error(Exception('sin red')));
    await tester.pump();
    expect(find.text('No se pudo cargar tu resumen.'), findsOneWidget);
  });

  testWidgets('el acceso rápido lleva a Tomar asistencia', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutResponsivo(
          titulo: 'Samán',
          subtitulo: 'Entrenador',
          destinos: [
            DestinoNavegacion(
              etiqueta: 'Dashboard',
              icono: Icons.dashboard,
              iconoSeleccionado: Icons.dashboard,
              pantalla: DashboardEntrenadorScreen(
                nombre: 'Carlos',
                resumen: Stream.value(resumen()),
                ahora: ahora,
              ),
            ),
            for (final nombre in ['Disciplinas', 'Estudiantes', 'Asistencia'])
              DestinoNavegacion(
                etiqueta: nombre,
                icono: Icons.circle,
                iconoSeleccionado: Icons.circle,
                pantalla: Text('Pantalla $nombre'),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Tomar asistencia'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla Asistencia'), findsOneWidget);
  });
}
