import 'enums.dart';
import 'persona.dart';

/// Entrenador de una disciplina (hereda de Persona).
/// Su cuenta la crea el administrador, no se autorregistra.
class Entrenador extends Persona {
  final String especialidad;
  final int aniosExperiencia;

  const Entrenador({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    required this.especialidad,
    required this.aniosExperiencia,
  });

  @override
  Rol get rol => Rol.entrenador;

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'especialidad': especialidad,
      'aniosExperiencia': aniosExperiencia,
    };
  }

  factory Entrenador.fromMap(String uid, Map<String, dynamic> datos) {
    return Entrenador(
      uid: uid,
      cedula: datos['cedula'] as String? ?? '',
      nombre: datos['nombre'] as String? ?? '',
      correo: datos['correo'] as String? ?? '',
      especialidad: datos['especialidad'] as String? ?? '',
      // Firestore puede devolver el número como int o como double,
      // por eso se lee como num y se convierte.
      aniosExperiencia: (datos['aniosExperiencia'] as num?)?.toInt() ?? 0,
    );
  }

  Entrenador copyWith({
    String? nombre,
    String? especialidad,
    int? aniosExperiencia,
  }) {
    return Entrenador(
      uid: uid,
      cedula: cedula,
      nombre: nombre ?? this.nombre,
      correo: correo,
      especialidad: especialidad ?? this.especialidad,
      aniosExperiencia: aniosExperiencia ?? this.aniosExperiencia,
    );
  }
}
