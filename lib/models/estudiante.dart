import 'enums.dart';
import 'persona.dart';

/// Estudiante de la UNIMET (hereda de Persona).
/// Es el único rol que puede registrarse por sí mismo.
class Estudiante extends Persona {
  final String carnet;
  /// Número internacional E.164, por ejemplo +584121234567.
  /// Opcional para mantener la lectura de perfiles creados antes del Hito 4.
  final String? telefono;
  final EstadoEstudiante estado;

  const Estudiante({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    required this.carnet,
    this.telefono,
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
      if (telefono?.isNotEmpty ?? false) 'telefono': telefono,
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
      telefono: datos['telefono'] as String?,
      estado: EstadoEstudiante.desdeTexto(datos['estado'] as String?),
    );
  }

  /// Crea una copia cambiando solo los campos indicados.
  /// La usará la pantalla de perfil para editar sin mutar el objeto.
  Estudiante copyWith({
    String? nombre,
    String? carnet,
    String? telefono,
    EstadoEstudiante? estado,
  }) {
    return Estudiante(
      uid: uid,
      cedula: cedula, // La cédula identifica a la persona: no se edita.
      nombre: nombre ?? this.nombre,
      correo: correo, // El correo lo gestiona Firebase Auth.
      carnet: carnet ?? this.carnet,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
    );
  }
}
