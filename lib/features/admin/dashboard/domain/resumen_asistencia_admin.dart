import 'package:saman_deportivo/models/asistencia.dart';

/// Promedio de asistencia por REGISTROS de sesiones (no por estudiantes únicos).
/// La ausencia de registros se representa con `null`, no como 0 %.
class ResumenAsistenciaAdmin {
  const ResumenAsistenciaAdmin({
    required this.presentes,
    required this.ausentes,
  });

  final int presentes;
  final int ausentes;

  int get total => presentes + ausentes;

  double? get porcentaje => total == 0 ? null : presentes * 100 / total;

  static ResumenAsistenciaAdmin calcular(
    Iterable<Asistencia> registros, {
    String? deporteId,
  }) {
    var presentes = 0;
    var ausentes = 0;

    for (final registro in registros) {
      if (deporteId != null && registro.deporteId != deporteId) continue;
      if (registro.estuvoPresente) {
        presentes++;
      } else {
        ausentes++;
      }
    }

    return ResumenAsistenciaAdmin(presentes: presentes, ausentes: ausentes);
  }
}
