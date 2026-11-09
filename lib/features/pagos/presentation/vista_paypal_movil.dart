import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:saman_deportivo/features/pagos/domain/resultado_paypal.dart';

/// Android: abre pagar.html en un WebView y lo cierra al llegar a pago_resultado.html.
class VistaPaypal extends StatefulWidget {
  const VistaPaypal({super.key, required this.url, required this.onTerminar});

  final Uri url;
  final ValueChanged<ResultadoPaypal> onTerminar;

  @override
  State<VistaPaypal> createState() => _VistaPaypalState();
}

class _VistaPaypalState extends State<VistaPaypal> {
  bool _terminado = false;

  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (r) =>
          _revisar(r.url) ? NavigationDecision.prevent : NavigationDecision.navigate,
      onPageStarted: _revisar,
    ))
    ..loadRequest(widget.url);

  bool _revisar(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.path.endsWith('pago_resultado.html')) return false;
    if (!_terminado) {
      _terminado = true;
      widget.onTerminar(ResultadoPaypal.desdeMapa(uri.queryParameters));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
