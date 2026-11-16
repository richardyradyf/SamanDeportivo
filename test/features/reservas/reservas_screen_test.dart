import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/reservas/presentation/crear_reserva_screen.dart';
import 'package:saman_deportivo/features/reservas/presentation/reservas_screen.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

import 'reservas_datos_prueba.dart';

const _celular = Size(390, 844);
const _escritorio = Size(1280, 900);

Future<void> _tamano(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ReservasFalsas> _mostrar(
  WidgetTester tester, {
  Rol rol = Rol.estudiante,
  Size tamano = _celular,
  DateTime? ahora,
  List<OcupacionEspacio>? ocupaciones,
  ReservasFalsas? reservas,
  bool fallarDisponibilidad = false,
}) async {
  await _tamano(tester, tamano);
  final repo = reservas ?? ReservasFalsas();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(
        body: ReservasScreen(
          rol: rol,
          usuarioUid: 'est-1',
          espacios: EspaciosFalsos([tenis2, gimnasio, inactivo, tenis1]),
          deportes: DeportesFalsos([tenis]),
          disponibilidad: DisponibilidadFalsa(
            ocupaciones ?? [ocupacionLunes],
            fallar: fallarDisponibilidad,
          ),
          reservas: repo,
          reloj: () => ahora ?? en(lunes, 17),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _irA(WidgetTester tester, String pestana) async {
  await tester.tap(find.widgetWithText(Tab, pestana));
  await tester.pumpAndSettle();
}

/// Abre el formulario directamente, como lo hace la pantalla.
Future<ReservasFalsas> _formulario(
  WidgetTester tester, {
  required Rol rol,
  DateTime? inicio,
  DateTime? fin,
  ReservasFalsas? reservas,
  Size tamano = _celular,
  List<bool?>? resultado,
}) async {
  await _tamano(tester, tamano);
  final repo = reservas ?? ReservasFalsas();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CrearReservaScreen(
                      espacios: [tenis1, gimnasio],
                      deportes: [tenis],
                      disponibilidad: DisponibilidadFalsa([ocupacionLunes]),
                      reservas: repo,
                      rol: rol,
                      reloj: () => en(lunes, 10),
                      espacioId: 'tenis-1',
                      inicio: inicio,
                      fin: fin,
                    ),
                  ),
                );
                resultado?.add(r);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('Pantalla A: explorar espacios', () {
    for (final (nombre, tamano) in [('celular', _celular), ('escritorio', _escritorio)]) {
      testWidgets('en $nombre lista los espacios activos sin desbordes', (
        tester,
      ) async {
        await _mostrar(tester, tamano: tamano);

        expect(tester.takeException(), isNull);
        expect(find.text('Cancha de tenis 1'), findsOneWidget);
        expect(find.text('Cancha de tenis 2'), findsOneWidget);
        expect(find.text('Gimnasio 1'), findsOneWidget);
        expect(find.text('Gimnasio'), findsOneWidget);
        // El administrador lo desactivó: no se ofrece.
        expect(find.text('Cancha de fútbol 1'), findsNothing);
      });
    }

    testWidgets('identifica el espacio ocupado por una clase', (tester) async {
      // Lunes a las 17:00: la cancha 1 tiene Tenis de 16:00 a 18:00.
      await _mostrar(tester, tamano: _escritorio);

      expect(find.text('Ocupado hasta las 18:00'), findsOneWidget);
      expect(find.text('Disponible ahora'), findsNWidgets(2));
    });

    testWidgets('«Ver disponibilidad» abre la pestaña con ese espacio', (
      tester,
    ) async {
      await _mostrar(tester, tamano: _escritorio, ahora: en(lunes, 7));

      final tarjeta = find.ancestor(
        of: find.text('Cancha de tenis 1'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: tarjeta, matching: find.text('Ver disponibilidad')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cancha de tenis 1 · lunes 16/11/2026'), findsOneWidget);
    });
  });

  group('Pantalla B: disponibilidad', () {
    testWidgets('distingue horas libres, clases y reservas', (tester) async {
      await _mostrar(tester, tamano: _escritorio, ahora: en(lunes, 7));
      final tarjeta = find.ancestor(
        of: find.text('Cancha de tenis 1'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: tarjeta, matching: find.text('Ver disponibilidad')),
      );
      await tester.pumpAndSettle();

      Finder fila(String rango) => find.ancestor(
        of: find.text(rango),
        matching: find.byType(Container),
      ).first;

      expect(
        find.descendant(of: fila('10:00 - 11:00'), matching: find.text('Reservado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fila('16:00 - 17:00'), matching: find.text('Clase')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fila('16:00 - 17:00'), matching: find.text('Tenis')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fila('09:00 - 10:00'), matching: find.text('Disponible')),
        findsOneWidget,
      );
      // Solo las libres ofrecen reservar.
      expect(
        find.descendant(of: fila('16:00 - 17:00'), matching: find.text('Reservar')),
        findsNothing,
      );
    });

    testWidgets('filtra por franja y muestra los límites al estudiante', (
      tester,
    ) async {
      await _mostrar(tester, ahora: en(lunes, 7));
      await _irA(tester, 'Disponibilidad');

      expect(find.textContaining('21 días'), findsOneWidget);
      await tester.ensureVisible(find.text('Noche'));
      await tester.tap(find.text('Noche'));
      await tester.pumpAndSettle();

      expect(find.text('18:00 - 19:00'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el administrador no ve el aviso de límites', (tester) async {
      await _mostrar(tester, rol: Rol.administrador, ahora: en(lunes, 7));
      await _irA(tester, 'Disponibilidad');

      expect(find.textContaining('21 días'), findsNothing);
    });

    testWidgets('si falla la consulta lo avisa', (tester) async {
      await _mostrar(tester, fallarDisponibilidad: true);
      await _irA(tester, 'Disponibilidad');

      expect(find.text('No pudimos consultar la disponibilidad'), findsOneWidget);
    });
  });

  group('Pantalla C: crear reserva', () {
    testWidgets('al estudiante le muestra los límites y no deja pasar de 2 horas', (
      tester,
    ) async {
      await _formulario(
        tester,
        rol: Rol.estudiante,
        inicio: en(lunes.add(const Duration(days: 1)), 10),
        fin: en(lunes.add(const Duration(days: 1)), 11),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('limitesReserva')),
          matching: find.textContaining('hasta 2 horas'),
        ),
        findsOneWidget,
      );
      expect(find.text('Máximo 2 horas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('las horas de finalización respetan el máximo del estudiante', () {
      // Inicio a las 10:00 (600 minutos).
      expect(
        CrearReservaScreen.opcionesFin(inicio: 600, rol: Rol.estudiante),
        [630, 660, 690, 720],
      );
      final entrenador = CrearReservaScreen.opcionesFin(
        inicio: 600,
        rol: Rol.entrenador,
      );
      expect(entrenador.first, 630);
      expect(entrenador.last, 22 * 60);
      expect(
        CrearReservaScreen.opcionesFin(inicio: 21 * 60, rol: Rol.administrador),
        [21 * 60 + 30, 22 * 60],
      );
      expect(CrearReservaScreen.opcionesFin(inicio: null, rol: Rol.estudiante), isEmpty);
    });

    testWidgets('entrenadores y administradores no tienen esos límites', (
      tester,
    ) async {
      await _formulario(
        tester,
        rol: Rol.entrenador,
        inicio: en(lunes.add(const Duration(days: 1)), 10),
        fin: en(lunes.add(const Duration(days: 1)), 11),
      );

      expect(find.textContaining('no tienes límite'), findsOneWidget);
      expect(find.text('Máximo 2 horas'), findsNothing);
    });

    testWidgets('confirma la reserva con los datos elegidos', (tester) async {
      final resultado = <bool?>[];
      final manana = lunes.add(const Duration(days: 1));
      final repo = await _formulario(
        tester,
        rol: Rol.estudiante,
        inicio: en(manana, 10),
        fin: en(manana, 11),
        resultado: resultado,
      );

      await tester.enterText(find.byKey(const Key('reservaMotivo')), 'Práctica de saque');
      await tester.ensureVisible(find.byKey(const Key('confirmarReserva')));
      await tester.tap(find.byKey(const Key('confirmarReserva')));
      await tester.pumpAndSettle();

      expect(repo.creadas, hasLength(1));
      expect(repo.creadas.single.espacioId, 'tenis-1');
      expect(repo.creadas.single.inicio, en(manana, 10));
      expect(repo.creadas.single.fin, en(manana, 11));
      expect(repo.creadas.single.motivo, 'Práctica de saque');
      expect(resultado, [true]);
    });

    testWidgets('avisa antes de enviar si choca con una clase', (tester) async {
      final repo = await _formulario(
        tester,
        rol: Rol.estudiante,
        inicio: en(lunes, 16),
        fin: en(lunes, 17),
      );

      await tester.enterText(find.byKey(const Key('reservaMotivo')), 'Práctica');
      await tester.ensureVisible(find.byKey(const Key('confirmarReserva')));
      await tester.tap(find.byKey(const Key('confirmarReserva')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ocupado por Tenis'), findsOneWidget);
      expect(repo.creadas, isEmpty);
    });

    testWidgets('muestra la carga y el error de la transacción', (tester) async {
      final espera = Completer<void>();
      final manana = lunes.add(const Duration(days: 1));
      await _formulario(
        tester,
        rol: Rol.estudiante,
        inicio: en(manana, 10),
        fin: en(manana, 11),
        reservas: ReservasFalsas(pendiente: espera, errorAlCrear: choque),
      );

      await tester.enterText(find.byKey(const Key('reservaMotivo')), 'Práctica');
      await tester.ensureVisible(find.byKey(const Key('confirmarReserva')));
      await tester.tap(find.byKey(const Key('confirmarReserva')));
      await tester.pump();
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.byKey(const Key('confirmarReserva')),
      );
      expect(boton.onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('confirmarReserva')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      espera.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('errorReserva')), findsOneWidget);
      expect(find.textContaining('ya tiene una reserva'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('confirmarReserva'))).onPressed,
        isNotNull,
      );
    });

    testWidgets('exige el motivo', (tester) async {
      final manana = lunes.add(const Duration(days: 1));
      final repo = await _formulario(
        tester,
        rol: Rol.estudiante,
        inicio: en(manana, 10),
        fin: en(manana, 11),
      );

      await tester.ensureVisible(find.byKey(const Key('confirmarReserva')));
      await tester.tap(find.byKey(const Key('confirmarReserva')));
      await tester.pumpAndSettle();

      expect(find.text('Escribe al menos 3 caracteres'), findsOneWidget);
      expect(repo.creadas, isEmpty);
    });

    testWidgets('en escritorio el formulario no se estira ni se desborda', (
      tester,
    ) async {
      await _formulario(tester, rol: Rol.administrador, tamano: _escritorio);

      expect(tester.takeException(), isNull);
      final ancho = tester.getSize(find.byType(Card).first).width;
      expect(ancho, lessThanOrEqualTo(560));
    });
  });

  group('Pantalla D: mis reservas', () {
    final manana = lunes.add(const Duration(days: 1));
    final propias = [
      reserva('proxima', inicio: en(manana, 9), fin: en(manana, 10), motivo: 'Práctica de saque'),
      reserva('vieja', inicio: en(lunes, 8), fin: en(lunes, 9), espacioId: 'gym-1'),
      reserva(
        'cancelada',
        inicio: en(manana, 15),
        fin: en(manana, 16),
        estado: EstadoReservaEspacio.cancelada,
      ),
    ];

    testWidgets('separa próximas y pasadas con espacio, fecha, horario y estado', (
      tester,
    ) async {
      await _mostrar(tester, reservas: ReservasFalsas(propias: propias));
      await _irA(tester, 'Mis reservas');

      expect(find.text('PRÓXIMAS (1)'), findsOneWidget);
      expect(find.text('PASADAS (2)'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('Finalizada'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsOneWidget);
      expect(find.text('martes 17/11/2026'), findsNWidgets(2));
      expect(find.text('Gimnasio 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las tres pestañas caben en el celular y se puede volver', (
      tester,
    ) async {
      await _mostrar(tester, reservas: ReservasFalsas(propias: propias));
      for (final pestana in ['Espacios', 'Disponibilidad', 'Mis reservas']) {
        final centro = tester.getCenter(find.widgetWithText(Tab, pestana));
        expect(centro.dx, inInclusiveRange(0, _celular.width), reason: pestana);
      }

      await _irA(tester, 'Mis reservas');
      await _irA(tester, 'Espacios');
      await _irA(tester, 'Mis reservas');

      expect(find.text('PRÓXIMAS (1)'), findsOneWidget);
      expect(find.text('No pudimos cargar tus reservas'), findsNothing);
    });

    testWidgets('sin reservas invita a crear una', (tester) async {
      await _mostrar(tester);
      await _irA(tester, 'Mis reservas');

      expect(find.text('Todavía no tienes reservas'), findsOneWidget);
    });

    testWidgets('abre el detalle y permite cancelar con confirmación', (
      tester,
    ) async {
      final repo = await _mostrar(tester, reservas: ReservasFalsas(propias: propias));
      await _irA(tester, 'Mis reservas');

      await tester.tap(find.text('09:00 - 10:00'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de la reserva'), findsOneWidget);
      expect(find.text('Práctica de saque'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancelarReserva')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(repo.canceladas, ['proxima']);
      expect(find.text('Reserva cancelada.'), findsOneWidget);
    });

    testWidgets('una reserva pasada no se puede cancelar', (tester) async {
      await _mostrar(tester, reservas: ReservasFalsas(propias: propias));
      await _irA(tester, 'Mis reservas');

      await tester.ensureVisible(find.text('08:00 - 09:00'));
      await tester.tap(find.text('08:00 - 09:00'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancelarReserva')), findsNothing);
    });
  });

  testWidgets('sin repositorios ni Firebase muestra un aviso', (tester) async {
    await _tamano(tester, _celular);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReservasScreen(rol: Rol.estudiante))),
    );

    expect(find.text('Las reservas no están disponibles por ahora'), findsOneWidget);
  });
}
