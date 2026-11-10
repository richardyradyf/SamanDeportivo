import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';

/// Web: muestra pagar.html en un iframe y escucha el aviso de pago_resultado.html.
class VistaPaypal extends StatefulWidget {
  const VistaPaypal({super.key, required this.url, required this.onTerminar});

  final Uri url;
  final ValueChanged<ResultadoPaypal> onTerminar;

  @override
  State<VistaPaypal> createState() => _VistaPaypalState();
}

class _VistaPaypalState extends State<VistaPaypal> {
  static int _contador = 0;
  late final String _tipo = 'paypal-${_contador++}';
  late final JSFunction _oyente = _alMensaje.toJS;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_tipo, (int _) {
      final marco = web.HTMLIFrameElement()
        ..src = widget.url.toString()
        ..allow = 'payment';
      marco.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      return marco;
    });
    web.window.addEventListener('message', _oyente);
  }

  void _alMensaje(web.MessageEvent e) {
    if (_terminado || e.origin != web.window.location.origin) return;
    final datos = e.data.dartify();
    if (datos is! Map || datos['tipo'] != 'paypal') return;
    _terminado = true;
    widget.onTerminar(ResultadoPaypal.desdeMapa({
      for (final k in ['estado', 'orderId', 'captureId', 'monto'])
        k: datos[k]?.toString(),
    }));
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _oyente);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _tipo);
}
