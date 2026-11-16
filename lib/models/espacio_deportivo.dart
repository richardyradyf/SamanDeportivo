import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';

/// Instalación física compartida por las clases y las reservas particulares.
/// Su ID es estable incluso si el administrador cambia el nombre visible.
class EspacioDeportivo {
  const EspacioDeportivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.creadoEn,
    this.descripcion = '',
    this.activo = true,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String tipo;
  final String descripcion;
  final bool activo;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;

  Map<String, dynamic> toMap() => {
    'nombre': nombre.trim(),
    'tipo': tipo.trim(),
    'descripcion': descripcion.trim(),
    'activo': activo,
    'creadoEn': Timestamp.fromDate(creadoEn),
    'actualizadoEn': actualizadoEn == null
        ? null
        : Timestamp.fromDate(actualizadoEn!),
  };

  factory EspacioDeportivo.fromMap(String id, Map<String, dynamic> data) =>
      EspacioDeportivo(
        id: id,
        nombre: data['nombre'] as String? ?? '',
        tipo: data['tipo'] as String? ?? '',
        descripcion: data['descripcion'] as String? ?? '',
        activo: data['activo'] as bool? ?? true,
        creadoEn: leerFecha(data['creadoEn']),
        actualizadoEn: leerFechaOpcional(data['actualizadoEn']),
      );

  EspacioDeportivo copyWith({
    String? nombre,
    String? tipo,
    String? descripcion,
    bool? activo,
    DateTime? actualizadoEn,
  }) => EspacioDeportivo(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    descripcion: descripcion ?? this.descripcion,
    activo: activo ?? this.activo,
    creadoEn: creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
  );
}
