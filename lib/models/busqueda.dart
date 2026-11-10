import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversiones.dart';

/// Búsqueda hecha en el catálogo (RF-06).
/// Colección `busquedas`; alimenta "deportes más buscados" del panel (RF-18).
class Busqueda {
  final String id;

  /// Texto buscado, en minúsculas.
  final String termino;

  /// Filtros usados: disciplina, dia, especialidad, soloConCupo.
  final Map<String, dynamic> filtros;

  /// Códigos de los deportes que salieron en el resultado.
  final List<String> deporteIds;

  /// Null si se buscó desde el landing sin iniciar sesión.
  final String? usuarioUid;
  final DateTime fecha;

  const Busqueda({
    required this.id,
    required this.termino,
    required this.fecha,
    this.filtros = const {},
    this.deporteIds = const [],
    this.usuarioUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'termino': termino.trim().toLowerCase(),
      'filtros': filtros,
      'deporteIds': deporteIds,
      'usuarioUid': usuarioUid,
      'fecha': Timestamp.fromDate(fecha),
    };
  }

  factory Busqueda.fromMap(String id, Map<String, dynamic> datos) {
    return Busqueda(
      id: id,
      termino: datos['termino'] as String? ?? '',
      filtros: Map<String, dynamic>.from(datos['filtros'] as Map? ?? const {}),
      deporteIds: leerListaTexto(datos['deporteIds']),
      usuarioUid: datos['usuarioUid'] as String?,
      fecha: leerFecha(datos['fecha']),
    );
  }
}
