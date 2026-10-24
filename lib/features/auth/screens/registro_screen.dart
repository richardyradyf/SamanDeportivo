import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de los campos del formulario.
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

  // Validar los datos ingresados.
  void _validarRegistro() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulario validado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Validaciones específicas de cada campo.
  String? _validarCampo(String etiqueta, String? valor) {
    final texto = valor?.trim() ?? '';

    // Verificar que el campo no esté vacío.
    if (texto.isEmpty) {
      return 'Este campo es obligatorio';
    }

    // Nombre y apellido: mínimo dos palabras.
    if (etiqueta == 'Nombre completo') {
      final palabras = texto.split(RegExp(r'\s+'));

      if (palabras.length < 2) {
        return 'Ingresa al menos un nombre y un apellido';
      }

      if (palabras.any((palabra) => palabra.length < 2)) {
        return 'Cada palabra debe tener al menos 2 caracteres';
      }

      if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$')
          .hasMatch(texto)) {
        return 'El nombre solo debe contener letras';
      }
    }

    // Cédula: únicamente números.
    if (etiqueta == 'Cédula') {
      if (!RegExp(r'^[0-9]+$').hasMatch(texto)) {
        return 'La cédula debe contener solo números';
      }
    }

    // Correo institucional de la UNIMET.
    if (etiqueta == 'Correo electrónico') {
      final correoValido = RegExp(
        r'^[A-Za-z0-9._%+-]+@(correo\.unimet\.edu\.ve|unimet\.edu\.ve)$',
        caseSensitive: false,
      );

      if (!correoValido.hasMatch(texto)) {
        return 'Utiliza un correo institucional UNIMET';
      }
    }

    // Contraseña: mínimo seis caracteres.
    if (etiqueta == 'Contraseña') {
      if (valor!.length < 6) {
        return 'La contraseña debe tener al menos 6 caracteres';
      }
    }

    // Confirmación de la contraseña.
    if (etiqueta == 'Confirmar contraseña') {
      if (valor != _contrasenaController.text) {
        return 'Las contraseñas no coinciden';
      }
    }

    return null;
  }

  // Crear campos reutilizables.
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

                  // Cédula: solo números.
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

                  // Confirmar contraseña.
                  _campo(
                    'Confirmar contraseña',
                    _confirmarController,
                    ocultar: true,
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _validarRegistro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Registrarme'),
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
