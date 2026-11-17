import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/reservas/presentation/reservas_espacios_screen.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Acceso común desde los tres roles, sin cambiar sus menús actuales.
class BotonReservas extends StatelessWidget {
  const BotonReservas({super.key, required this.rol, this.usuarioUid});

  final Rol rol;
  final String? usuarioUid;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Reservas de espacios',
    icon: const Icon(Icons.event_available_outlined),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReservasEspaciosScreen(rol: rol, usuarioUid: usuarioUid),
      ),
    ),
  );
}
