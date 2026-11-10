import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

/// True si el estudiante puede calificar el deporte [codigoDeporte]: tiene
/// en ese deporte una inscripción confirmada, es decir, ya pagó (RF-17).
///
/// Es la misma condición que revisan las reglas de Firestore antes de
/// guardar la reseña; aquí solo sirve para mostrar u ocultar el formulario.
bool tieneInscripcionConfirmada(List<Inscripcion>? inscripciones, String codigoDeporte) {
  return inscripciones?.any(
        (inscripcion) =>
            inscripcion.deporteId == codigoDeporte &&
            inscripcion.estado == EstadoInscripcion.confirmada,
      ) ??
      false;
}
