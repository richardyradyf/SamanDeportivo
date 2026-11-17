import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_en_vivo.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_entrenador.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

final ahora = DateTime(2026, 11, 16, 10);

Deporte deporte(String codigo, {bool activo = true}) => Deporte(
  codigo: codigo,
  nombre: codigo,
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  cuposConfirmados: 5,
  creadoEn: DateTime(2026, 1, 1),
  activo: activo,
);

Asistencia registro(String codigo, EstadoAsistencia estado) =>
    Asistencia.registrar(
      inscripcionId: 'a_$codigo',
      estudianteUid: 'a',
      estudianteNombre: 'a',
      deporteId: codigo,
      entrenadorUid: 'ent1',
      fecha: DateTime(2026, 11, 9),
      estado: estado,
    );

void main() {
  late StreamController<List<Deporte>> deportes;
  late Map<String, StreamController<List<Asistencia>>> asistencias;
  late List<ResumenEntrenador> recibidos;
  late StreamSubscription<ResumenEntrenador> sub;

  setUp(() {
    deportes = StreamController<List<Deporte>>();
    asistencias = {};
    recibidos = [];
    sub = resumenEnVivo(
      deportes: deportes.stream,
      asistenciasDe: (codigo) => asistencias
          .putIfAbsent(codigo, StreamController<List<Asistencia>>.new)
          .stream,
      reloj: () => ahora,
    ).listen(recibidos.add);
  });

  tearDown(() => sub.cancel());

  test('espera la respuesta de todos los deportes y luego recalcula', () async {
    deportes.add([deporte('FUT-01'), deporte('TEN-01')]);
    await pumpEventQueue();

    asistencias['FUT-01']!.add([registro('FUT-01', EstadoAsistencia.presente)]);
    await pumpEventQueue();
    expect(recibidos, isEmpty); // falta TEN-01

    asistencias['TEN-01']!.add([registro('TEN-01', EstadoAsistencia.ausente)]);
    await pumpEventQueue();
    expect(recibidos.last.porcentajeAsistencia, 50);
    expect(recibidos.last.inscritosConfirmados, 10);

    asistencias['TEN-01']!.add([registro('TEN-01', EstadoAsistencia.presente)]);
    await pumpEventQueue();
    expect(recibidos.last.porcentajeAsistencia, 100);
  });

  test('si cambian los deportes, cierra las consultas anteriores', () async {
    deportes.add([deporte('FUT-01')]);
    await pumpEventQueue();
    expect(asistencias['FUT-01']!.hasListener, isTrue);

    deportes.add([deporte('TEN-01')]);
    await pumpEventQueue();
    expect(asistencias['FUT-01']!.hasListener, isFalse);
    expect(asistencias['TEN-01']!.hasListener, isTrue);
  });

  test('sin deportes activos emite un resumen en cero', () async {
    deportes.add([deporte('VOL-01', activo: false)]);
    await pumpEventQueue();
    expect(recibidos.single.disciplinas, 0);
    expect(recibidos.single.porcentajeAsistencia, 0);
    expect(asistencias, isEmpty);
  });

  test('pasa los errores a la pantalla', () async {
    final errores = <Object>[];
    await sub.cancel();
    sub = resumenEnVivo(
      deportes: Stream.error(Exception('sin permisos')),
      asistenciasDe: (_) => const Stream.empty(),
    ).listen(recibidos.add, onError: errores.add);
    await pumpEventQueue();
    expect(errores, hasLength(1));
  });
}
