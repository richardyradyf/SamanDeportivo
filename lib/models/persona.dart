import 'administrador.dart';
import 'entrenador.dart';
import 'enums.dart';
import 'estudiante.dart';

/// Clase base abstracta del diagrama de clases (RF-04).
///
/// No se puede crear una "Persona" a secas: todo usuario del sistema
/// es un Estudiante, un Entrenador o un Administrador.
/// Todos se guardan en la misma colección de Firestore: `usuarios`.
abstract class Persona {
  /// UID de Firebase Authentication.
  final String uid;
  final String cedula;
  final String nombre;
  final String correo;

  const Persona({
    required this.uid,
    required this.cedula,
    required this.nombre,
    required this.correo,
  });

  /// Cada subclase indica su rol: así nadie tiene que
  /// pasar el rol "a mano" y no puede quedar inconsistente.
  Rol get rol;

  Map<String, dynamic> toMap() {
    return {
      'cedula': cedula,
      'nombre': nombre,
      'correo': correo,
      'rol': rol.name,
    };
  }

  /// Fábrica: lee el campo `rol` del documento y construye
  /// la subclase correcta. Es el patrón Factory Method.
  ///
  /// [uid] es el ID del documento; [datos] es su contenido.
  factory Persona.fromMap(String uid, Map<String, dynamic> datos) {
    final rol = Rol.desdeTexto(datos['rol'] as String?);

    // El switch es exhaustivo: si mañana se agrega un rol al enum,
    // el compilador obliga a manejarlo aquí.
    return switch (rol) {
      Rol.estudiante => Estudiante.fromMap(uid, datos),
      Rol.entrenador => Entrenador.fromMap(uid, datos),
      Rol.administrador => Administrador.fromMap(uid, datos),
    };
  }
}
