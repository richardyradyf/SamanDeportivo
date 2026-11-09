enum EstadoInscripcion { pendiente, confirmada, cancelada, expirada }

class CambioEstadoInscripcion {
  final EstadoInscripcion? anterior;
  final EstadoInscripcion nuevo;
  final DateTime fecha;

  const CambioEstadoInscripcion({
    required this.anterior,
    required this.nuevo,
    required this.fecha,
  });
}

class InscripcionLocal {
  final String id;
  final String estudianteId;
  final String deporteId;
  final EstadoInscripcion estado;
  final List<CambioEstadoInscripcion> historial;

  InscripcionLocal._({
    required this.id,
    required this.estudianteId,
    required this.deporteId,
    required this.estado,
    required List<CambioEstadoInscripcion> historial,
  }) : historial = List.unmodifiable(historial);

  // Crear una inscripción nueva.
  factory InscripcionLocal.nueva({
    required String id,
    required String estudianteId,
    required String deporteId,
    required DateTime fecha,
  }) {
    if (id.trim().isEmpty ||
        estudianteId.trim().isEmpty ||
        deporteId.trim().isEmpty) {
      throw ArgumentError('Los identificadores son obligatorios.');
    }

    return InscripcionLocal._(
      id: id,
      estudianteId: estudianteId,
      deporteId: deporteId,
      estado: EstadoInscripcion.pendiente,
      historial: [
        CambioEstadoInscripcion(
          anterior: null,
          nuevo: EstadoInscripcion.pendiente,
          fecha: fecha,
        ),
      ],
    );
  }

  // Indica si la inscripción todavía está vigente.
  bool get estaVigente =>
      estado == EstadoInscripcion.pendiente ||
      estado == EstadoInscripcion.confirmada;

  // Validar si se permite cambiar de estado.
  bool puedeCambiarA(EstadoInscripcion nuevoEstado) {
    switch (estado) {
      case EstadoInscripcion.pendiente:
        return nuevoEstado == EstadoInscripcion.confirmada ||
            nuevoEstado == EstadoInscripcion.cancelada ||
            nuevoEstado == EstadoInscripcion.expirada;

      case EstadoInscripcion.confirmada:
        return nuevoEstado == EstadoInscripcion.cancelada;

      case EstadoInscripcion.cancelada:
      case EstadoInscripcion.expirada:
        return false;
    }
  }

  // Cambiar el estado y conservar el historial.
  InscripcionLocal cambiarEstado({
    required EstadoInscripcion nuevoEstado,
    required DateTime fecha,
  }) {
    if (!puedeCambiarA(nuevoEstado)) {
      throw StateError('Cambio de estado no permitido.');
    }

    if (fecha.isBefore(historial.last.fecha)) {
      throw ArgumentError('La fecha no puede ser anterior al último cambio.');
    }

    return InscripcionLocal._(
      id: id,
      estudianteId: estudianteId,
      deporteId: deporteId,
      estado: nuevoEstado,
      historial: [
        ...historial,
        CambioEstadoInscripcion(
          anterior: estado,
          nuevo: nuevoEstado,
          fecha: fecha,
        ),
      ],
    );
  }

  // Cancelar la inscripción.
  InscripcionLocal cancelar(DateTime fecha) {
    return cambiarEstado(
      nuevoEstado: EstadoInscripcion.cancelada,
      fecha: fecha,
    );
  }

  // Expirar una inscripción pendiente.
  InscripcionLocal expirar(DateTime fecha) {
    return cambiarEstado(nuevoEstado: EstadoInscripcion.expirada, fecha: fecha);
  }
}
