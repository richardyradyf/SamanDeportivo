import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/entrenador.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Error de validación mostrado por la pantalla administrativa.
class AgendaEntrenadorException implements Exception {
  const AgendaEntrenadorException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Validaciones puras, independientes de Firestore y fáciles de probar.
abstract final class ValidacionesAgendaEntrenador {
  static final RegExp _formatoHora = RegExp(
    r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$',
  );

  /// Cada sesión necesita una hora real y un intervalo positivo.
  /// Dos sesiones de un mismo deporte tampoco pueden solaparse.
  static void validarHorarios(List<HorarioSesion> horarios) {
    for (final sesion in horarios) {
      if (!_formatoHora.hasMatch(sesion.horaInicio) ||
          !_formatoHora.hasMatch(sesion.horaFin) ||
          !sesion.esValido) {
        throw const AgendaEntrenadorException(
          'Usa horas HH:mm válidas; el final debe ser posterior al inicio.',
        );
      }
      if (sesion.lugar.trim().isEmpty) {
        throw const AgendaEntrenadorException(
          'Cada sesión debe indicar un lugar de entrenamiento.',
        );
      }
    }

    for (var i = 0; i < horarios.length; i++) {
      for (var j = i + 1; j < horarios.length; j++) {
        if (horarios[i].seCruzaCon(horarios[j])) {
          throw const AgendaEntrenadorException(
            'Dos horarios del mismo deporte se solapan.',
          );
        }
      }
    }
  }

  /// Comprueba conflictos entre deportes de un entrenador.
  /// Ignora [codigoDeporte] porque corresponde al deporte que se está editando.
  static void validarSinSolapamientos({
    required String entrenadorUid,
    required String codigoDeporte,
    required List<HorarioSesion> horarios,
    required Iterable<Deporte> deportes,
  }) {
    validarHorarios(horarios);
    for (final otro in deportes) {
      if (otro.codigo == codigoDeporte || otro.entrenadorUid != entrenadorUid) {
        continue;
      }
      for (final propuesto in horarios) {
        for (final existente in otro.horarios) {
          if (propuesto.seCruzaCon(existente)) {
            throw AgendaEntrenadorException(
              'El entrenador ya tiene una sesión en ${otro.nombre} '
              '(${existente.resumen}).',
            );
          }
        }
      }
    }
  }
}

/// Casos de uso administrativos de A2, basados en el contrato de Richard.
///
/// Esta comprobación evita errores normales de interfaz, pero NO garantiza
/// exclusión mutua si dos administradores escriben concurrentemente.
/// La garantía definitiva debe implementarse con bloqueo/agenda transaccional
/// del lado del servidor antes de considerar RF-16 completamente cerrado.
class GestionAgendaEntrenador {
  GestionAgendaEntrenador(this._deportes);

  final DeporteRepository _deportes;

  Future<List<Deporte>> _consultarTodos() async {
    return _deportes.observarCatalogo(soloActivos: false).first;
  }

  Deporte _deportePorCodigo(List<Deporte> todos, String codigo) {
    for (final deporte in todos) {
      if (deporte.codigo == codigo) return deporte;
    }
    throw AgendaEntrenadorException('El deporte $codigo no existe.');
  }

  /// Asigna una cuenta de entrenador ya existente al deporte indicado.
  /// Las cuentas de Firebase Authentication NO se crean desde Flutter.
  Future<void> asignar({
    required String codigoDeporte,
    required Entrenador entrenador,
    required List<HorarioSesion> horarios,
  }) async {
    final todos = await _consultarTodos();
    final actual = _deportePorCodigo(todos, codigoDeporte);
    ValidacionesAgendaEntrenador.validarSinSolapamientos(
      entrenadorUid: entrenador.uid,
      codigoDeporte: codigoDeporte,
      horarios: horarios,
      deportes: todos,
    );
    await _deportes.actualizar(
      actual.copyWith(
        entrenadorUid: entrenador.uid,
        entrenadorNombre: entrenador.nombre,
        entrenadorEspecialidad: entrenador.especialidad,
        horarios: horarios,
      ),
    );
  }

  /// Desasigna al entrenador, pero conserva las sesiones del deporte.
  Future<void> desasignar(String codigoDeporte) async {
    final todos = await _consultarTodos();
    final actual = _deportePorCodigo(todos, codigoDeporte);
    await _deportes.actualizar(actual.sinEntrenador());
  }

  /// Cambia el horario de un deporte asignado o todavía sin entrenador.
  Future<void> actualizarHorarios({
    required String codigoDeporte,
    required List<HorarioSesion> horarios,
  }) async {
    final todos = await _consultarTodos();
    final actual = _deportePorCodigo(todos, codigoDeporte);
    final uid = actual.entrenadorUid;
    if (uid == null) {
      ValidacionesAgendaEntrenador.validarHorarios(horarios);
    } else {
      ValidacionesAgendaEntrenador.validarSinSolapamientos(
        entrenadorUid: uid,
        codigoDeporte: codigoDeporte,
        horarios: horarios,
        deportes: todos,
      );
    }
    await _deportes.actualizar(actual.copyWith(horarios: horarios));
  }
}
