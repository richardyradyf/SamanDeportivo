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

/// Resultado de convertir documentos de una colección operativa.
/// Si los documentos tienen estados o tipos incorrectos, se omiten de las
/// métricas y se informa al administrador. Errores de permisos NO se omiten.
class LecturaOperativa<T> {
  const LecturaOperativa({required this.registros, required this.omitidos});

  final List<T> registros;
  final int omitidos;
}

/// Contrato adicional opcional: mantiene compatibles los repositorios de
/// pruebas y las futuras implementaciones de Inscripcion/Pago/Busqueda.
abstract class OperacionesDashboardDiagnosticoRepository {
  Stream<LecturaOperativa<Inscripcion>> observarInscripcionesConDiagnostico();
  Stream<LecturaOperativa<Pago>> observarPagosConDiagnostico();
  Stream<LecturaOperativa<Busqueda>> observarBusquedasConDiagnostico();
}

/// Conversión por documento. No expone datos personales en el diagnóstico.
/// Los errores de la consulta Firestore permanecen en el stream de origen.
LecturaOperativa<T> procesarDocumentosOperativos<T>(
  Iterable<MapEntry<String, Map<String, dynamic>>> documentos,
  T Function(String id, Map<String, dynamic> datos) convertir,
) {
  final validos = <T>[];
  var omitidos = 0;
  for (final documento in documentos) {
    try {
      validos.add(convertir(documento.key, documento.value));
    } catch (_) {
      omitidos++;
    }
  }
  return LecturaOperativa(
    registros: List<T>.unmodifiable(validos),
    omitidos: omitidos,
  );
}

/// Consultas de Firestore que preservan errores de permisos de la colección,
/// pero toleran documentos con datos inválidos, uno a la vez.
class FirestoreOperacionesDashboardRepository
    implements
        OperacionesDashboardRepository,
        OperacionesDashboardDiagnosticoRepository {
  FirestoreOperacionesDashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<LecturaOperativa<T>> _observar<T>(
    Query<Map<String, dynamic>> consulta,
    T Function(String, Map<String, dynamic>) convertir,
  ) => consulta.snapshots().map(
    (snapshot) => procesarDocumentosOperativos(
      snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      convertir,
    ),
  );

  @override
  Stream<LecturaOperativa<Inscripcion>> observarInscripcionesConDiagnostico() =>
      _observar(_firestore.collection('inscripciones'), Inscripcion.fromMap);

  @override
  Stream<LecturaOperativa<Pago>> observarPagosConDiagnostico() =>
      _observar(_firestore.collection('pagos'), Pago.fromMap);

  @override
  Stream<LecturaOperativa<Busqueda>> observarBusquedasConDiagnostico() {
    final desde = DateTime.now().subtract(const Duration(days: 30));
    return _observar(
      _firestore
          .collection('busquedas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde)),
      Busqueda.fromMap,
    );
  }

  // API histórica: otras pantallas continúan recibiendo listas.
  @override
  Stream<List<Inscripcion>> observarInscripciones() =>
      observarInscripcionesConDiagnostico().map((r) => r.registros);

  @override
  Stream<List<Pago>> observarPagos() =>
      observarPagosConDiagnostico().map((r) => r.registros);

  @override
  Stream<List<Busqueda>> observarBusquedasRecientes() =>
      observarBusquedasConDiagnostico().map((r) => r.registros);
}
