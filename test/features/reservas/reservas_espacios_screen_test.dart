import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/espacios/data/espacio_repository.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/data/reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/presentation/boton_reservas.dart';
import 'package:saman_deportivo/features/reservas/presentation/horario_reserva_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/reservas_espacios_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

final _espacio = EspacioDeportivo(
  id: 'cancha-a',
  nombre: 'Cancha norte',
  tipo: 'Tenis',
  creadoEn: DateTime.utc(2026, 11, 1),
);

class _EspaciosPrueba extends Fake implements EspacioRepository {
  @override
  Stream<List<EspacioDeportivo>> observarTodos() => Stream.value([_espacio]);
}

class _DeportesPrueba extends Fake implements DeporteRepository {
  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value([]);
}

class _DisponibilidadPrueba extends Fake implements DisponibilidadRepository {
  _DisponibilidadPrueba(this.ocupaciones);
  final List<OcupacionEspacio> ocupaciones;

  @override
  Stream<List<OcupacionEspacio>> observarOcupaciones({
    required String espacioId,
    required DateTime desde,
    required DateTime hasta,
  }) => Stream.value(ocupaciones);
}

class _ReservasPrueba extends Fake implements ReservasRepository {
  final cambios = StreamController<List<ReservaEspacio>>.broadcast();
  final lista = <ReservaEspacio>[];
  int creaciones = 0;
  int cancelaciones = 0;

  void publicar() => cambios.add(List.of(lista));

  @override
  Stream<List<ReservaEspacio>> observarPropias(String usuarioUid) =>
      cambios.stream;

  @override
  Future<String> crear({
    required String espacioId,
    required DateTime inicio,
    required DateTime fin,
    required String motivo,
  }) async {
    creaciones++;
    lista.add(
      ReservaEspacio(
        id: 'res-$creaciones',
        espacioId: espacioId,
        usuarioUid: 'alumno-1',
        rol: Rol.estudiante,
        inicio: inicio,
        fin: fin,
        motivo: motivo,
        creadoEn: DateTime.utc(2026, 11, 15),
      ),
    );
    publicar();
    return 'res-$creaciones';
  }

  @override
  Future<void> cancelar(String reservaId) async {
    cancelaciones++;
    final indice = lista.indexWhere((r) => r.id == reservaId);
    lista[indice] = lista[indice].cancelar(DateTime.utc(2026, 11, 15));
    publicar();
  }

  Future<void> cerrar() => cambios.close();
}

Widget _pantalla({
  required _ReservasPrueba reservas,
  List<OcupacionEspacio> ocupaciones = const [],
}) => MaterialApp(
  home: ReservasEspaciosScreen(
    rol: Rol.estudiante,
    usuarioUid: 'alumno-1',
    reloj: () => DateTime.utc(2026, 11, 15, 14),
    espacios: _EspaciosPrueba(),
    deportes: _DeportesPrueba(),
    disponibilidad: _DisponibilidadPrueba(ocupaciones),
    reservas: reservas,
  ),
);

void _usarVentanaAmplia(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1900);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('el acceso a reservas funciona sin Firebase en pruebas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BotonReservas(rol: Rol.estudiante)),
      ),
    );

    await tester.tap(find.byTooltip('Reservas de espacios'));
    await tester.pumpAndSettle();
    expect(find.text('Reservas de espacios'), findsOneWidget);
    expect(
      find.text('Inicia sesión para consultar y crear reservas.'),
      findsOneWidget,
    );
  });

  test(
    'la fecha y hora Caracas se mantienen sin depender de la zona local',
    () {
      final instante = HorarioReservaCaracas.combinar(
        DateTime(2026, 11, 16),
        const TimeOfDay(hour: 10, minute: 30),
      );
      expect(instante, DateTime.utc(2026, 11, 16, 14, 30));
      expect(HorarioReservaCaracas.hora(instante), '10:30');
    },
  );

  testWidgets('la interfaz crea y cancela una reserva sin Firebase', (
    tester,
  ) async {
    _usarVentanaAmplia(tester);

    final repo = _ReservasPrueba();
    addTearDown(repo.cerrar);
    await tester.pumpWidget(_pantalla(reservas: repo));
    repo.publicar();
    await tester.pumpAndSettle();

    expect(find.text('Cancha norte · Tenis'), findsOneWidget);
    expect(
      find.text('No hay horarios ocupados para las próximas 48 horas.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('reserva-motivo')),
      'Partido amistoso',
    );
    await tester.ensureVisible(find.byKey(const Key('confirmar-reserva')));
    await tester.tap(find.byKey(const Key('confirmar-reserva')));
    await tester.pumpAndSettle();

    expect(repo.creaciones, 1);
    expect(repo.lista.single.inicio, DateTime.utc(2026, 11, 16, 14));
    expect(find.text('Partido amistoso'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cancelar-reserva-res-1')));
    await tester.tap(find.byKey(const Key('cancelar-reserva-res-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    expect(repo.cancelaciones, 1);
    expect(repo.lista.single.estado, EstadoReservaEspacio.cancelada);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('el formulario rechaza un motivo vacío antes de escribir', (
    tester,
  ) async {
    _usarVentanaAmplia(tester);

    final repo = _ReservasPrueba();
    addTearDown(repo.cerrar);
    await tester.pumpWidget(_pantalla(reservas: repo));
    repo.publicar();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('confirmar-reserva')));
    await tester.tap(find.byKey(const Key('confirmar-reserva')));
    await tester.pumpAndSettle();

    expect(repo.creaciones, 0);
    expect(
      find.text('El motivo debe tener entre 3 y 200 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'una ocupación se muestra sin datos privados y bloquea la reserva',
    (tester) async {
      _usarVentanaAmplia(tester);

      final repo = _ReservasPrueba();
      addTearDown(repo.cerrar);
      final ocupacion = OcupacionEspacio(
        id: 'de-otro',
        espacioId: 'cancha-a',
        inicio: DateTime.utc(2026, 11, 16, 14, 30),
        fin: DateTime.utc(2026, 11, 16, 15, 30),
      );
      await tester.pumpWidget(
        _pantalla(reservas: repo, ocupaciones: [ocupacion]),
      );
      repo.publicar();
      await tester.pumpAndSettle();

      expect(find.textContaining('10:30–11:30 · Reservado'), findsOneWidget);
      expect(find.text('de-otro'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('reserva-motivo')),
        'Entrenamiento',
      );
      await tester.ensureVisible(find.byKey(const Key('confirmar-reserva')));
      await tester.tap(find.byKey(const Key('confirmar-reserva')));
      await tester.pumpAndSettle();

      expect(repo.creaciones, 0);
      expect(find.textContaining('ya tiene una reserva'), findsOneWidget);
    },
  );
}
