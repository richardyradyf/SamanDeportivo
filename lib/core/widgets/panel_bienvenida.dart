import 'package:flutter/material.dart';

/// Primera sección de cada pantalla de inicio: un saludo grande y, debajo,
/// el contenido propio de cada rol (como en el Figma).
class PanelBienvenida extends StatelessWidget {
  const PanelBienvenida({super.key, required this.saludo, this.contenido});

  /// Texto completo del saludo, por ejemplo "Buenos días, Alejandro 👋".
  final String saludo;

  /// Lo que va debajo del saludo (tarjetas, avisos...). Opcional.
  final Widget? contenido;

  /// "Buenos días" hasta las 11:59, "Buenas tardes" hasta las 18:59 y
  /// "Buenas noches" desde las 19:00.
  static String saludoSegunHora(DateTime hora) {
    if (hora.hour < 12) return 'Buenos días';
    if (hora.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// "Ana María Pérez" -> "Ana".
  static String primerNombre(String nombre) =>
      nombre.trim().split(RegExp(r'\s+')).first;

  /// Une el saludo con el primer nombre: "Hola" + "María Pérez" ->
  /// "Hola, María". Si no hay nombre, deja solo el saludo.
  static String componer(String inicio, String nombre) {
    final primero = primerNombre(nombre);
    return primero.isEmpty ? inicio : '$inicio, $primero';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final extra = contenido;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                saludo,
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (extra != null) ...[const SizedBox(height: 24), extra],
            ],
          ),
        ),
      ),
    );
  }
}
