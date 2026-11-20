import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

void main() {
  final ahora = DateTime.utc(2026, 11, 15, 12);
  final cancha = EspacioDeportivo(
    id: 'cancha-tenis-1',
    nombre: 'Cancha de tenis 1',
    tipo: 'Tenis',
    creadoEn: ahora,
  );
  final gimnasio = EspacioDeportivo(
    id: 'gimnasio-1',
    nombre: 'Gimnasio 1',
    tipo: 'Gimnasio',
    creadoEn: ahora,
  );
  final claseTenis = Deporte(
    codigo: 'TEN-01',
    nombre: 'Tenis',
    descripcion: 'Tenis de prueba',
    disciplina: Disciplina.raqueta,
    costo: 0,
    cupoMaximo: 12,
    creadoEn: ahora,
    horarios: const [
      HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: 'Cancha de tenis 1',
        espacioId: 'cancha-tenis-1',
      ),
    ],
  );

  void validar({
    EspacioDeportivo? espacio,
    Rol rol = Rol.estudiante,
    DateTime? inicio,
    DateTime? fin,
    String motivo = 'Práctica libre',
    Iterable<Deporte>? deportes,
    Iterable<OcupacionEspacio> ocupaciones = const [],
  }) {
    ValidacionesReserva.validarSolicitud(
      espacio: espacio ?? cancha,
      rol: rol,
      inicio: inicio ?? DateTime.utc(2026, 11, 17, 13),
      fin: fin ?? DateTime.utc(2026, 11, 17, 15),
      ahora: ahora,
      motivo: motivo,
      deportes: deportes ?? [claseTenis],
      ocupaciones: ocupaciones,
    );
  }

  test('estudiante puede reservar exactamente dos horas dentro de tres semanas', () {
    expect(() => validar(), returnsNormally);
  });

  test('agenda nueva rechaza una clase que cruza una reserva privada', () {
    const horarioLunes = HorarioSesion(
      dia: DiaSemana.lunes,
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha de tenis 1',
      espacioId: 'cancha-tenis-1',
    );
    // Lunes 16-nov-2026, 16:00-18:00 Caracas = 20:00-22:00 UTC.
    expect(
      ValidacionesReserva.reservaCruzaClaseSemanal(
        inicioReserva: DateTime.utc(2026, 11, 16, 21),
        finReserva: DateTime.utc(2026, 11, 16, 22),
        horario: horarioLunes,
      ),
      isTrue,
    );
    // Una reserva contigua es válida, tanto al terminar como al iniciar.
    expect(
      ValidacionesReserva.reservaCruzaClaseSemanal(
        inicioReserva: DateTime.utc(2026, 11, 16, 22),
        finReserva: DateTime.utc(2026, 11, 16, 23),
        horario: horarioLunes,
      ),
      isFalse,
    );
    // También detecta colisión con una clase de la semana siguiente.
    expect(
      ValidacionesReserva.reservaCruzaClaseSemanal(
        inicioReserva: DateTime.utc(2026, 11, 16, 23),
        finReserva: DateTime.utc(2026, 11, 23, 21),
        horario: horarioLunes,
      ),
      isTrue,
    );
  });

  test('estudiante no puede reservar más de dos horas', () {
    expect(
      () => validar(fin: DateTime.utc(2026, 11, 17, 15, 1)),
      throwsA(isA<ReservaEspacioException>().having(
        (e) => e.mensaje, 'mensaje', contains('máximo 2 horas'),
      )),
    );
  });

  test('el período de tres semanas incluye el final de la reserva', () {
    final limite = ahora.add(const Duration(days: 21));
    expect(() => validar(
      inicio: limite.subtract(const Duration(hours: 2)),
      fin: limite,
    ), returnsNormally);
    expect(() => validar(
      inicio: limite.subtract(const Duration(hours: 1)),
      fin: limite.add(const Duration(minutes: 1)),
    ), throwsA(isA<ReservaEspacioException>()));
  });

  test('entrenador y administrador no tienen límites de duración ni antelación', () {
    for (final rol in [Rol.entrenador, Rol.administrador]) {
      expect(() => validar(
        espacio: gimnasio,
        rol: rol,
        inicio: DateTime.utc(2028, 1, 1),
        fin: DateTime.utc(2028, 1, 5),
      ), returnsNormally);
    }
  });

  test('rechaza fechas pasadas, duración nula y negativa', () {
    expect(() => validar(
      inicio: ahora.subtract(const Duration(minutes: 1)),
      fin: ahora.add(const Duration(hours: 1)),
    ), throwsA(isA<ReservaEspacioException>()));
    expect(() => validar(
      inicio: ahora.add(const Duration(days: 1)),
      fin: ahora.add(const Duration(days: 1)),
    ), throwsA(isA<ReservaEspacioException>()));
    expect(() => validar(
      inicio: ahora.add(const Duration(days: 2)),
      fin: ahora.add(const Duration(days: 1)),
    ), throwsA(isA<ReservaEspacioException>()));
  });

  test('no permite reservar un espacio desactivado', () {
    expect(() => validar(espacio: cancha.copyWith(activo: false)),
        throwsA(isA<ReservaEspacioException>()));
  });

  test('motivo obligatorio y máximo de 200 caracteres', () {
    expect(() => validar(motivo: '  '), throwsA(isA<ReservaEspacioException>()));
    expect(() => validar(motivo: 'a' * 201),
        throwsA(isA<ReservaEspacioException>()));
  });

  test('rechaza solape con una reserva particular del mismo espacio', () {
    final ocupada = OcupacionEspacio(
      id: 'reserva-1',
      espacioId: cancha.id,
      inicio: DateTime.utc(2026, 11, 17, 14),
      fin: DateTime.utc(2026, 11, 17, 16),
    );
    expect(() => validar(ocupaciones: [ocupada]),
        throwsA(isA<ReservaEspacioException>()));
    expect(() => validar(ocupaciones: [
      OcupacionEspacio(
        id: 'reserva-2', espacioId: gimnasio.id,
        inicio: ocupada.inicio, fin: ocupada.fin,
      ),
    ]), returnsNormally);
  });

  test('dos reservas contiguas son válidas con intervalos semiabiertos', () {
    expect(() => validar(ocupaciones: [
      OcupacionEspacio(
        id: 'reserva-1', espacioId: cancha.id,
        inicio: DateTime.utc(2026, 11, 17, 11),
        fin: DateTime.utc(2026, 11, 17, 13),
      ),
      OcupacionEspacio(
        id: 'reserva-2', espacioId: cancha.id,
        inicio: DateTime.utc(2026, 11, 17, 15),
        fin: DateTime.utc(2026, 11, 17, 17),
      ),
    ]), returnsNormally);
  });

  test('una clase semanal ocupa la cancha aunque sea otro deporte', () {
    // Lunes 16:30 Caracas equivale a lunes 20:30 UTC.
    expect(() => validar(
      inicio: DateTime.utc(2026, 11, 16, 20, 30),
      fin: DateTime.utc(2026, 11, 16, 21, 30),
    ), throwsA(isA<ReservaEspacioException>().having(
      (e) => e.mensaje, 'mensaje', contains('Tenis'),
    )));
  });

  test('la comparación usa Caracas incluso si cambia el día en UTC', () {
    final claseNoche = claseTenis.copyWith(horarios: const [
      HorarioSesion(
        dia: DiaSemana.miercoles,
        horaInicio: '23:00',
        horaFin: '23:59',
        lugar: 'Cancha de tenis 1',
        espacioId: 'cancha-tenis-1',
      ),
    ]);
    // Miércoles 23:30 Caracas = jueves 03:30 UTC.
    expect(() => validar(
      inicio: DateTime.utc(2026, 11, 19, 3, 30),
      fin: DateTime.utc(2026, 11, 19, 3, 45),
      deportes: [claseNoche],
    ), throwsA(isA<ReservaEspacioException>()));
  });

  test('se permite reservar inmediatamente después de una clase', () {
    expect(() => validar(
      inicio: DateTime.utc(2026, 11, 16, 22),
      fin: DateTime.utc(2026, 11, 16, 23),
    ), returnsNormally);
  });

  test('las clases inactivas no bloquean nuevas reservas', () {
    expect(() => validar(
      deportes: [claseTenis.copyWith(activo: false)],
      inicio: DateTime.utc(2026, 11, 16, 20, 30),
      fin: DateTime.utc(2026, 11, 16, 21, 30),
    ), returnsNormally);
  });

  test('las agendas históricas sin espacioId se comparan por nombre', () {
    final historica = claseTenis.copyWith(horarios: const [
      HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00', horaFin: '18:00',
        lugar: 'CANCHA DE TENIS 1',
      ),
    ]);
    expect(() => validar(
      deportes: [historica],
      inicio: DateTime.utc(2026, 11, 16, 20),
      fin: DateTime.utc(2026, 11, 16, 21),
    ), throwsA(isA<ReservaEspacioException>()));
  });

  test('una reserva larga no elude la clase de la semana siguiente', () {
    expect(() => validar(
      rol: Rol.administrador,
      inicio: DateTime.utc(2026, 11, 16, 23),
      fin: DateTime.utc(2026, 11, 25),
    ), throwsA(isA<ReservaEspacioException>()));
  });

  test('la disponibilidad ordena clases y reservas sin revelar identidad', () {
    final bloques = ValidacionesReserva.consultarOcupaciones(
      espacio: cancha,
      desde: DateTime.utc(2026, 11, 16, 19),
      hasta: DateTime.utc(2026, 11, 16, 23),
      deportes: [claseTenis],
      ocupaciones: [
        OcupacionEspacio(
          id: 'reserva-1',
          espacioId: cancha.id,
          inicio: DateTime.utc(2026, 11, 16, 22),
          fin: DateTime.utc(2026, 11, 16, 22, 30),
        ),
      ],
    );
    expect(bloques.length, 2);
    expect(bloques.first.descripcion, 'Tenis');
    expect(bloques.first.origen, OrigenOcupacion.clase);
    expect(bloques.last.descripcion, 'Reservado');
    expect(bloques.last.origen, OrigenOcupacion.reserva);
  });

  test('una cancha sin clases ni reservas aparece libre', () {
    final bloques = ValidacionesReserva.consultarOcupaciones(
      espacio: gimnasio,
      desde: DateTime.utc(2026, 11, 16, 19),
      hasta: DateTime.utc(2026, 11, 16, 23),
      deportes: [claseTenis],
      ocupaciones: const [],
    );
    expect(bloques, isEmpty);
  });
}
