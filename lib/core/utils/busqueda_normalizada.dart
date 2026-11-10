/// Normaliza consultas y campos para búsquedas sin distinguir mayúsculas
/// ni tildes. La normalización ocurre solamente en la UI: no altera datos.
String normalizarBusqueda(String texto) {
  return texto
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâäãåā]'), 'a')
      .replaceAll(RegExp(r'[éèêëē]'), 'e')
      .replaceAll(RegExp(r'[íìîïī]'), 'i')
      .replaceAll(RegExp(r'[óòôöõō]'), 'o')
      .replaceAll(RegExp(r'[úùûüū]'), 'u')
      .replaceAll(RegExp(r'[ýÿ]'), 'y')
      .replaceAll(RegExp(r'[ñń]'), 'n')
      .replaceAll(RegExp(r'[çć]'), 'c')
      // También acepta caracteres escritos con diacríticos combinados.
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}
