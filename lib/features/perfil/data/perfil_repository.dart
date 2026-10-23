import '../domain/perfil_usuario.dart';

/// Puerto de datos: permite probar la interfaz sin conectar Firebase.
abstract class PerfilRepository {
  Stream<PerfilUsuario?> observarPerfil(String uid);

  /// Solo campos permitidos por las reglas; el rol es inmutable por el cliente.
  Future<void> actualizarPerfil({
    required String uid,
    required String nombre,
    String? carnet,
  });
}
