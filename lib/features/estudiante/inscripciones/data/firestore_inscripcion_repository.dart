import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';
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
  // 1. INSCRIBIRSE
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
      final estudianteDoc = await transaction.get(estudianteRef);
      final deporteDoc = await transaction.get(deporteRef);
      final inscripcionDoc = await transaction.get(inscripcionRef);

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

      if (!estudianteActual.estaActivo) {
        throw InscripcionException.estudianteInactivo;
      }

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

      final pendienteVencida = anterior != null && anterior.estaVencida(ahora);

      if (anterior != null && anterior.ocupaCupo && !pendienteVencida) {
        throw InscripcionException.yaInscrito;
      }

      final cuposLiberados = pendienteVencida ? 1 : 0;

      final ocupadosAjustados = deporteActual.cuposOcupados - cuposLiberados;

      if (ocupadosAjustados < 0) {
        throw const InscripcionException(
          'Los contadores de cupos necesitan revisión.',
        );
      }

      if (ocupadosAjustados >= deporteActual.cupoMaximo) {
        throw InscripcionException.sinCupos;
      }

      Inscripcion nuevaInscripcion;

      if (anterior == null) {
        nuevaInscripcion = Inscripcion.nueva(
          estudiante: estudianteActual,
          deporte: deporteActual,
          ahora: ahora,
        );
      } else {
        final inscripcionAnterior = pendienteVencida
            ? anterior.conEstado(
                EstadoInscripcion.expirada,
                responsableUid: estudiante.uid,
                motivo: 'Plazo de pago vencido',
                fecha: ahora,
              )
            : anterior;

        nuevaInscripcion = inscripcionAnterior.reinscribir(
          estudiante: estudianteActual,
          deporte: deporteActual,
          ahora: ahora,
        );
      }

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

      if (inscripcion.estudianteUid != usuario.uid) {
        throw const InscripcionException(
          'No puedes cancelar una inscripción de otro estudiante.',
        );
      }

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

      transaction.update(inscripcionRef, cancelada.toMap());

      transaction.update(deporteRef, {
        'cuposOcupados': deporte.cuposOcupados - 1,
        if (inscripcion.estado == EstadoInscripcion.confirmada)
          'cuposConfirmados': deporte.cuposConfirmados - 1,
      });
    });
  }

  // ---------------------------------------------------------
  // 3. EXPIRAR UNA INSCRIPCIÓN VENCIDA
  // ---------------------------------------------------------

  @override
  Future<void> expirar(String inscripcionId, {required String motivo}) async {
    final resultado = await _expirarSiVencida(inscripcionId, motivo: motivo);

    if (!resultado) {
      throw const InscripcionException(
        'La inscripción no está pendiente y vencida.',
      );
    }
  }

  // Expira una reserva vencida y libera su cupo.
  // Devuelve false si ya no corresponde expirar.
  Future<bool> _expirarSiVencida(
    String inscripcionId, {
    required String motivo,
  }) async {
    final usuario = auth.currentUser;

    if (usuario == null) {
      throw const InscripcionException('Debes iniciar sesión.');
    }

    final inscripcionRef = firestore
        .collection('inscripciones')
        .doc(inscripcionId);

    return firestore.runTransaction((transaction) async {
      final inscripcionDoc = await transaction.get(inscripcionRef);

      if (!inscripcionDoc.exists || inscripcionDoc.data() == null) {
        return false;
      }

      final inscripcion = Inscripcion.fromMap(
        inscripcionId,
        inscripcionDoc.data()!,
      );

      // Esta implementación local solo trabaja con
      // inscripciones del estudiante autenticado.
      if (inscripcion.estudianteUid != usuario.uid) {
        throw const InscripcionException(
          'No tienes permiso para modificar esta inscripción.',
        );
      }

      final ahora = DateTime.now();

      if (!inscripcion.estaVencida(ahora)) {
        return false;
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

      if (deporte.cuposOcupados <= 0) {
        throw const InscripcionException(
          'Los contadores de cupos necesitan revisión.',
        );
      }

      final expirada = inscripcion.conEstado(
        EstadoInscripcion.expirada,
        responsableUid: usuario.uid,
        motivo: motivo,
        fecha: ahora,
      );

      transaction.update(inscripcionRef, expirada.toMap());

      transaction.update(deporteRef, {
        'cuposOcupados': deporte.cuposOcupados - 1,
      });

      return true;
    });
  }

  // ---------------------------------------------------------
  // 4. EXPIRAR RESERVAS VENCIDAS DEL ESTUDIANTE ACTUAL
  // ---------------------------------------------------------

  @override
  Future<int> expirarVencidas() async {
    final usuario = auth.currentUser;

    if (usuario == null) {
      throw const InscripcionException('Debes iniciar sesión.');
    }

    final ahora = DateTime.now();

    final consulta = await firestore
        .collection('inscripciones')
        .where('estudianteUid', isEqualTo: usuario.uid)
        .where('estado', isEqualTo: EstadoInscripcion.pendiente.name)
        .where('fechaLimitePago', isLessThan: Timestamp.fromDate(ahora))
        .get();

    int totalExpiradas = 0;

    for (final documento in consulta.docs) {
      final expirada = await _expirarSiVencida(
        documento.id,
        motivo: 'Plazo de pago vencido',
      );

      if (expirada) {
        totalExpiradas++;
      }
    }

    return totalExpiradas;
  }

  // ---------------------------------------------------------
  // 5. CONSULTAR INSCRIPCIONES DEL ESTUDIANTE
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

          inscripciones.sort(
            (a, b) => b.fechaInscripcion.compareTo(a.fechaInscripcion),
          );

          return inscripciones;
        });
  }

  // ---------------------------------------------------------
  // 6. CONSULTAR CONFIRMADAS DE UN DEPORTE
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

          inscripciones.sort(
            (a, b) => a.estudianteNombre.compareTo(b.estudianteNombre),
          );

          return inscripciones;
        });
  }

  // ---------------------------------------------------------
  // 7. CONSULTAR TODAS LAS INSCRIPCIONES
  // ---------------------------------------------------------

  @override
  Stream<List<Inscripcion>> observarTodas() {
    return firestore.collection('inscripciones').snapshots().map((snapshot) {
      final inscripciones = snapshot.docs
          .map((doc) => Inscripcion.fromMap(doc.id, doc.data()))
          .toList();

      inscripciones.sort(
        (a, b) => b.fechaInscripcion.compareTo(a.fechaInscripcion),
      );

      return inscripciones;
    });
  }

  // ---------------------------------------------------------
  // 8. CONFIRMAR INSCRIPCIÓN DESPUÉS DEL PAGO
  // ---------------------------------------------------------

  // Sin Cloud Functions (plan gratuito), el pago lo captura PayPal en el
  // navegador y la app lo registra aquí. Las reglas de Firestore validan que
  // el pago sea del estudiante, que el monto sea el costo del deporte y que
  // las tres escrituras vayan juntas. Limitación conocida del modo sandbox:
  // no se verifica la captura contra la API de PayPal (se audita en RF-12).
  @override
  Future<void> confirmar(String inscripcionId, {required Pago pago}) async {
    final usuario = auth.currentUser;

    if (usuario == null || usuario.uid != pago.estudianteUid) {
      throw const InscripcionException(
        'Debes iniciar sesión con tu cuenta de estudiante.',
      );
    }

    if (!pago.estaAprobado ||
        pago.paypalCaptureId == null ||
        pago.id != pago.paypalOrderId ||
        pago.inscripcionId != inscripcionId) {
      throw const InscripcionException('Los datos del pago no son válidos.');
    }

    final inscripcionRef = firestore
        .collection('inscripciones')
        .doc(inscripcionId);
    final pagoRef = firestore.collection('pagos').doc(pago.id);

    await firestore.runTransaction((transaction) async {
      final inscripcionDoc = await transaction.get(inscripcionRef);

      if (!inscripcionDoc.exists || inscripcionDoc.data() == null) {
        throw const InscripcionException('La inscripción no existe.');
      }

      final inscripcion = Inscripcion.fromMap(
        inscripcionId,
        inscripcionDoc.data()!,
      );

      if (inscripcion.estudianteUid != usuario.uid) {
        throw const InscripcionException(
          'No puedes pagar una inscripción de otro estudiante.',
        );
      }

      if (inscripcion.estado != EstadoInscripcion.pendiente) {
        throw const InscripcionException(
          'Esta inscripción ya no está pendiente de pago.',
        );
      }

      final ahora = DateTime.now();

      if (inscripcion.estaVencida(ahora)) {
        throw const InscripcionException('El plazo de pago ya venció.');
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

      if ((deporte.costo - pago.monto).abs() > 0.005) {
        throw const InscripcionException(
          'El monto pagado no coincide con el costo del deporte.',
        );
      }

      if (deporte.cuposConfirmados >= deporte.cuposOcupados) {
        throw const InscripcionException(
          'Los contadores de cupos necesitan revisión.',
        );
      }

      final pagoDoc = await transaction.get(pagoRef);

      if (pagoDoc.exists) {
        throw const InscripcionException('Este pago ya fue registrado.');
      }

      transaction.set(pagoRef, pago.toMap());

      transaction.update(inscripcionRef, {
        'estado': EstadoInscripcion.confirmada.name,
        'pagoId': pago.id,
        'historial': FieldValue.arrayUnion([
          CambioEstado(
            estado: EstadoInscripcion.confirmada,
            fecha: ahora,
            responsableUid: usuario.uid,
          ).toMap(),
        ]),
      });

      transaction.update(deporteRef, {
        'cuposConfirmados': deporte.cuposConfirmados + 1,
      });
    });
  }
}