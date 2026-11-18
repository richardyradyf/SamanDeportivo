import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/franjas_disponibilidad.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/mis_reservas_view.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

import 'reservas_datos_prueba.dart';

List<BloqueOcupado> _bloquesLunes() => ValidacionesReserva.consultarOcupaciones(
  espacio: tenis1,
  desde: en(lunes, 0),
  hasta: en(lunes.add(const Duration(days: 1)), 0),
  deportes: [tenis],
  ocupaciones: [ocupacionLunes],
);

void main() {
  group('HoraCaracas', () {
    test('construye y muestra la hora de Caracas sin importar la zona', () {
      final inicio = en(lunes, 16, 30);
      expect(inicio.toUtc(), DateTime.utc(2026, 11, 16, 20, 30));
      expect(HoraCaracas.hora(inicio), '16:30');
      expect(HoraCaracas.fecha(inicio), '16/11/2026');
      expect(HoraCaracas.diaLargo(inicio), 'lunes 16/11/2026');
      expect(HoraCaracas.minutosDelDia(inicio), 16 * 60 + 30);
      expect(HoraCaracas.diaDe(inicio), lunes);
    });
  });

  group('franjasDelDia', () {
    test('marca clases, reservas, horas pasadas y horas libres', () {
      final franjas = franjasDelDia(
        dia: lunes,
        bloques: _bloquesLunes(),
        ahora: en(lunes, 8, 15),
      );
      FranjaHoraria a(int hora) =>
          franjas.firstWhere((f) => HoraCaracas.minutosDelDia(f.inicio) == hora * 60);

      expect(franjas, hasLength(16)); // de 06:00 a 22:00
      expect(a(7).estado, EstadoFranja.pasada);
      expect(a(8).estado, EstadoFranja.pasada); // empezó a las 08:00
      expect(a(9).estado, EstadoFranja.disponible);
      expect(a(10).estado, EstadoFranja.reserva);
      expect(a(11).estado, EstadoFranja.reserva);
      expect(a(12).estado, EstadoFranja.disponible); // [10, 12) no toca las 12
      expect(a(16).estado, EstadoFranja.clase);
      expect(a(16).descripcion, 'Tenis');
      expect(a(17).estado, EstadoFranja.clase);
      expect(a(18).estado, EstadoFranja.disponible);
      expect(a(9).sePuedeReservar, isTrue);
      expect(a(16).sePuedeReservar, isFalse);
    });

    test('filtra por parte del día', () {
      final tarde = franjasDelDia(
        dia: lunes,
        bloques: _bloquesLunes(),
        ahora: en(lunes, 8),
        parte: ParteDelDia.tarde,
      );
      expect(tarde, hasLength(6));
      expect(HoraCaracas.hora(tarde.first.inicio), '12:00');
      expect(HoraCaracas.hora(tarde.last.fin), '18:00');
    });
  });

  group('ResumenEspacioHoy', () {
    test('durante la clase dice hasta qué hora está ocupado', () {
      final resumen = ResumenEspacioHoy.de(_bloquesLunes(), en(lunes, 17));
      expect(resumen.libreAhora, isFalse);
      expect(HoraCaracas.hora(resumen.ocupadoHasta!), '18:00');
      expect(resumen.ocupadasHoy, 1);
    });

    test('libre entre bloques y cuenta los que faltan', () {
      final resumen = ResumenEspacioHoy.de(_bloquesLunes(), en(lunes, 9));
      expect(resumen.libreAhora, isTrue);
      expect(resumen.ocupadoHasta, isNull);
      expect(resumen.ocupadasHoy, 2);
    });
  });

  group('separarReservas', () {
    test('próximas en orden y pasadas o canceladas aparte', () {
      final ahora = en(lunes, 12);
      final manana = lunes.add(const Duration(days: 1));
      final lista = [
        reserva('b', inicio: en(manana, 15), fin: en(manana, 16)),
        reserva('a', inicio: en(manana, 9), fin: en(manana, 10)),
        reserva('pasada', inicio: en(lunes, 8), fin: en(lunes, 9)),
        reserva(
          'cancelada',
          inicio: en(manana, 11),
          fin: en(manana, 12),
          estado: EstadoReservaEspacio.cancelada,
        ),
        reserva('en-curso', inicio: en(lunes, 11), fin: en(lunes, 13)),
      ];

      final (:proximas, :pasadas) = separarReservas(lista, ahora);

      expect(proximas.map((r) => r.id), ['en-curso', 'a', 'b']);
      expect(pasadas.map((r) => r.id), ['cancelada', 'pasada']);
    });
  });
}
