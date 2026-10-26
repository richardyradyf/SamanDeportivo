import 'enums.dart';
import 'persona.dart';

/// Estudiante de la UNIMET (hereda de Persona).
/// Es el único rol que puede registrarse por sí mismo.
class Estudiante extends Persona {
  final String carnet;
  final EstadoEstudiante estado;

  const Estudiante({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    required this.carnet,
    this.estado = EstadoEstudiante.activo, // Nace activo.
  });

  @override
  Rol get rol => Rol.estudiante;

  bool get estaActivo => estado == EstadoEstudiante.activo;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(), // cedula, nombre, correo y rol
      'carnet': carnet,
      'estado': estado.name,
    };
  }

  factory Estudiante.fromMap(String uid, Map<String, dynamic> datos) {
    return Estudiante(
      uid: uid,
      cedula: datos['cedula'] as String? ?? '',
      nombre: datos['nombre'] as String? ?? '',
      correo: datos['correo'] as String? ?? '',
      carnet: datos['carnet'] as String? ?? '',
      estado: EstadoEstudiante.desdeTexto(datos['estado'] as String?),
    );
  }

  /// Crea una copia cambiando solo los campos indicados.
  /// La usará la pantalla de perfil para editar sin mutar el objeto.
  Estudiante copyWith({
    String? nombre,
    String? carnet,
    EstadoEstudiante? estado,
  }) {
    return Estudiante(
      uid: uid,
      cedula: cedula, // La cédula identifica a la persona: no se edita.
      nombre: nombre ?? this.nombre,
      correo: correo, // El correo lo gestiona Firebase Auth.
      carnet: carnet ?? this.carnet,
      estado: estado ?? this.estado,
    );
  }
}
