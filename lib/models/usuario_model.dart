
class UsuarioModel {
  final String uid;
  final String cedula;
  final String nombre;
  final String correo;
  final String rol;

  // Datos específicos del estudiante
  final String? carnet;
  final String? estado;

  // Datos específicos del entrenador
  final String? especialidad;
  final int? aniosExperiencia;

  UsuarioModel({
    required this.uid,
    required this.cedula,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.carnet,
    this.estado,
    this.especialidad,
    this.aniosExperiencia,
  });

  // Convertir los datos del usuario en un mapa para Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'cedula': cedula,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'carnet': carnet,
      'estado': estado,
      'especialidad': especialidad,
      'aniosExperiencia': aniosExperiencia,
    };
  }

  // Crear un usuario a partir de los datos de Firestore.
  factory UsuarioModel.fromMap(Map<String, dynamic> datos) {
    return UsuarioModel(
      uid: datos['uid'] as String,
      cedula: datos['cedula'] as String,
      nombre: datos['nombre'] as String,
      correo: datos['correo'] as String,
      rol: datos['rol'] as String,
      carnet: datos['carnet'] as String?,
      estado: datos['estado'] as String?,
      especialidad: datos['especialidad'] as String?,
      aniosExperiencia: datos['aniosExperiencia'] as int?,
    );
  }
}
