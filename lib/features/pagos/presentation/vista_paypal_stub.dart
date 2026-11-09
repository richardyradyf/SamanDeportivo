import 'package:flutter/widgets.dart';

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';

class VistaPaypal extends StatelessWidget {
  const VistaPaypal({super.key, required this.url, required this.onTerminar});

  final Uri url;
  final ValueChanged<ResultadoPaypal> onTerminar;

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('El pago con PayPal no está disponible en esta plataforma.'),
      );
}
