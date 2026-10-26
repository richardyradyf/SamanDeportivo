import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/utils/validadores.dart';
import 'package:saman_deportivo/features/auth/controllers/login_controller.dart';
import 'package:saman_deportivo/features/auth/screens/recuperar_contrasena_screen.dart';
import 'package:saman_deportivo/features/auth/screens/registro_screen.dart';

/// Pantalla de inicio de sesión (la ven quienes no tienen sesión).
///
/// Capas: pantalla → LoginController → AuthService → Firebase.
/// La pantalla NO navega al iniciar sesión: el SesionController detecta la
/// sesión y el AuthGate muestra el inicio que corresponde al rol.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.controlador});

  /// Permite inyectar un controller falso en las pruebas.
  /// En la app normal es null y se crea el real.
  final LoginController? controlador;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginController>(
      create: (_) => controlador ?? LoginController(),
      child: const _PaginaLogin(),
    );
  }
}

/// Ancho desde el cual se muestra el panel de marca a la izquierda
/// (escritorio). En tablet y móvil solo se ve el formulario.
const double _anchoEscritorio = 900;

class _PaginaLogin extends StatelessWidget {
  const _PaginaLogin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, restricciones) {
          final esEscritorio = restricciones.maxWidth >= _anchoEscritorio;
          return Row(
            children: [
              if (esEscritorio) const Expanded(child: _PanelMarca()),
              Expanded(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: _FormularioLogin(mostrarMarca: !esEscritorio),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Panel verde oscuro de la izquierda (solo en pantallas anchas).
class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      color: AppColors.primarioOscuro,
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              'Samán Deportivo',
              textAlign: TextAlign.center,
              style: textos.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Gestiona tus actividades deportivas en la UNIMET',
              textAlign: TextAlign.center,
              style: textos.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioLogin extends StatefulWidget {
  const _FormularioLogin({required this.mostrarMarca});

  /// true en móvil y tablet: no hay panel lateral, la marca va arriba.
  final bool mostrarMarca;

  @override
  State<_FormularioLogin> createState() => _FormularioLoginState();
}

class _FormularioLoginState extends State<_FormularioLogin> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  /// Valida los campos y, si están bien, pide el inicio de sesión.
  /// Si funciona no hacemos nada más: el AuthGate cambia la pantalla.
  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<LoginController>().iniciarSesion(
          _correoController.text.trim().toLowerCase(),
          _contrasenaController.text,
        );
  }

  /// Se abre con push (no reemplazo) para que el "pop" del registro
  /// regrese a esta pantalla.
  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegistroScreen()),
    );
  }

  /// Abre la recuperación de contraseña llevando el correo ya escrito.
  void _irARecuperar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecuperarContrasenaScreen(
          correoInicial: _correoController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginController>();
    final tema = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.mostrarMarca) ...[
            Icon(Icons.sports, size: 56, color: tema.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Samán Deportivo',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
          ],
          Text('Bienvenido de nuevo', style: tema.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Ingresa con tu correo y tu contraseña',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          // Correo.
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'nombre@correo.unimet.edu.ve',
            ),
            validator: Validadores.correo,
            onChanged: (_) => login.limpiarError(),
          ),
          const SizedBox(height: 16),
          // Contraseña, con el ojito para mostrarla u ocultarla.
          TextFormField(
            controller: _contrasenaController,
            obscureText: login.contrasenaOculta,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                tooltip: login.contrasenaOculta
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  login.contrasenaOculta
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: login.alternarContrasena,
              ),
            ),
            validator: Validadores.contrasenaLogin,
            onChanged: (_) => login.limpiarError(),
            onFieldSubmitted: (_) => _entrar(),
          ),
          // Enlace a la recuperación de contraseña.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: login.cargando ? null : _irARecuperar,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          // Error de Firebase ya traducido al español.
          if (login.error != null) ...[
            const SizedBox(height: 12),
            Text(
              login.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: login.cargando ? null : _entrar,
            child: login.cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 16),
          // Enlace al registro.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('¿No tienes cuenta?'),
              TextButton(
                onPressed: login.cargando ? null : _irARegistro,
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
