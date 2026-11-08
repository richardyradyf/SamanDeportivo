import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';

/// Decide cuándo una búsqueda del catálogo se guarda para las métricas
/// (RF-06, RF-18).
///
/// No se guarda una por cada tecla. Una búsqueda cuenta cuando:
/// - el estudiante deja de escribir o de cambiar filtros durante [espera], o
/// - pulsa Enter en el buscador ([confirmar]).
///
/// Tampoco se repite la misma búsqueda dos veces seguidas, ni se guarda
/// el catálogo sin texto ni filtros.
class RegistroBusquedas {
  RegistroBusquedas({
    required this.repositorio,
    this.usuarioUid,
    this.espera = const Duration(seconds: 1),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final BusquedaRepository repositorio;

  /// Null si se busca sin sesión (landing).
  final String? usuarioUid;
  final Duration espera;
  final DateTime Function() _reloj;

  /// Límites de las reglas A3.6.
  static const int maxTermino = 120;
  static const int maxDeportes = 50;

  Timer? _temporizador;
  String? _ultimaClave;

  /// Programa el registro para dentro de [espera]. Si llega otro cambio
  /// antes, el anterior se descarta. [resultados] se calcula al guardar,
  /// para que coincida con lo que el estudiante ve en ese momento.
  void programar(FiltroCatalogo filtro, List<Deporte> Function() resultados) {
    _temporizador?.cancel();
    _temporizador = Timer(
      espera,
      () => unawaited(_registrar(filtro, resultados())),
    );
  }

  /// Guarda la búsqueda ya, sin esperar (Enter en el buscador).
  void confirmar(FiltroCatalogo filtro, List<Deporte> resultados) {
    _temporizador?.cancel();
    unawaited(_registrar(filtro, resultados));
  }

  /// Cancela lo que esté pendiente. Llamar en el dispose de la pantalla.
  void dispose() => _temporizador?.cancel();

  /// Texto y filtros juntos: identifican una búsqueda para no repetirla.
  static String claveDe(FiltroCatalogo filtro) {
    final filtros = filtro.aMapa().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '${normalizarBusqueda(filtro.texto)}|'
        '${filtros.map((e) => '${e.key}=${e.value}').join(',')}';
  }

  Future<void> _registrar(
    FiltroCatalogo filtro,
    List<Deporte> resultados,
  ) async {
    if (filtro.estaVacio) return;
    final clave = claveDe(filtro);
    if (clave == _ultimaClave) return;
    _ultimaClave = clave;

    final texto = filtro.texto.trim();
    try {
      await repositorio.registrar(
        Busqueda(
          id: '',
          termino: texto.length > maxTermino
              ? texto.substring(0, maxTermino)
              : texto,
          filtros: filtro.aMapa(),
          deporteIds: resultados
              .take(maxDeportes)
              .map((d) => d.codigo)
              .toList(growable: false),
          usuarioUid: usuarioUid,
          fecha: _reloj(),
        ),
      );
    } catch (error) {
      // Una métrica que no se guarda no debe romper el catálogo.
      debugPrint('No se pudo registrar la búsqueda: $error');
    }
  }
}
