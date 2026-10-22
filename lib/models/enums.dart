/// Enumeraciones del dominio de Samán Deportivo.
/// Se guardan en Firestore como texto usando `.name`
/// Usar enums evita valores inválidos como "Estudiantes" o "admin".
library;

/// Rol de cada usuario del sistema (RF-02).
enum Rol {
  estudiante('Estudiante'),
  entrenador('Entrenador'),
  administrador('Administrador');

  const Rol(this.etiqueta);

  final String etiqueta;

  /// Convierte el texto guardado en Firestore al enum.
  /// Si el rol no existe, lanza un error
  static Rol desdeTexto(String? texto) {
    return Rol.values.firstWhere(
      (rol) => rol.name == texto,
      orElse: () => throw ArgumentError('Rol desconocido: $texto'),
    );
  }
}

/// Estado del estudiante. Nace activo; solo el administrador.
enum EstadoEstudiante {
  activo('Activo'),
  inactivo('Inactivo');

  const EstadoEstudiante(this.etiqueta);

  final String etiqueta;

  /// Si el campo no existe en Firestore, se asume activo.
  static EstadoEstudiante desdeTexto(String? texto) {
    return EstadoEstudiante.values.firstWhere(
      (estado) => estado.name == texto,
      orElse: () => EstadoEstudiante.activo,
    );
  }
}
