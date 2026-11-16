import 'dart:async';

/// Evita declarar como inválida una cuenta recién creada mientras Firestore
/// termina de recibir su perfil. No oculta el error indefinidamente.
class EsperaPerfil {
  EsperaPerfil({this.duracion = const Duration(seconds: 10)});

  final Duration duracion;
  Timer? _temporizador;

  bool get pendiente => _temporizador?.isActive ?? false;

  /// Los snapshots vacíos sucesivos comparten un único período de gracia.
  void iniciar(void Function() alVencer) {
    if (pendiente) return;
    _temporizador = Timer(duracion, () {
      _temporizador = null;
      alVencer();
    });
  }

  /// El temporizador anterior nunca puede disparar su callback tras cancelar.
  void cancelar() {
    _temporizador?.cancel();
    _temporizador = null;
  }
}
