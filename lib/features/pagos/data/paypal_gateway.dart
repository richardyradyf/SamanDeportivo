import 'package:cloud_functions/cloud_functions.dart';

class PagoException implements Exception {
  const PagoException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class OrdenPaypal {
  const OrdenPaypal({required this.pagoId, required this.urlAprobacion});
  final String pagoId;
  final String urlAprobacion;
}

abstract class PagoGateway {
  Future<OrdenPaypal> crearOrden(String inscripcionId);
  Future<void> capturar(String pagoId);
}

class PaypalGateway implements PagoGateway {
  PaypalGateway([FirebaseFunctions? functions])
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _llamar(
      String nombre, Map<String, dynamic> datos) async {
    try {
      final r = await _functions.httpsCallable(nombre).call(datos);
      return Map<String, dynamic>.from(r.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw PagoException(e.message ?? 'No se pudo completar la operación.');
    }
  }

  @override
  Future<OrdenPaypal> crearOrden(String inscripcionId) async {
    final d = await _llamar('crearOrdenPaypal', {'inscripcionId': inscripcionId});
    return OrdenPaypal(
      pagoId: d['pagoId'] as String,
      urlAprobacion: d['urlAprobacion'] as String,
    );
  }

  @override
  Future<void> capturar(String pagoId) async {
    await _llamar('capturarPagoPaypal', {'pagoId': pagoId});
  }
}