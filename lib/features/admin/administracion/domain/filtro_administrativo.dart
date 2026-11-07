/// Normaliza textos para búsqueda local sin distinguir tildes o mayúsculas.
/// No modifica los datos almacenados en Firestore.
String normalizarTextoAdministrativo(String texto) {
  var resultado = texto.toLowerCase().trim();
  const sustituciones = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  for (final cambio in sustituciones.entries) {
    resultado = resultado.replaceAll(cambio.key, cambio.value);
  }
  return resultado.replaceAll(RegExp(r'\s+'), ' ');
}
