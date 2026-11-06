import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

class FirestoreInscripcionRepository implements InscripcionRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FirestoreInscripcionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  // ---------------------------------------------------------
  // 1. INSCRIBIR ESTUDIANTE
  // ---------------------------------------------------------

  @override
  Future<Inscripcion> inscribirse({
    required Estudiante estudiante,
    required Deporte deporte,
  }) async {
    final usuario = auth.currentUser;

    if (usuario == null || usuario.uid != estudiante.uid) {
      throw const InscripcionException(
        'Debes iniciar sesión con tu cuenta de estudiante.',
      );
    }

    final estudianteRef = firestore.collection('usuarios').doc(estudiante.uid);

    final deporteRef = firestore.collection('deportes').doc(deporte.codigo);

    final inscripcionId = Inscripcion.idPara(estudiante.uid, deporte.codigo);

    final inscripcionRef = firestore
        .collection('inscripciones')
        .doc(inscripcionId);

    return firestore.runTransaction((transaction) async {
      // Leer los documentos antes de realizar cambios.
      final estudianteDoc = await transaction.get(estudianteRef);
      final deporteDoc = await transaction.get(deporteRef);
      final inscripcionDoc = await transaction.get(inscripcionRef);

      // Verificar que el estudiante exista.
      if (!estudianteDoc.exists || estudianteDoc.data() == null) {
        throw const InscripcionException('No se encontró el estudiante.');
      }

      final datosEstudiante = estudianteDoc.data()!;

      if (datosEstudiante['rol'] != 'estudiante') {
        throw const InscripcionException(
          'Solo los estudiantes pueden inscribirse.',
        );
      }

      final estudianteActual = Estudiante.fromMap(
        estudiante.uid,
        datosEstudiante,
      );

      // Verificar que el estudiante esté activo.
      if (!estudianteActual.estaActivo) {
        throw InscripcionException.estudianteInactivo;
      }

      // Verificar que el deporte exista.
      if (!deporteDoc.exists || deporteDoc.data() == null) {
        throw InscripcionException.deporteInactivo;
      }

      final deporteActual = Deporte.fromMap(deporte.codigo, deporteDoc.data()!);

      if (!deporteActual.activo) {
        throw InscripcionException.deporteInactivo;
      }

      final ahora = DateTime.now();

      Inscripcion? anterior;

      if (inscripcionDoc.exists && inscripcionDoc.data() != null) {
        anterior = Inscripcion.fromMap(inscripcionId, inscripcionDoc.data()!);
      }

      // Comprobar si existe una inscripción pendiente vencida.
      final pendienteVencida = anterior != null && anterior.estaVencida(ahora);

      // Evitar inscripciones duplicadas que retengan cupo.
      if (anterior != null && anterior.ocupaCupo && !pendienteVencida) {
        throw InscripcionException.yaInscrito;
      }

      // Si la inscripción anterior venció, descontar
      // temporalmente el cupo que estaba reteniendo.
      final cuposLiberados = pendienteVencida ? 1 : 0;

      final ocupadosAjustados = deporteActual.cuposOcupados - cuposLiberados;

      if (ocupadosAjustados < 0) {
        throw const InscripcionException(
          'Los cupos del deporte necesitan revisión.',
        );
      }

      // Comprobar la disponibilidad real del deporte.
      if (ocupadosAjustados >= deporteActual.cupoMaximo) {
        throw InscripcionException.sinCupos;
      }

      Inscripcion nuevaInscripcion;

      if (anterior == null) {
        // Crear una inscripción nueva.
        nuevaInscripcion = Inscripcion.nueva(
          estudiante: estudianteActual,
          deporte: deporteActual,
          ahora: ahora,
        );
      } else {
        // Registrar la expiración si la inscripción venció.
        final inscripcionAnterior = pendienteVencida
            ? anterior.conEstado(
                EstadoInscripcion.expirada,
                responsableUid: estudiante.uid,
                motivo: 'Plazo de pago vencido',
                fecha: ahora,
              )
            : anterior;

        // Reinscribir conservando el historial.
        nuevaInscripcion = inscripcionAnterior.reinscribir(
          estudiante: estudianteActual,
          deporte: deporteActual,
          ahora: ahora,
        );
      }

      // Guardar la inscripción y el contador de cupos
      // dentro de una misma transacción.
      transaction.set(inscripcionRef, nuevaInscripcion.toMap());

      transaction.update(deporteRef, {'cuposOcupados': ocupadosAjustados + 1});

      return nuevaInscripcion;
    });
  }

  // ---------------------------------------------------------
  // 2. CANCELAR INSCRIPCIÓN
  // ---------------------------------------------------------

  @override
  Future<void> cancelar(
    String inscripcionId, {
    required String responsableUid,
  }) async {
    final usuario = auth.currentUser;

    if (usuario == null || usuario.uid != responsableUid) {
      throw const InscripcionException(
        'No tienes permiso para cancelar esta inscripción.',
      );
    }

    final inscripcionRef = firestore
        .collection('inscripciones')
        .doc(inscripcionId);

    await firestore.runTransaction((transaction) async {
      final inscripcionDoc = await transaction.get(inscripcionRef);

      if (!inscripcionDoc.exists || inscripcionDoc.data() == null) {
        throw const InscripcionException('La inscripción no existe.');
      }

      final inscripcion = Inscripcion.fromMap(
        inscripcionId,
        inscripcionDoc.data()!,
      );

      // Solo el propietario puede cancelar.
      if (inscripcion.estudianteUid != usuario.uid) {
        throw const InscripcionException(
          'No puedes cancelar una inscripción de otro estudiante.',
        );
      }

      // No cancelar inscripciones que ya liberaron su cupo.
      if (!inscripcion.ocupaCupo) {
        throw const InscripcionException(
          'Esta inscripción ya no está vigente.',
        );
      }

      final deporteRef = firestore
          .collection('deportes')
          .doc(inscripcion.deporteId);

      final deporteDoc = await transaction.get(deporteRef);

      if (!deporteDoc.exists || deporteDoc.data() == null) {
        throw const InscripcionException('No se encontró el deporte asociado.');
      }

      final deporte = Deporte.fromMap(
        inscripcion.deporteId,
        deporteDoc.data()!,
      );

      // Comprobar que los contadores sean consistentes.
      if (deporte.cuposOcupados <= 0 ||
          (inscripcion.estado == EstadoInscripcion.confirmada &&
              deporte.cuposConfirmados <= 0)) {
        throw const InscripcionException(
          'Los contadores de cupos necesitan revisión.',
        );
      }

      final cancelada = inscripcion.conEstado(
        EstadoInscripcion.cancelada,
        responsableUid: responsableUid,
      );

      // Guardar cancelación y liberar cupo.
      transaction.update(inscripcionRef, cancelada.toMap());

      transaction.update(deporteRef, {
        'cuposOcupados': deporte.cuposOcupados - 1,
        if (inscripcion.estado == EstadoInscripcion.confirmada)
          'cuposConfirmados': deporte.cuposConfirmados - 1,
      });
    });
  }

  // ---------------------------------------------------------
  // 3. CONSULTAR INSCRIPCIONES DEL ESTUDIANTE
  // ---------------------------------------------------------

  @override
  Stream<List<Inscripcion>> observarDeEstudiante(String estudianteUid) {
    final usuario = auth.currentUser;

    if (usuario == null || usuario.uid != estudianteUid) {
      return Stream.error(
        const InscripcionException(
          'No tienes permiso para consultar estas inscripciones.',
        ),
      );
    }

    return firestore
        .collection('inscripciones')
        .where('estudianteUid', isEqualTo: estudianteUid)
        .snapshots()
        .map((snapshot) {
          final inscripciones = snapshot.docs
              .map((doc) => Inscripcion.fromMap(doc.id, doc.data()))
              .toList();

          // Mostrar primero las inscripciones más recientes.
          inscripciones.sort(
            (a, b) => b.fechaInscripcion.compareTo(a.fechaInscripcion),
          );

          return inscripciones;
        });
  }

  // ---------------------------------------------------------
  // 4. CONSULTAR INSCRITOS CONFIRMADOS DEL DEPORTE
  // ---------------------------------------------------------

  @override
  Stream<List<Inscripcion>> observarConfirmadasDeDeporte(String codigoDeporte) {
    return firestore
        .collection('inscripciones')
        .where('deporteId', isEqualTo: codigoDeporte)
        .where('estado', isEqualTo: EstadoInscripcion.confirmada.name)
        .snapshots()
        .map((snapshot) {
          final inscripciones = snapshot.docs
              .map((doc) => Inscripcion.fromMap(doc.id, doc.data()))
              .toList();

          // Ordenar estudiantes alfabéticamente.
          inscripciones.sort(
            (a, b) => a.estudianteNombre.compareTo(b.estudianteNombre),
          );

          return inscripciones;
        });
  }

  // ---------------------------------------------------------
  // 5. CONSULTAR TODAS LAS INSCRIPCIONES
  // ---------------------------------------------------------

  @override
  Stream<List<Inscripcion>> observarTodas() {
    return firestore.collection('inscripciones').snapshots().map((snapshot) {
      final inscripciones = snapshot.docs
          .map((doc) => Inscripcion.fromMap(doc.id, doc.data()))
          .toList();

      // Ordenar por fecha, de la más reciente a la antigua.
      inscripciones.sort(
        (a, b) => b.fechaInscripcion.compareTo(a.fechaInscripcion),
      );

      return inscripciones;
    });
  }

  // ---------------------------------------------------------
  // 6. CONFIRMAR INSCRIPCIÓN DESPUÉS DEL PAGO
  // ---------------------------------------------------------

  @override
  Future<void> confirmar(String inscripcionId, {required String pagoId}) {
    // Pendiente de integrar con el módulo de pagos de Andrés.
    // La aprobación del pago debe verificarse de forma segura.
    throw UnimplementedError('Confirmación de pago pendiente');
  }

  // ---------------------------------------------------------
  // 7. EXPIRAR UNA INSCRIPCIÓN
  // ---------------------------------------------------------

  @override
  Future<void> expirar(String inscripcionId, {required String motivo}) {
    throw UnimplementedError('Expiración de inscripción pendiente');
  }

  // ---------------------------------------------------------
  // 8. EXPIRAR INSCRIPCIONES VENCIDAS
  // ---------------------------------------------------------

  @override
  Future<int> expirarVencidas() {
    throw UnimplementedError('Expiración de inscripciones vencidas pendiente');
  }
}
