import 'package:cloud_functions/cloud_functions.dart';
import 'package:saman_deportivo/features/admin/entrenadores/domain/gestion_agenda_entrenador.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';

/// La única vía para escribir asignaciones y horarios en Firebase.
/// El backend verifica rol y conflictos dentro de una transacción serializada.
class FirebaseAgendaGateway implements AgendaMutaciones {
  FirebaseAgendaGateway({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<void> guardarAgenda({
    required Deporte deporte,
    required String? entrenadorUid,
    required List<HorarioSesion> horarios,
  }) async {
    await _functions.httpsCallable('guardarAgendaDeporte').call(
      <String, dynamic>{
        'codigoDeporte': deporte.codigo,
        'entrenadorUid': entrenadorUid,
        'horarios': horarios.map((h) => h.toMap()).toList(),
        'expectedVersion': deporte.actualizadoEn?.millisecondsSinceEpoch,
      },
    );
  }
}
