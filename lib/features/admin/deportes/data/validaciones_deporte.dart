import 'package:saman_deportivo/models/deporte.dart';

/// Validaciones de negocio previas a las operaciones administrativas.
/// La autorización se aplica por separado en firestore.rules.
class ValidacionesDeporte {
  const ValidacionesDeporte._();

  static final RegExp _hora24 = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

  static void validar(Deporte deporte) {
    if (!Deporte.formatoCodigo.hasMatch(deporte.codigo)) {
      throw ArgumentError('El código debe tener el formato FUT-01.');
    }
    final nombre = deporte.nombre.trim();
    if (nombre.length < 3 || nombre.length > 100) {
      throw ArgumentError('El nombre debe tener entre 3 y 100 caracteres.');
    }
    if (deporte.descripcion.length > 500) {
      throw ArgumentError('La descripción no puede superar 500 caracteres.');
    }
    if (!deporte.costo.isFinite || deporte.costo < 0) {
      throw ArgumentError('El costo debe ser un número no negativo.');
    }
    if (deporte.cupoMaximo <= 0) {
      throw ArgumentError('El cupo máximo debe ser mayor que cero.');
    }
    if (deporte.cuposOcupados < 0 ||
        deporte.cuposConfirmados < 0 ||
        deporte.cuposConfirmados > deporte.cuposOcupados ||
        deporte.cuposOcupados > deporte.cupoMaximo) {
      throw ArgumentError('Los contadores de cupos son inconsistentes.');
    }
    if (deporte.totalResenas < 0 ||
        !deporte.promedioCalificacion.isFinite ||
        deporte.promedioCalificacion < 0 ||
        deporte.promedioCalificacion > 5) {
      throw ArgumentError('Los indicadores de reseñas son inválidos.');
    }
    for (final horario in deporte.horarios) {
      if (!_hora24.hasMatch(horario.horaInicio) ||
          !_hora24.hasMatch(horario.horaFin) ||
          !horario.esValido ||
          horario.lugar.trim().isEmpty) {
        throw ArgumentError('Existe un horario inválido.');
      }
    }
    for (var i = 0; i < deporte.horarios.length; i++) {
      for (var j = i + 1; j < deporte.horarios.length; j++) {
        if (deporte.horarios[i].seCruzaCon(deporte.horarios[j])) {
          throw ArgumentError('Hay horarios solapados en el mismo deporte.');
        }
      }
    }
  }

  static void validarCreacion(Deporte deporte) {
    validar(deporte);
    if (deporte.cuposOcupados != 0 ||
        deporte.cuposConfirmados != 0 ||
        deporte.totalResenas != 0 ||
        deporte.promedioCalificacion != 0 ||
        deporte.actualizadoEn != null) {
      throw ArgumentError(
        'Un deporte nuevo debe iniciar sin reservas ni reseñas.',
      );
    }
  }
}
