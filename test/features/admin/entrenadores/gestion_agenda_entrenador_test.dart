import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/admin/entrenadores/domain/gestion_agenda_entrenador.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/entrenador.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

const _lunes16a18 = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '16:00',
  horaFin: '18:00',
  lugar: 'Cancha A',
);
const _lunes17a19 = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '17:00',
  horaFin: '19:00',
  lugar: 'Cancha B',
);
const _lunes18a20 = HorarioSesion(
  dia: DiaSemana.lunes,
  horaInicio: '18:00',
  horaFin: '20:00',
  lugar: 'Cancha B',
);
const _martes16a18 = HorarioSesion(
  dia: DiaSemana.martes,
  horaInicio: '16:00',
  horaFin: '18:00',
  lugar: 'Gimnasio',
);

const _entrenador = Entrenador(
  uid: 'ent-1',
  cedula: '12345678',
  nombre: 'Carlos Rojas',
  correo: 'entrenador1@saman.test',
  especialidad: 'Fútbol',
  aniosExperiencia: 8,
);

Deporte _deporte(
  String codigo, {
  String? entrenadorUid,
  List<HorarioSesion> horarios = const [],
}) {
  return Deporte(
    codigo: codigo,
    nombre: codigo == 'FUT-01' ? 'Fútbol sala' : 'Tenis',
    descripcion: 'Entrenamiento',
    disciplina: Disciplina.colectivo,
    costo: 0,
    cupoMaximo: 20,
    cuposOcupados: 4,
    cuposConfirmados: 2,
    creadoEn: DateTime(2026, 11, 5),
    entrenadorUid: entrenadorUid,
    horarios: horarios,
  );
}

class _DeporteRepositoryFake implements DeporteRepository {
  _DeporteRepositoryFake(this.deportes);

  final List<Deporte> deportes;

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) =>
      Stream.value(deportes.where((d) => !soloActivos || d.activo).toList());

  @override
  Stream<Deporte?> observar(String codigo) =>
      Stream.value(deportes.where((d) => d.codigo == codigo).firstOrNull);

  @override
  Stream<List<Deporte>> observarPorEntrenador(String entrenadorUid) =>
      Stream.value(
        deportes.where((d) => d.entrenadorUid == entrenadorUid).toList(),
      );

  @override
  Future<void> crear(Deporte deporte) async => deportes.add(deporte);

  @override
  Future<void> actualizar(Deporte deporte) async {
    final index = deportes.indexWhere((d) => d.codigo == deporte.codigo);
    if (index == -1) throw StateError('Deporte no encontrado');
    deportes[index] = deporte;
  }

  @override
  Future<void> desactivar(String codigo) async {
    final index = deportes.indexWhere((d) => d.codigo == codigo);
    if (index == -1) throw StateError('Deporte no encontrado');
    deportes[index] = deportes[index].copyWith(activo: false);
  }
}

