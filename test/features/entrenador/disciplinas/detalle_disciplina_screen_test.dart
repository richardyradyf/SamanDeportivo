import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/entrenador/disciplinas/detalle_disciplina_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/resena.dart';

final futbol = Deporte(
  codigo: 'FUT-01',
  nombre: 'Fútbol sala',
  descripcion: 'Entrenamientos para todos los niveles.',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  cuposOcupados: 17,
  cuposConfirmados: 15,
  promedioCalificacion: 4.5,
  totalResenas: 2,
  creadoEn: DateTime(2026, 1, 1),
  horarios: const [
    HorarioSesion(
      dia: DiaSemana.lunes,
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha techada',
    ),
  ],
);

Resena resena(
  String nombre,
  int estrellas,
  DateTime fecha, {
  bool oculta = false,
}) => Resena(
  estudianteUid: nombre,
  estudianteNombre: nombre,
  puntuacion: estrellas,
  comentario: 'Comentario de $nombre',
  fecha: fecha,
  oculta: oculta,
);

Future<void> mostrar(WidgetTester tester, Stream<List<Resena>> resenas) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetalleDisciplinaScreen(deporte: futbol, resenas: resenas),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra los datos, horarios, cupos y calificación', (
    tester,
  ) async {
    await mostrar(tester, Stream.value(const []));

    expect(find.text('Fútbol sala'), findsOneWidget);
    expect(find.text('FUT-01 · Deporte colectivo'), findsOneWidget);
    expect(find.text('Entrenamientos para todos los niveles.'), findsOneWidget);
    expect(find.text('Lun · 16:00 - 18:00'), findsOneWidget);
    expect(find.text('Cancha techada'), findsOneWidget);
    expect(find.text('15 confirmados · 3 disponibles de 20'), findsOneWidget);
    expect(find.text('4.5 (2 reseñas)'), findsOneWidget);
  });

  testWidgets('lista los comentarios visibles, del más reciente al más viejo', (
    tester,
  ) async {
    await mostrar(
      tester,
      Stream.value([
        resena('Ana', 5, DateTime(2026, 11, 1)),
        resena('Luis', 4, DateTime(2026, 11, 10)),
        resena('Pedro', 1, DateTime(2026, 11, 12), oculta: true),
      ]),
    );

    expect(find.text('Comentario de Ana'), findsOneWidget);
    expect(find.text('Comentario de Luis'), findsOneWidget);
    expect(find.text('Comentario de Pedro'), findsNothing);
    expect(find.text('10/11/2026'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Luis')).dy,
      lessThan(tester.getTopLeft(find.text('Ana')).dy),
    );
  });

  testWidgets('sin reseñas lo dice', (tester) async {
    await mostrar(tester, Stream.value(const []));
    expect(find.text('Todavía no hay reseñas.'), findsOneWidget);
  });

  testWidgets('si fallan las reseñas muestra un error', (tester) async {
    await mostrar(tester, Stream.error(Exception('sin red')));
    expect(find.text('No se pudieron cargar las reseñas.'), findsOneWidget);
  });
}
