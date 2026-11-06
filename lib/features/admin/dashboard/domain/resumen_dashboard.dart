import 'dart:math' as math;

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Datos mínimos necesarios para calcular indicadores de usuarios.
/// No se utiliza UsuarioModel porque el seed del emulador identifica a los
/// usuarios por el ID del documento y no guarda un campo uid adicional.
class UsuarioDashboard {
  const UsuarioDashboard({required this.rol, this.estado});

  final String rol;
  final String? estado;

  factory UsuarioDashboard.fromMap(Map<String, dynamic> datos) {
    return UsuarioDashboard(
      rol: datos['rol'] as String? ?? '',
      estado: datos['estado'] as String?,
    );
  }
}

class OcupacionDeporte {
  const OcupacionDeporte({
    required this.codigo,
    required this.nombre,
    required this.ocupados,
    required this.confirmados,
    required this.capacidad,
  });

  final String codigo;
  final String nombre;
  final int ocupados;
  final int confirmados;
  final int capacidad;

  int get disponibles => math.max(0, capacidad - ocupados);

  double get porcentaje => capacidad > 0 ? 100 * ocupados / capacidad : 0;
}

/// Indicadores calculados únicamente a partir de los documentos presentes.
/// Se consideran solo deportes activos para métricas de disponibilidad.
/// 'cuposOcupados' incluye reservas pendientes y confirmadas; no equivale
/// al número de alumnos con pago aprobado.
class ResumenDashboard {
  const ResumenDashboard({
    required this.deportesTotales,
    required this.deportesActivos,
    required this.deportesSinEntrenador,
    required this.estudiantes,
    required this.estudiantesActivos,
    required this.entrenadores,
    required this.cuposTotales,
    required this.cuposOcupados,
    required this.cuposConfirmados,
    required this.deportesCompletos,
    required this.porDisciplina,
    required this.ocupacionDeportes,
  });

  final int deportesTotales;
  final int deportesActivos;
  final int deportesSinEntrenador;
  final int estudiantes;
  final int estudiantesActivos;
  final int entrenadores;
  final int cuposTotales;
  final int cuposOcupados;
  final int cuposConfirmados;
  final int deportesCompletos;
  final Map<Disciplina, int> porDisciplina;
  final List<OcupacionDeporte> ocupacionDeportes;

  int get cuposDisponibles => math.max(0, cuposTotales - cuposOcupados);

  double get porcentajeOcupacion =>
      cuposTotales > 0 ? 100 * cuposOcupados / cuposTotales : 0;

  static ResumenDashboard calcular({
    required List<Deporte> deportes,
    required List<UsuarioDashboard> usuarios,
  }) {
    final activos = deportes.where((d) => d.activo).toList();
    final distribucion = <Disciplina, int>{
      for (final disciplina in Disciplina.values) disciplina: 0,
    };
    final ocupacion = <OcupacionDeporte>[];
    var capacidadTotal = 0;
    var ocupadosTotal = 0;
    var confirmadosTotal = 0;
    var completos = 0;
    var sinEntrenador = 0;

    for (final d in activos) {
      final capacidad = math.max(0, d.cupoMaximo);
      final ocupados = math.max(0, math.min(capacidad, d.cuposOcupados));
      final confirmados = math.max(0, math.min(ocupados, d.cuposConfirmados));
      capacidadTotal += capacidad;
      ocupadosTotal += ocupados;
      confirmadosTotal += confirmados;
      if (capacidad > 0 && ocupados >= capacidad) completos++;
      if (d.entrenadorUid == null || d.entrenadorUid!.isEmpty) {
        sinEntrenador++;
      }
      distribucion[d.disciplina] = (distribucion[d.disciplina] ?? 0) + 1;
      ocupacion.add(
        OcupacionDeporte(
          codigo: d.codigo,
          nombre: d.nombre,
          ocupados: ocupados,
          confirmados: confirmados,
          capacidad: capacidad,
        ),
      );
    }
    ocupacion.sort((a, b) {
      final comparacion = b.porcentaje.compareTo(a.porcentaje);
      return comparacion != 0 ? comparacion : a.codigo.compareTo(b.codigo);
    });

    return ResumenDashboard(
      deportesTotales: deportes.length,
      deportesActivos: activos.length,
      deportesSinEntrenador: sinEntrenador,
      estudiantes: usuarios.where((u) => u.rol == 'estudiante').length,
      estudiantesActivos: usuarios
          .where((u) => u.rol == 'estudiante' && u.estado == 'activo')
          .length,
      entrenadores: usuarios.where((u) => u.rol == 'entrenador').length,
      cuposTotales: capacidadTotal,
      cuposOcupados: ocupadosTotal,
      cuposConfirmados: confirmadosTotal,
      deportesCompletos: completos,
      porDisciplina: Map<Disciplina, int>.unmodifiable(distribucion),
      ocupacionDeportes: List<OcupacionDeporte>.unmodifiable(ocupacion),
    );
  }
}
