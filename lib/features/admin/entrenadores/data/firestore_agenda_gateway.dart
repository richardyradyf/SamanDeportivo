import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saman_deportivo/features/admin/entrenadores/domain/gestion_agenda_entrenador.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

/// Agenda compatible con Firebase Spark: no utiliza Cloud Functions.
///
/// Todas las modificaciones de agenda comparten `control/agenda`, cuya version
/// se incrementa en la MISMA transaccion que actualiza el deporte.
/// Las operaciones basadas en una vista vieja se rechazan para que el admin
/// recargue y vuelva a comprobar solapamientos antes de continuar.
///
/// Diseno intencional para un catalogo academico pequeno: se re-lee todo el
/// catalogo dentro de la transaccion. No usar como solucion escalable para
/// miles de deportes sin migrar a indices de ocupacion por franja horaria.
class FirestoreAgendaGateway implements AgendaMutaciones {
  FirestoreAgendaGateway({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _control =>
      _db.collection('control').doc('agenda');

  static int _version(Map<String, dynamic>? datos) {
    if (datos == null) return 0;
    final valor = datos['version'];
    if (valor is int && valor >= 1) return valor;
    throw const AgendaEntrenadorException(
      'El control de agenda tiene una version invalida.',
    );
  }

  @override
  Future<void> guardarAgenda({
    required Deporte deporte,
    required String? entrenadorUid,
    required List<HorarioSesion> horarios,
  }) async {
    final administradorUid = _auth.currentUser?.uid;
    if (administradorUid == null) {
      throw const AgendaEntrenadorException(
        'Inicia sesion como administrador para modificar horarios.',
      );
    }
    ValidacionesAgendaEntrenador.validarHorarios(horarios);

    // Orden obligatorio: version de control, catalogo, transaccion.
    // Si otro administrador cambia una agenda en cualquier intervalo,
    // la version cambiara y la operacion se rechazara (no aceptara datos
    // obsoletos aunque la transaccion de Firestore sea reintentada).
    final controlPrevio = await _control.get(
      const GetOptions(source: Source.server),
    );
    final versionEsperada = _version(controlPrevio.data());
    final catalogo = await _db.collection('deportes').get(
      const GetOptions(source: Source.server),
    );

    if (!catalogo.docs.any((doc) => doc.id == deporte.codigo)) {
      throw AgendaEntrenadorException(
        'El deporte ${deporte.codigo} ya no existe.',
      );
    }

    await _db.runTransaction<void>((tx) async {
      final controlActual = await tx.get(_control);
      if (_version(controlActual.data()) != versionEsperada) {
        throw const AgendaEntrenadorException(
          'Otro administrador modifico la agenda. Recarga y vuelve a intentar.',
        );
      }

      // Firestore permite leer documentos individuales dentro de una
      // transaccion. La consulta se hace antes; el control global evita
      // aceptar instantaneas viejas o conflictos entre dos deportes.
      final actuales = <Deporte>[];
      DocumentReference<Map<String, dynamic>>? destino;
      Deporte? deporteActual;
      for (final candidato in catalogo.docs) {
        final snapshot = await tx.get(candidato.reference);
        final datos = snapshot.data();
        if (datos == null) {
          throw const AgendaEntrenadorException(
            'Cambio el catalogo de deportes. Recarga la agenda.',
          );
        }
        final actual = Deporte.fromMap(snapshot.id, datos);
        actuales.add(actual);
        if (actual.codigo == deporte.codigo) {
          destino = candidato.reference;
          deporteActual = actual;
        }
      }

      if (destino == null || deporteActual == null) {
        throw const AgendaEntrenadorException(
          'El deporte ya no esta disponible. Recarga la agenda.',
        );
      }
      if (deporteActual.actualizadoEn?.millisecondsSinceEpoch !=
          deporte.actualizadoEn?.millisecondsSinceEpoch) {
        throw const AgendaEntrenadorException(
          'El deporte cambio desde que abriste el formulario. Recarga.',
        );
      }

      String? nombre;
      String? especialidad;
      if (entrenadorUid != null) {
        final perfil = await tx.get(
          _db.collection('usuarios').doc(entrenadorUid),
        );
        final info = perfil.data();
        if (info == null || info['rol'] != 'entrenador') {
          throw const AgendaEntrenadorException(
            'El entrenador asignado no existe o no tiene el rol correcto.',
          );
        }
        nombre = info['nombre'] as String?;
        especialidad = info['especialidad'] as String?;
        if (nombre == null || nombre.trim().isEmpty) {
          throw const AgendaEntrenadorException(
            'El entrenador no tiene un nombre valido.',
          );
        }
        ValidacionesAgendaEntrenador.validarSinSolapamientos(
          entrenadorUid: entrenadorUid,
          codigoDeporte: deporte.codigo,
          horarios: horarios,
          deportes: actuales,
        );
      }

      final dias = horarios.map((h) => h.dia.name).toSet().toList();
      tx.update(destino, <String, dynamic>{
        'entrenadorUid': entrenadorUid,
        'entrenadorNombre': nombre,
        'entrenadorEspecialidad': especialidad,
        'horarios': horarios.map((h) => h.toMap()).toList(),
        'dias': dias,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      tx.set(_control, <String, dynamic>{
        'version': versionEsperada + 1,
        'codigoDeporte': deporte.codigo,
        'adminUid': administradorUid,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }
}
