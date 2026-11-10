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
/// También simula la solvencia de la BD central UNIMET (RF-10):
/// un estudiante inactivo no puede inscribirse.
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

/// Estados de una inscripción (RF-08).
enum EstadoInscripcion {
  pendiente('Pendiente'),
  confirmada('Confirmada'),
  rechazada('Rechazada'),
  cancelada('Cancelada'),
  expirada('Expirada');

  const EstadoInscripcion(this.etiqueta);

  final String etiqueta;

  /// Pendiente y confirmada retienen el cupo; las demás lo liberan.
  bool get ocupaCupo =>
      this == EstadoInscripcion.pendiente ||
      this == EstadoInscripcion.confirmada;

  static EstadoInscripcion desdeTexto(String? texto) {
    return EstadoInscripcion.values.firstWhere(
      (estado) => estado.name == texto,
      orElse: () => throw ArgumentError('Estado de inscripción desconocido: $texto'),
    );
  }
}

/// Estados de un pago con PayPal (RF-12).
enum EstadoPago {
  pendiente('Pendiente'),
  aprobado('Aprobado'),
  rechazado('Rechazado'),
  reembolsado('Reembolsado');

  const EstadoPago(this.etiqueta);

  final String etiqueta;

  static EstadoPago desdeTexto(String? texto) {
    return EstadoPago.values.firstWhere(
      (estado) => estado.name == texto,
      orElse: () => throw ArgumentError('Estado de pago desconocido: $texto'),
    );
  }
}

/// Estado de un estudiante en una sesión de entrenamiento (RF-14).
enum EstadoAsistencia {
  presente('Presente'),
  ausente('Ausente');

  const EstadoAsistencia(this.etiqueta);

  final String etiqueta;

  static EstadoAsistencia desdeTexto(String? texto) {
    return EstadoAsistencia.values.firstWhere(
      (estado) => estado.name == texto,
      orElse: () => EstadoAsistencia.ausente,
    );
  }
}

/// Días de la semana para los horarios de un deporte.
enum DiaSemana {
  lunes('Lunes', 'Lun'),
  martes('Martes', 'Mar'),
  miercoles('Miércoles', 'Mié'),
  jueves('Jueves', 'Jue'),
  viernes('Viernes', 'Vie'),
  sabado('Sábado', 'Sáb'),
  domingo('Domingo', 'Dom');

  const DiaSemana(this.etiqueta, this.abreviatura);

  final String etiqueta;
  final String abreviatura;

  static DiaSemana desdeTexto(String? texto) {
    return DiaSemana.values.firstWhere(
      (dia) => dia.name == texto,
      orElse: () => throw ArgumentError('Día desconocido: $texto'),
    );
  }
}

/// Tipo de disciplina, usado en los filtros del catálogo (RF-06).
enum Disciplina {
  colectivo('Deporte colectivo'),
  individual('Deporte individual'),
  raqueta('Deporte de raqueta'),
  combate('Deporte de combate'),
  acuatico('Deporte acuático');

  const Disciplina(this.etiqueta);

  final String etiqueta;

  static Disciplina desdeTexto(String? texto) {
    return Disciplina.values.firstWhere(
      (disciplina) => disciplina.name == texto,
      orElse: () => Disciplina.individual,
    );
  }
}
