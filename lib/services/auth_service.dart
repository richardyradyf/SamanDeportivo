
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Usuario que tiene la sesión iniciada.
  User? get usuarioActual => _auth.currentUser;

  // Permite observar los cambios de sesión.
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  // Registrar un usuario con correo y contraseña.
  Future<UserCredential> registrarUsuario({
    required String correo,
    required String contrasena,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  // Iniciar sesión.
  Future<UserCredential> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  // Enviar correo para recuperar la contraseña.
  Future<void> recuperarContrasena(String correo) async {
    await _auth.sendPasswordResetEmail(
      email: correo.trim(),
    );
  }

  // Cerrar sesión.
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }
}
