import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';

/// Búsquedas del catálogo en la colección `busquedas` (RF-06, RF-18).
///
/// Según las reglas A3.6, cualquiera puede crear una búsqueda válida, pero
/// solo el administrador puede leerlas (para "deportes más buscados").
class FirestoreBusquedaRepository implements BusquedaRepository {
  FirestoreBusquedaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _busquedas =>
      _firestore.collection('busquedas');

  @override
  Future<void> registrar(Busqueda busqueda) async {
    await _busquedas.add(busqueda.toMap());
  }

  @override
  Stream<List<Busqueda>> observarDesde(DateTime desde) {
    return _busquedas
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (documento) => Busqueda.fromMap(documento.id, documento.data()),
              )
              .toList(growable: false),
        );
  }
}
