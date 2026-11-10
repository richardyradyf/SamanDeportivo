import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Interfaz inyectable para mantener el dashboard comprobable sin Firebase.
abstract class DashboardRepository {
  Stream<List<Deporte>> observarDeportes();
  Stream<List<UsuarioDashboard>> observarUsuarios();
}

/// Solo consulta colecciones ya existentes y cubiertas por las reglas A1.
/// El listado de usuarios está permitido exclusivamente a administradores.
class FirestoreDashboardRepository implements DashboardRepository {
  FirestoreDashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Deporte>> observarDeportes() => _firestore
      .collection('deportes')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((documento) => Deporte.fromMap(documento.id, documento.data()))
            .toList(growable: false),
      );

  @override
  Stream<List<UsuarioDashboard>> observarUsuarios() => _firestore
      .collection('usuarios')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((documento) => UsuarioDashboard.fromMap(documento.data()))
            .toList(growable: false),
      );
}
