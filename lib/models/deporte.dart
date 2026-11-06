import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';
import 'enums.dart';
import 'horario_sesion.dart';

/// Deporte del catálogo (RF-05, RF-15, RF-16).
/// Colección `deportes`; el ID del documento es el [codigo] (ej. "FUT-01"),
/// así el código es único por construcción.
class Deporte {
  final String codigo;
  final String nombre;
  final String descripcion;
  final Disciplina disciplina;

  /// Monto de la reserva en USD (se paga con PayPal, RF-11).
  final double costo;
  final String? imagenUrl;

  final int cupoMaximo;

  /// Inscripciones pendientes + confirmadas. Solo cambia en transacciones.
  final int cuposOcupados;

  /// Solo confirmadas (para el catálogo y el panel del admin).
  final int cuposConfirmados;

  final String? entrenadorUid;
  final String? entrenadorNombre;
  final String? entrenadorEspecialidad;
  final List<HorarioSesion> horarios;
  final bool activo;
  final double promedioCalificacion;
  final int totalResenas;
  final DateTime creadoEn;

  const Deporte({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.disciplina,
    required this.costo,
    required this.cupoMaximo,
    required this.creadoEn,
    this.imagenUrl,
    this.cuposOcupados = 0,
    this.cuposConfirmados = 0,
    this.entrenadorUid,
    this.entrenadorNombre,
    this.entrenadorEspecialidad,
    this.horarios = const [],
    this.activo = true,
    this.promedioCalificacion = 0,
    this.totalResenas = 0,
  });

  /// Formato del código: tres letras, guion y dos números (FUT-01).
  static final RegExp formatoCodigo = RegExp(r'^[A-Z]{3}-[0-9]{2}$');

  int get cuposDisponibles =>
      (cupoMaximo - cuposOcupados).clamp(0, cupoMaximo);

  bool get tieneCupo => cuposDisponibles > 0;

  bool get tieneEntrenador => entrenadorUid != null;

  /// Días en que hay sesión, sin repetir. Se guarda aparte en Firestore
  /// para poder filtrar con `array-contains` (RF-06).
  List<DiaSemana> get dias => horarios.map((h) => h.dia).toSet().toList();

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'disciplina': disciplina.name,
      'costo': costo,
      'imagenUrl': imagenUrl,
      'cupoMaximo': cupoMaximo,
      'cuposOcupados': cuposOcupados,
      'cuposConfirmados': cuposConfirmados,
      'entrenadorUid': entrenadorUid,
      'entrenadorNombre': entrenadorNombre,
      'entrenadorEspecialidad': entrenadorEspecialidad,
      'horarios': horarios.map((h) => h.toMap()).toList(),
      'dias': dias.map((d) => d.name).toList(),
      'activo': activo,
      'promedioCalificacion': promedioCalificacion,
      'totalResenas': totalResenas,
      'creadoEn': Timestamp.fromDate(creadoEn),
    };
  }

  factory Deporte.fromMap(String id, Map<String, dynamic> datos) {
    final horarios = (datos['horarios'] as List<dynamic>? ?? const [])
        .map((h) => HorarioSesion.fromMap(Map<String, dynamic>.from(h as Map)))
        .toList();

    return Deporte(
      codigo: id,
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String? ?? '',
      disciplina: Disciplina.desdeTexto(datos['disciplina'] as String?),
      costo: leerDecimal(datos['costo']),
      imagenUrl: datos['imagenUrl'] as String?,
      cupoMaximo: leerEntero(datos['cupoMaximo']),
      cuposOcupados: leerEntero(datos['cuposOcupados']),
      cuposConfirmados: leerEntero(datos['cuposConfirmados']),
      entrenadorUid: datos['entrenadorUid'] as String?,
      entrenadorNombre: datos['entrenadorNombre'] as String?,
      entrenadorEspecialidad: datos['entrenadorEspecialidad'] as String?,
      horarios: horarios,
      activo: datos['activo'] as bool? ?? true,
      promedioCalificacion: leerDecimal(datos['promedioCalificacion']),
      totalResenas: leerEntero(datos['totalResenas']),
      creadoEn: leerFecha(datos['creadoEn']),
    );
  }

  /// Copia cambiando solo los campos indicados. El código no se edita.
  Deporte copyWith({
    String? nombre,
    String? descripcion,
    Disciplina? disciplina,
    double? costo,
    String? imagenUrl,
    int? cupoMaximo,
    int? cuposOcupados,
    int? cuposConfirmados,
    String? entrenadorUid,
    String? entrenadorNombre,
    String? entrenadorEspecialidad,
    List<HorarioSesion>? horarios,
    bool? activo,
    double? promedioCalificacion,
    int? totalResenas,
  }) {
    return Deporte(
      codigo: codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      disciplina: disciplina ?? this.disciplina,
      costo: costo ?? this.costo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      cupoMaximo: cupoMaximo ?? this.cupoMaximo,
      cuposOcupados: cuposOcupados ?? this.cuposOcupados,
      cuposConfirmados: cuposConfirmados ?? this.cuposConfirmados,
      entrenadorUid: entrenadorUid ?? this.entrenadorUid,
      entrenadorNombre: entrenadorNombre ?? this.entrenadorNombre,
      entrenadorEspecialidad:
          entrenadorEspecialidad ?? this.entrenadorEspecialidad,
      horarios: horarios ?? this.horarios,
      activo: activo ?? this.activo,
      promedioCalificacion: promedioCalificacion ?? this.promedioCalificacion,
      totalResenas: totalResenas ?? this.totalResenas,
      creadoEn: creadoEn,
    );
  }
}