void main() {
  group('A2 - validaciones de agenda', () {
    test('admite horarios contiguos sin solapamiento', () {
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([
          _lunes16a18,
          _lunes18a20,
        ]),
        returnsNormally,
      );
    });

    test('rechaza dos horarios solapados del mismo deporte', () {
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([
          _lunes16a18,
          _lunes17a19,
        ]),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });

    test('permite la misma hora en distintos días', () {
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([
          _lunes16a18,
          _martes16a18,
        ]),
        returnsNormally,
      );
    });

    test('rechaza horas fuera del formato HH:mm', () {
      const invalido = HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '25:99',
        horaFin: '26:00',
        lugar: 'Cancha',
      );
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([invalido]),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });

    test('rechaza un horario con fin anterior al inicio', () {
      const invalido = HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '19:00',
        horaFin: '18:00',
        lugar: 'Cancha',
      );
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([invalido]),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });

    test('rechaza sesiones sin lugar', () {
      const invalido = HorarioSesion(
        dia: DiaSemana.lunes,
        horaInicio: '16:00',
        horaFin: '18:00',
        lugar: ' ',
      );
      expect(
        () => ValidacionesAgendaEntrenador.validarHorarios([invalido]),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });

    test('detecta cruce de entrenador entre deportes distintos', () {
      final deportes = [
        _deporte('FUT-01', entrenadorUid: 'ent-1', horarios: [_lunes16a18]),
      ];
      expect(
        () => ValidacionesAgendaEntrenador.validarSinSolapamientos(
          entrenadorUid: 'ent-1',
          codigoDeporte: 'TEN-01',
          horarios: [_lunes17a19],
          deportes: deportes,
        ),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });

    test('un entrenador diferente puede tener horario coincidente', () {
      final deportes = [
        _deporte('FUT-01', entrenadorUid: 'ent-2', horarios: [_lunes16a18]),
      ];
      expect(
        () => ValidacionesAgendaEntrenador.validarSinSolapamientos(
          entrenadorUid: 'ent-1',
          codigoDeporte: 'TEN-01',
          horarios: [_lunes17a19],
          deportes: deportes,
        ),
        returnsNormally,
      );
    });

    test('ignora el deporte que se está editando', () {
      final deportes = [
        _deporte('FUT-01', entrenadorUid: 'ent-1', horarios: [_lunes16a18]),
      ];
      expect(
        () => ValidacionesAgendaEntrenador.validarSinSolapamientos(
          entrenadorUid: 'ent-1',
          codigoDeporte: 'FUT-01',
          horarios: [_lunes17a19],
          deportes: deportes,
        ),
        returnsNormally,
      );
    });
  });

  group('A2 - casos de uso', () {
    test('asigna entrenador preservando los contadores de cupos', () async {
      final repo = _DeporteRepositoryFake([_deporte('FUT-01')]);
      await GestionAgendaEntrenador(repo).asignar(
        codigoDeporte: 'FUT-01',
        entrenador: _entrenador,
        horarios: [_lunes16a18],
      );
      final resultado = repo.deportes.single;
      expect(resultado.entrenadorUid, 'ent-1');
      expect(resultado.entrenadorNombre, 'Carlos Rojas');
      expect(resultado.horarios, hasLength(1));
      expect(resultado.cuposOcupados, 4);
      expect(resultado.cuposConfirmados, 2);
    });

    test('impide asignar un entrenador con otro deporte solapado', () async {
      final repo = _DeporteRepositoryFake([
        _deporte('FUT-01', entrenadorUid: 'ent-1', horarios: [_lunes16a18]),
        _deporte('TEN-01'),
      ]);
      await expectLater(
        GestionAgendaEntrenador(repo).asignar(
          codigoDeporte: 'TEN-01',
          entrenador: _entrenador,
          horarios: [_lunes17a19],
        ),
        throwsA(isA<AgendaEntrenadorException>()),
      );
      expect(repo.deportes.last.entrenadorUid, isNull);
    });

    test('puede desasignar un entrenador conservando horarios', () async {
      final repo = _DeporteRepositoryFake([
        _deporte('FUT-01', entrenadorUid: 'ent-1', horarios: [_lunes16a18]),
      ]);
      await GestionAgendaEntrenador(repo).desasignar('FUT-01');
      expect(repo.deportes.single.entrenadorUid, isNull);
      expect(repo.deportes.single.horarios, hasLength(1));
    });

    test('actualiza horarios de un deporte sin entrenador', () async {
      final repo = _DeporteRepositoryFake([_deporte('TEN-01')]);
      await GestionAgendaEntrenador(
        repo,
      ).actualizarHorarios(codigoDeporte: 'TEN-01', horarios: [_martes16a18]);
      expect(repo.deportes.single.horarios.single.dia, DiaSemana.martes);
    });

    test(
      'rechaza editar horarios si colisionan con otro deporte asignado',
      () async {
        final repo = _DeporteRepositoryFake([
          _deporte('FUT-01', entrenadorUid: 'ent-1', horarios: [_lunes16a18]),
          _deporte('TEN-01', entrenadorUid: 'ent-1', horarios: [_martes16a18]),
        ]);
        await expectLater(
          GestionAgendaEntrenador(repo).actualizarHorarios(
            codigoDeporte: 'TEN-01',
            horarios: [_lunes17a19],
          ),
          throwsA(isA<AgendaEntrenadorException>()),
        );
        expect(repo.deportes.last.horarios.single.dia, DiaSemana.martes);
      },
    );

    test('rechaza códigos de deporte inexistentes', () async {
      final repo = _DeporteRepositoryFake([_deporte('FUT-01')]);
      await expectLater(
        GestionAgendaEntrenador(repo).desasignar('TEN-01'),
        throwsA(isA<AgendaEntrenadorException>()),
      );
    });
  });
}
