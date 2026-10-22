import 'enums.dart';
import 'persona.dart';

/// Administrador de la coordinación de deportes (hereda de Persona).
/// No tiene campos propios; su diferencia es el rol y, por lo tanto,
/// los permisos que le dan las reglas de Firestore.
class Administrador extends Persona {
  const Administrador({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
  });

  @override
  Rol get rol => Rol.administrador;

  factory Administrador.fromMap(String uid, Map<String, dynamic> datos) {
    return Administrador(
      uid: uid,
      cedula: datos['cedula'] as String? ?? '',
      nombre: datos['nombre'] as String? ?? '',
      correo: datos['correo'] as String? ?? '',
    );
  }

  Administrador copyWith({String? nombre}) {
    return Administrador(
      uid: uid,
      cedula: cedula,
      nombre: nombre ?? this.nombre,
      correo: correo,
    );
  }
}
