/// DTO exclusivo de la interfaz Perfil; NO sustituye a Persona (Richard).
/// El rol lo provee el documento de Firestore protegido por reglas.
enum RolPerfil { estudiante, entrenador, administrador }

class PerfilUsuario {
  const PerfilUsuario({
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

  final String uid;
  final String cedula;
  final String nombre;
  final String correo;
  final RolPerfil rol;
  final String? carnet;
  final String? estado;
  final String? especialidad;
  final int? aniosExperiencia;

  static RolPerfil convertirRol(Object? valor) => switch (valor) {
        'estudiante' => RolPerfil.estudiante,
        'entrenador' => RolPerfil.entrenador,
        'administrador' => RolPerfil.administrador,
        _ => throw const FormatException('Rol ausente o no reconocido'),
      };

  factory PerfilUsuario.fromMap(String uid, Map<String, dynamic> datos) {
    String obligatorio(String nombreCampo) {
      final valor = datos[nombreCampo];
      if (valor is! String || valor.trim().isEmpty) {
        throw FormatException('Campo requerido: $nombreCampo');
      }
      return valor.trim();
    }

    String? opcional(String nombreCampo) {
      final valor = datos[nombreCampo];
      return valor is String && valor.trim().isNotEmpty ? valor.trim() : null;
    }

    final rol = convertirRol(datos['rol']);
    if (rol == RolPerfil.estudiante && opcional('carnet') == null) {
      throw const FormatException('El estudiante debe tener carnet');
    }

    return PerfilUsuario(
      uid: uid,
      cedula: obligatorio('cedula'),
      nombre: obligatorio('nombre'),
      correo: obligatorio('correo'),
      rol: rol,
      carnet: opcional('carnet'),
      estado: opcional('estado'),
      especialidad: opcional('especialidad'),
      aniosExperiencia: datos['aniosExperiencia'] is int
          ? datos['aniosExperiencia'] as int
          : null,
    );
  }

  String get nombreRol => switch (rol) {
        RolPerfil.estudiante => 'Estudiante',
        RolPerfil.entrenador => 'Entrenador',
        RolPerfil.administrador => 'Administrador',
      };

  String get iniciales {
    final palabras = nombre.trim().split(RegExp(r'\s+'));
    if (palabras.isEmpty || palabras.first.isEmpty) return '?';
    return [palabras.first[0], if (palabras.length > 1) palabras.last[0]]
        .join()
        .toUpperCase();
  }
}
