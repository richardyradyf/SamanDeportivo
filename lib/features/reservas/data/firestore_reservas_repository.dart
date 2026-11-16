import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saman_deportivo/features/reservas/data/reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Escritor para Firebase Spark: transacción desde Flutter y control global
/// compartido con la agenda administrativa (`control/agenda`).
///
/// El control serializa solicitudes de clientes honestos. Las reglas exigen
/// que reserva privada, proyección pública y control cambien juntos, aunque
/// Firestore Rules NO puede demostrar ausencia de solapes arbitrarios.
class FirestoreReservasRepository implements ReservasRepository {
  FirestoreReservasRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _control =>
      _db.collection('control').doc('agenda');

  CollectionReference<Map<String, dynamic>> get _reservas =>
      _db.collection('reservasEspacios');

  CollectionReference<Map<String, dynamic>> get _ocupaciones =>
      _db.collection('ocupacionesEspacios');

  String _usuarioActual() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ReservaEspacioException('Debes iniciar sesión para reservar.');
    }
    return uid;
  }

  static int _version(Map<String, dynamic>? datos) {
    if (datos == null) return 0;
    final valor = datos['version'];
    if (valor is int && valor >= 1) return valor;
    throw const ReservaEspacioException(
      'La disponibilidad cambió. Recarga y vuelve a intentar.',
    );
  }

  @override
  Stream<List<ReservaEspacio>> observarPropias(String usuarioUid) {
    if (_usuarioActual() != usuarioUid) {
      throw const ReservaEspacioException('Solo puedes consultar tus reservas.');
    }
    return _reservas
        .where('usuarioUid', isEqualTo: usuarioUid)
        .snapshots()
        .map((s) {
          final lista = s.docs
              .map((d) => ReservaEspacio.fromMap(d.id, d.data()))
              .toList(growable: false);
          lista.sort((a, b) => a.inicio.compareTo(b.inicio));
          return lista;
        });
  }

  @override
  Future<String> crear({
    required String espacioId,
    required DateTime inicio,
    required DateTime fin,
    required String motivo,
  }) async {
    final uid = _usuarioActual();
    final perfil = await _db.collection('usuarios').doc(uid).get(
      const GetOptions(source: Source.server),
    );
    final datosPerfil = perfil.data();
    if (datosPerfil == null) {
      throw const ReservaEspacioException('Tu perfil no está disponible.');
    }
    final rol = Rol.desdeTexto(datosPerfil['rol'] as String?);

    // La vista se obtiene del servidor, no de caché. La versión global de
    // control invalida esta lectura si otro usuario reserva o el admin cambia
    // horarios mientras preparamos la transacción.
    final controlPrevio = await _control.get(
      const GetOptions(source: Source.server),
    );
    final versionEsperada = _version(controlPrevio.data());
    final catalogo = await _db.collection('deportes').get(
      const GetOptions(source: Source.server),
    );
    final ocupacionesPrevias = await _ocupaciones
        .where('espacioId', isEqualTo: espacioId)
        .where('inicio', isLessThan: Timestamp.fromDate(fin))
        .get(const GetOptions(source: Source.server));
    final espacioRef = _db.collection('espacios').doc(espacioId);
    final nueva = _reservas.doc(); // ID aleatorio, nunca UID o cédula.
    final publica = _ocupaciones.doc(nueva.id);

    await _db.runTransaction<void>((tx) async {
      final controlActual = await tx.get(_control);
      if (_version(controlActual.data()) != versionEsperada) {
        throw const ReservaEspacioException(
          'Otro usuario modificó la disponibilidad. Actualiza e intenta otra vez.',
        );
      }
      final espacioSnap = await tx.get(espacioRef);
      if (espacioSnap.data() == null) {
        throw const ReservaEspacioException('El espacio ya no existe.');
      }
      final espacio = EspacioDeportivo.fromMap(
        espacioSnap.id,
        espacioSnap.data()!,
      );

      final deportes = <Deporte>[];
      for (final candidato in catalogo.docs) {
        final actual = await tx.get(candidato.reference);
        if (actual.data() == null) {
          throw const ReservaEspacioException(
            'El catálogo cambió. Actualiza y vuelve a intentar.',
          );
        }
        deportes.add(Deporte.fromMap(actual.id, actual.data()!));
      }
      final ocupaciones = <OcupacionEspacio>[];
      for (final candidato in ocupacionesPrevias.docs) {
        final actual = await tx.get(candidato.reference);
        if (actual.data() == null) {
          throw const ReservaEspacioException(
            'Las reservas cambiaron. Actualiza y vuelve a intentar.',
          );
        }
        ocupaciones.add(OcupacionEspacio.fromMap(actual.id, actual.data()!));
      }

      ValidacionesReserva.validarSolicitud(
        espacio: espacio,
        rol: rol,
        inicio: inicio,
        fin: fin,
        ahora: DateTime.now(),
        motivo: motivo,
        deportes: deportes,
        ocupaciones: ocupaciones,
      );

      tx.set(nueva, <String, dynamic>{
        'espacioId': espacio.id,
        'usuarioUid': uid,
        'rol': rol.name,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
        'motivo': motivo.trim(),
        'estado': EstadoReservaEspacio.activa.name,
        'creadoEn': FieldValue.serverTimestamp(),
        'actualizadoEn': null,
      });
      tx.set(publica, <String, dynamic>{
        'espacioId': espacio.id,
        'inicio': Timestamp.fromDate(inicio),
        'fin': Timestamp.fromDate(fin),
      });
      tx.set(_control, <String, dynamic>{
        'version': versionEsperada + 1,
        'reservaId': nueva.id,
        'accion': 'crear',
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
    return nueva.id;
  }

  @override
  Future<void> cancelar(String reservaId) async {
    final uid = _usuarioActual();
    final privada = _reservas.doc(reservaId);
    final publica = _ocupaciones.doc(reservaId);

    await _db.runTransaction<void>((tx) async {
      final control = await tx.get(_control);
      final version = _version(control.data());
      final actual = await tx.get(privada);
      final datos = actual.data();
      if (datos == null || datos['usuarioUid'] != uid) {
        throw const ReservaEspacioException('La reserva no te pertenece.');
      }
      if (datos['estado'] != EstadoReservaEspacio.activa.name) {
        throw const ReservaEspacioException('La reserva ya fue cancelada.');
      }
      final ocupacion = await tx.get(publica);
      if (!ocupacion.exists) {
        throw const ReservaEspacioException(
          'La disponibilidad cambió. Actualiza y vuelve a intentar.',
        );
      }

      tx.update(privada, <String, dynamic>{
        'estado': EstadoReservaEspacio.cancelada.name,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      tx.delete(publica);
      tx.set(_control, <String, dynamic>{
        'version': version + 1,
        'reservaId': reservaId,
        'accion': 'cancelar',
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }
}
