
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/registro_controller.dart';

class RegistroScreen extends StatelessWidget {
  const RegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistroController(),
      child: const _FormularioRegistro(),
    );
  }
}

class _FormularioRegistro extends StatefulWidget {
  const _FormularioRegistro();

  @override
  State<_FormularioRegistro> createState() =>
      _FormularioRegistroState();
}

class _FormularioRegistroState extends State<_FormularioRegistro> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _carnetController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _carnetController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  // Realizar el registro del estudiante.
  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final registro = context.read<RegistroController>();

    await registro.registrarEstudiante(
      nombre: _nombreController.text.trim(),
      cedula: _cedulaController.text.trim(),
      carnet: _carnetController.text.trim(),
      correo: _correoController.text.trim().toLowerCase(),
      contrasena: _contrasenaController.text,
    );

    // La pantalla pudo haberse cerrado mientras Firebase respondía.
    if (!mounted) return;

    if (registro.registroExitoso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta registrada correctamente'),
        ),
      );

      // SesionController se encarga de detectar
      // la cuenta y cargar el perfil desde Firestore.
    }
  }

  // Validaciones visuales de los campos.
  String? _validarCampo(String etiqueta, String? valor) {
    final texto = valor?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Este campo es obligatorio';
    }

    if (etiqueta == 'Nombre completo') {
      final palabras = texto.split(RegExp(r'\s+'));

      if (palabras.length < 2 ||
          palabras.any((palabra) => palabra.length < 2)) {
        return 'Ingresa un nombre y apellido válidos';
      }

      if (!RegExp(
        r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$',
      ).hasMatch(texto)) {
        return 'El nombre solo debe contener letras';
      }
    }

    if (etiqueta == 'Cédula') {
      if (!RegExp(r'^[0-9]+$').hasMatch(texto)) {
        return 'La cédula debe contener solo números';
      }
    }

    if (etiqueta == 'Correo electrónico') {
      final correoValido = RegExp(
        r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
        caseSensitive: false,
      );

      if (!correoValido.hasMatch(texto)) {
        return 'Utiliza un correo institucional UNIMET';
      }
    }

    if (etiqueta == 'Contraseña' && valor!.length < 6) {
      return 'Debe tener al menos 6 caracteres';
    }

    if (etiqueta == 'Confirmar contraseña' &&
        valor != _contrasenaController.text) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  // Campo reutilizable con estilos del tema global.
  Widget _campo(
    String etiqueta,
    TextEditingController controller, {
    bool ocultar = false,
    TextInputType tipoTeclado = TextInputType.text,
    List<TextInputFormatter>? filtros,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: ocultar,
        keyboardType: tipoTeclado,
        inputFormatters: filtros,
        decoration: InputDecoration(
          labelText: etiqueta,
        ),
        validator: (valor) => _validarCampo(etiqueta, valor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registro = context.watch<RegistroController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de estudiante'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sports,
                    size: 65,
                    color: Theme.of(context).colorScheme.primary,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '¡Únete a Samán Deportivo!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Completa tus datos para crear tu cuenta',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  _campo(
                    'Nombre completo',
                    _nombreController,
                  ),

                  _campo(
                    'Cédula',
                    _cedulaController,
                    tipoTeclado: TextInputType.number,
                    filtros: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),

                  _campo(
                    'Número de carnet',
                    _carnetController,
                  ),

                  _campo(
                    'Correo electrónico',
                    _correoController,
                    tipoTeclado: TextInputType.emailAddress,
                  ),

                  _campo(
                    'Contraseña',
                    _contrasenaController,
                    ocultar: true,
                  ),

                  _campo(
                    'Confirmar contraseña',
                    _confirmarController,
                    ocultar: true,
                  ),

                  if (registro.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      registro.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: registro.cargando ? null : _registrar,
                    child: registro.cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Registrarme'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
