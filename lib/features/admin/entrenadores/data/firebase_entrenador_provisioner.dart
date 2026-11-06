import 'package:cloud_functions/cloud_functions.dart';

/// No guarda ni transporta contraseñas en Firestore.
/// La invitación es un enlace de un solo uso; el administrador debe compartirlo
/// por un canal seguro. El backend no envía correos automáticamente.
class FirebaseEntrenadorProvisioner {
  FirebaseEntrenadorProvisioner({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String?> crear({
    required String nombre,
    required String correo,
    required String cedula,
    required String especialidad,
    required int aniosExperiencia,
  }) async {
    final result = await _functions.httpsCallable('crearEntrenador').call({
      'nombre': nombre.trim(),
      'correo': correo.trim(),
      'cedula': cedula.trim(),
      'especialidad': especialidad.trim(),
      'aniosExperiencia': aniosExperiencia,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['enlaceInvitacion'] as String?;
  }
}
