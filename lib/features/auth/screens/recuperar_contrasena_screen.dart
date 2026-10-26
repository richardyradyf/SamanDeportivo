import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:saman_deportivo/core/utils/validadores.dart';
import 'package:saman_deportivo/features/auth/controllers/recuperar_contrasena_controller.dart';

/// Pantalla "Recuperar contraseña".
///
/// Capas: pantalla → RecuperarContrasenaController → AuthService → Firebase.
class RecuperarContrasenaScreen extends StatelessWidget {
  const RecuperarContrasenaScreen({
    super.key,
    this.controlador,
    this.correoInicial = '',
  });

  /// Permite inyectar un controller falso en las pruebas.
  final RecuperarContrasenaController? controlador;

  /// Correo que el usuario ya había escrito en el login (puede estar vacío).
  final String correoInicial;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecuperarContrasenaController>(
      create: (_) => controlador ?? RecuperarContrasenaController(),
      child: _Contenido(correoInicial: correoInicial),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.correoInicial});

  final String correoInicial;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoController =
      TextEditingController(text: widget.correoInicial);

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    await context.read<RecuperarContrasenaController>().enviar(
          _correoController.text.trim().toLowerCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final recuperar = context.watch<RecuperarContrasenaController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: recuperar.enviado
                  ? _Confirmacion(
                      onVolver: () => Navigator.of(context).pop(),
                      onOtroCorreo: recuperar.reiniciar,
                    )
                  : _formulario(context, recuperar),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(
    BuildContext context,
    RecuperarContrasenaController recuperar,
  ) {
    final tema = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset, size: 64, color: tema.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Recupera tu contraseña',
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu correo y te enviaremos un enlace para crear una nueva.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'nombre@correo.unimet.edu.ve',
            ),
            validator: Validadores.correo,
            onChanged: (_) => recuperar.limpiarError(),
            onFieldSubmitted: (_) => _enviar(),
          ),
          if (recuperar.error != null) ...[
            const SizedBox(height: 12),
            Text(
              recuperar.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: recuperar.cargando ? null : _enviar,
            child: recuperar.cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }
}

/// Mensaje que se muestra cuando la solicitud se procesó.
class _Confirmacion extends StatelessWidget {
  const _Confirmacion({required this.onVolver, required this.onOtroCorreo});

  final VoidCallback onVolver;
  final VoidCallback onOtroCorreo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: tema.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Si el correo ingresado está registrado, te enviamos un enlace para '
          'crear una nueva contraseña. Revisa también la carpeta de spam.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onVolver,
          child: const Text('Volver al inicio de sesión'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onOtroCorreo,
          child: const Text('Usar otro correo'),
        ),
      ],
    );
  }
}
