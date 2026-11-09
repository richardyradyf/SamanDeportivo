import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:saman_deportivo/models/asistencia.dart';

/// Resultado de lectura: errores de permisos se propagan; registros malformados
/// no se convierten silenciosamente en ausencias ni cifras inventadas.
class LecturaAsistenciaAdmin {
  const LecturaAsistenciaAdmin({required this.registros, this.omitidos = 0});

  final List<Asistencia> registros;
  final int omitidos;
}

typedef ConsultarAsistenciaAdmin = Stream<LecturaAsistenciaAdmin> Function(
  DateTime desde,
  DateTime hasta,
);

class FirestoreAsistenciaAdminRepository {
  FirestoreAsistenciaAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// [desde, hasta): solo filtra por fecha para no añadir índices compuestos.
  /// El filtro por deporte se realiza en memoria sobre el rango seleccionado.
  Stream<LecturaAsistenciaAdmin> observar(DateTime desde, DateTime hasta) {
    return _firestore
        .collection('asistencias')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThan: Timestamp.fromDate(hasta))
        .snapshots()
        .map((snapshot) {
          final registros = <Asistencia>[];
          var omitidos = 0;
          for (final documento in snapshot.docs) {
            try {
              final datos = documento.data();
              if (datos['estado'] != 'presente' &&
                  datos['estado'] != 'ausente') {
                throw const FormatException('Estado de asistencia no válido');
              }
              if (datos['fecha'] is! Timestamp ||
                  datos['deporteId'] is! String ||
                  datos['estudianteUid'] is! String) {
                throw const FormatException('Campos de asistencia no válidos');
              }
              registros.add(Asistencia.fromMap(documento.id, datos));
            } catch (_) {
              omitidos++;
            }
          }
          return LecturaAsistenciaAdmin(
            registros: List.unmodifiable(registros),
            omitidos: omitidos,
          );
        });
  }
}
