
enum ResultadoInscripcion {
  permitida,
  estudianteInactivo,
  estudianteInsolvente,
  sinCupos,
  inscripcionDuplicada,
}

class ValidacionesInscripcion {
  static ResultadoInscripcion validar({
    required bool estudianteActivo,
    required bool estudianteSolvente,
    required int cuposDisponibles,
    required bool tieneInscripcionVigente,
  }) {
    if (!estudianteActivo) {
      return ResultadoInscripcion.estudianteInactivo;
    }

    if (!estudianteSolvente) {
      return ResultadoInscripcion.estudianteInsolvente;
    }

    if (cuposDisponibles <= 0) {
      return ResultadoInscripcion.sinCupos;
    }

    if (tieneInscripcionVigente) {
      return ResultadoInscripcion.inscripcionDuplicada;
    }

    return ResultadoInscripcion.permitida;
  }

  static String mensaje(ResultadoInscripcion resultado) {
    switch (resultado) {
      case ResultadoInscripcion.permitida:
        return 'El estudiante puede inscribirse correctamente.';

      case ResultadoInscripcion.estudianteInactivo:
        return 'No puedes inscribirte porque tu usuario está inactivo.';

      case ResultadoInscripcion.estudianteInsolvente:
        return 'No puedes inscribirte porque no estás solvente.';

      case ResultadoInscripcion.sinCupos:
        return 'No hay cupos disponibles para este deporte.';

      case ResultadoInscripcion.inscripcionDuplicada:
        return 'Ya tienes una inscripción vigente en este deporte.';
    }
  }
}
