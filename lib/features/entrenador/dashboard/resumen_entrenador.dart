import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/proxima_sesion.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Números del Dashboard del entrenador: cuántas disciplinas tiene,
/// cuántos inscritos confirmados, cuántas sesiones por semana, su próxima
/// sesión y el porcentaje de asistencia de los últimos 3 meses.
class ResumenEntrenador {
  const ResumenEntrenador({
    required this.disciplinas,
    required this.inscritosConfirmados,
    required this.sesionesPorSemana,
    required this.porcentajeAsistencia,
    required this.proxima,
  });

  final int disciplinas;
  final int inscritosConfirmados;
  final int sesionesPorSemana;

  /// De 0 a 100. Null si no hay registros en el período
  /// (no es lo mismo "0 %" que "todavía no ha tomado asistencia").
  final int porcentajeAsistencia;

  /// Null si ninguno de sus deportes tiene horarios.
  final ProximaSesion? proxima;

  factory ResumenEntrenador.calcular({
    required List<Deporte> deportes,
    required List<Asistencia> asistencias,
    required DateTime ahora,
  }) {
    final activos = deportes.where((d) => d.activo).toList();
    final codigos = {for (final d in activos) d.codigo};
    final asistencia = ResumenAsistenciaAdmin.calcular(
      asistencias.where((a) => codigos.contains(a.deporteId)),
      desde: ResumenAsistenciaAdmin.inicioTresMeses(ahora),
      creadoEnPorDeporte: {for (final d in activos) d.codigo: d.creadoEn},
    );
    return ResumenEntrenador(
      disciplinas: activos.length,
      inscritosConfirmados: activos.fold(
        0,
        (suma, d) => suma + d.cuposConfirmados,
      ),
      sesionesPorSemana: activos.fold(0, (suma, d) => suma + d.horarios.length),
      porcentajeAsistencia: asistencia.porcentaje.round(),
      proxima: proximaSesion(activos, ahora),
    );
  }
}
