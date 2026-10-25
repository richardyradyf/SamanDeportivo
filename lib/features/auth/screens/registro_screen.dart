
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/registro_controller.dart';

// Pantalla principal de registro.
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

// Formulario de registro de estudiantes.
class _FormularioRegistro extends StatefulWidget {
  const _FormularioRegistro();

  @override
  State<_FormularioRegistro> createState() =>
      _FormularioRegistroState();
}

class _FormularioRegistroState extends State<_FormularioRegistro> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de los campos.
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

  // Validar el formulario utilizando RegistroController.
  void _validarRegistro() {
    final formularioValido =
        _formKey.currentState!.validate();

    if (!formularioValido) {
      return;
    }

    final controller = context.read<RegistroController>();

    final error = controller.validarDatos(
      nombre: _nombreController.text,
      cedula: _cedulaController.text,
      carnet: _carnetController.text,
      correo: _correoController.text,
      contrasena: _contrasenaController.text,
    );

    if (error != null) {
      controller.mostrarError(error);
      return;
    }

    controller.limpiarEstado();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Datos validados. Registro en Firebase pendiente.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Validaciones que se muestran debajo de cada campo.
  String? _validarCampo(String etiqueta, String? valor) {
    final texto = valor?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Este campo es obligatorio';
    }

    // Nombre y apellido.
    if (etiqueta == 'Nombre completo') {
      final palabras = texto.split(RegExp(r'\s+'));

      if (palabras.length < 2 ||
          palabras.any((palabra) => palabra.length < 2)) {
        return 'Ingresa un nombre y un apellido válidos';
      }

      if (!RegExp(
        r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$',
      ).hasMatch(texto)) {
        return 'El nombre solo debe contener letras';
      }
    }

    // Cédula numérica.
    if (etiqueta == 'Cédula') {
      if (!RegExp(r'^[0-9]+$').hasMatch(texto)) {
        return 'La cédula debe contener solo números';
      }
    }

    // Correo institucional.
    if (etiqueta == 'Correo electrónico') {
      final correoValido = RegExp(
        r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
        caseSensitive: false,
      );

      if (!correoValido.hasMatch(texto)) {
        return 'Utiliza un correo institucional UNIMET';
      }
    }

    // Contraseña.
    if (etiqueta == 'Contraseña') {
      if (valor!.length < 6) {
        return 'Debe tener al menos 6 caracteres';
      }
    }

    // Confirmar contraseña.
    if (etiqueta == 'Confirmar contraseña') {
      if (valor != _contrasenaController.text) {
        return 'Las contraseñas no coinciden';
      }
    }

    return null;
  }

  // Campo reutilizable del formulario.
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
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.deepOrange,
              width: 2,
            ),
          ),
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
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
                  const Icon(
                    Icons.sports,
                    size: 65,
                    color: Colors.deepOrange,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    '¡Únete a Samán Deportivo!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Completa tus datos para crear tu cuenta',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Nombre y apellido.
                  _campo(
                    'Nombre completo',
                    _nombreController,
                  ),

                  // Cédula.
                  _campo(
                    'Cédula',
                    _cedulaController,
                    tipoTeclado: TextInputType.number,
                    filtros: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),

                  // Número de carnet.
                  _campo(
                    'Número de carnet',
                    _carnetController,
                  ),

                  // Correo institucional.
                  _campo(
                    'Correo electrónico',
                    _correoController,
                    tipoTeclado: TextInputType.emailAddress,
                  ),

                  // Contraseña.
                  _campo(
                    'Contraseña',
                    _contrasenaController,
                    ocultar: true,
                  ),

                  // Confirmación.
                  _campo(
                    'Confirmar contraseña',
                    _confirmarController,
                    ocultar: true,
                  ),

                  // Mostrar errores del controlador.
                  if (registro.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      registro.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: registro.cargando
                        ? null
                        : _validarRegistro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: registro.cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
