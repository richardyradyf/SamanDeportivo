/// Validación académica y financiera del estudiante (RF-10). Implementa: Mariana.
///
/// No hay acceso a la BD central de la UNIMET, así que se simula con el campo
/// `estado` de `usuarios/{uid}`: solo el administrador lo pasa a `inactivo`.
/// Está en un servicio propio para poder cambiarlo por la consulta real
/// sin tocar las pantallas.
abstract class ValidacionUnimetService {
  /// True si el estudiante está activo y solvente.
  Future<bool> estaHabilitado(String estudianteUid);
}
