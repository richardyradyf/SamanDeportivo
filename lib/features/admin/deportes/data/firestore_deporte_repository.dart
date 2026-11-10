import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

import 'validaciones_deporte.dart';

/// Implementación del contrato compartido definido en el PR #18.
///
/// IMPORTANTE:
/// - El SDK cliente NO es una frontera de seguridad: firestore.rules exige
///   el rol administrador para crear/editar/desactivar.
/// - Los contadores cuposOcupados/cuposConfirmados pertenecen al módulo de
///   inscripciones. Este repositorio nunca los modifica durante una edición.
class FirestoreDeporteRepository implements DeporteRepository {
  FirestoreDeporteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _deportes =>
      _firestore.collection('deportes');

  @override
  Stream<List<Deporte>> observarCatalogo({bool soloActivos = true}) {
    Query<Map<String, dynamic>> consulta = _deportes;
    if (soloActivos) {
      consulta = consulta.where('activo', isEqualTo: true);
    }
    return consulta.snapshots().map(
      (snapshot) => snapshot.docs
          .map((documento) => Deporte.fromMap(documento.id, documento.data()))
          .toList(growable: false),
    );
  }

  @override
  Stream<Deporte?> observar(String codigo) {
    return _deportes.doc(codigo).snapshots().map((documento) {
      final datos = documento.data();
      return datos == null ? null : Deporte.fromMap(documento.id, datos);
    });
  }

  @override
  Stream<List<Deporte>> observarPorEntrenador(String entrenadorUid) {
    return _deportes
        .where('entrenadorUid', isEqualTo: entrenadorUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (documento) => Deporte.fromMap(documento.id, documento.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> crear(Deporte deporte) async {
    ValidacionesDeporte.validarCreacion(deporte);
    final referencia = _deportes.doc(deporte.codigo);

    // La lectura dentro de la transacción impide sobrescribir un código
    // existente, incluso frente a dos altas simultáneas.
    await _firestore.runTransaction<void>((transaccion) async {
      final existente = await transaccion.get(referencia);
      if (existente.exists) {
        throw StateError(
          'Ya existe un deporte con el código ${deporte.codigo}.',
        );
      }
      transaccion.set(referencia, deporte.toMap());
    });
  }

  @override
  Future<void> actualizar(Deporte deporte) async {
    ValidacionesDeporte.validar(deporte);
    final referencia = _deportes.doc(deporte.codigo);

    await _firestore.runTransaction<void>((transaccion) async {
      final snapshot = await transaccion.get(referencia);
      final datos = snapshot.data();
      if (datos == null) {
        throw StateError('El deporte ${deporte.codigo} no existe.');
      }
      final actual = Deporte.fromMap(snapshot.id, datos);
      if (deporte.cupoMaximo < actual.cuposOcupados) {
        throw StateError(
          'No se puede reducir el cupo máximo por debajo de los '
          '${actual.cuposOcupados} cupos ocupados.',
        );
      }

      // Se actualizan SOLO campos administrativos. Los contadores,
      // la calificación acumulada, el código y creadoEn se preservan.
      // Para quitar un entrenador, usar deporte.sinEntrenador() antes
      // de pasar el modelo: se escribirán valores null explícitos.
      transaccion.update(referencia, {
        'nombre': deporte.nombre.trim(),
        'descripcion': deporte.descripcion,
        'disciplina': deporte.disciplina.name,
        'costo': deporte.costo,
        'imagenUrl': deporte.imagenUrl,
        'cupoMaximo': deporte.cupoMaximo,
        'entrenadorUid': deporte.entrenadorUid,
        'entrenadorNombre': deporte.entrenadorNombre,
        'entrenadorEspecialidad': deporte.entrenadorEspecialidad,
        'horarios': deporte.horarios.map((h) => h.toMap()).toList(),
        'dias': deporte.dias.map((d) => d.name).toList(),
        'activo': deporte.activo,
        'actualizadoEn': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  @override
  Future<void> desactivar(String codigo) async {
    if (!Deporte.formatoCodigo.hasMatch(codigo)) {
      throw ArgumentError('Código de deporte inválido.');
    }
    final referencia = _deportes.doc(codigo);
    await _firestore.runTransaction<void>((transaccion) async {
      final snapshot = await transaccion.get(referencia);
      if (!snapshot.exists) {
        throw StateError('El deporte $codigo no existe.');
      }
      transaccion.update(referencia, {
        'activo': false,
        'actualizadoEn': Timestamp.fromDate(DateTime.now()),
      });
    });
  }
}
