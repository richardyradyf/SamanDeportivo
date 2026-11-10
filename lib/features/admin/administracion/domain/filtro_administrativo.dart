import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';

/// Utiliza la misma normalización de tildes y caracteres que el catálogo.
/// Se conservan los espacios colapsados del filtro administrativo actual.
String normalizarTextoAdministrativo(String texto) =>
    normalizarBusqueda(texto).replaceAll(RegExp(r'\s+'), ' ');
