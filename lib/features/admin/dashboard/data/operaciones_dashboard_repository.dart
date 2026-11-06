import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

/// Contrato separado de A3.1, para integrarse con los módulos de Mariana,
/// Andrés y Gabriel sin exigir que ya hayan publicado sus repositorios.
abstract class OperacionesDashboardRepository {
  Stream<List<Inscripcion>> observarInscripciones();
  Stream<List<Pago>> observarPagos();
  Stream<List<Busqueda>> observarBusquedasRecientes();
}

/// Lecturas de Firestore. No crea/modifica documentos ni cambia reglas.
/// En tanto los módulos propietarios no concedan lectura al administrador,
/// Firestore devolverá PERMISSION_DENIED, que la UI mostrará como no disponible.
class FirestoreOperacionesDashboardRepository
    implements OperacionesDashboardRepository {
  FirestoreOperacionesDashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Inscripcion>> observarInscripciones() => _firestore
      .collection('inscripciones')
      .snapshots()
      .map(
        (instantanea) => instantanea.docs
            .map(
              (documento) =>
                  Inscripcion.fromMap(documento.id, documento.data()),
            )
            .toList(growable: false),
      );

  @override
  Stream<List<Pago>> observarPagos() => _firestore
      .collection('pagos')
      .snapshots()
      .map(
        (instantanea) => instantanea.docs
            .map((documento) => Pago.fromMap(documento.id, documento.data()))
            .toList(growable: false),
      );

  @override
  Stream<List<Busqueda>> observarBusquedasRecientes() {
    final desde = DateTime.now().subtract(const Duration(days: 30));
    return _firestore
        .collection('busquedas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .snapshots()
        .map(
          (instantanea) => instantanea.docs
              .map(
                (documento) => Busqueda.fromMap(documento.id, documento.data()),
              )
              .toList(growable: false),
        );
  }
}
