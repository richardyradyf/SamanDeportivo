import 'package:flutter/material.dart';

/// Paleta oficial de Samán Deportivo.
///
/// Es una copia fiel de la página "01 — System" del prototipo en Figma.
/// Cada constante indica entre comillas el nombre que tiene en Figma,
/// para que cualquiera pueda comparar.
///
/// REGLA DEL EQUIPO: ninguna pantalla escribe Color(0xFF...) a mano.
/// Se usa el tema (Theme.of(context)) o, si hace falta, estas constantes.
/// Si el diseño cambia en Figma, se cambia SOLO aquí.
abstract final class AppColors {
  // ---------- Marca ----------

  /// "Primary": botones principales, enlaces, textos de éxito.
  static const Color primario = Color(0xFF06452B);

  /// "Primary +": variante más clara del primario.
  static const Color primarioMas = Color(0xFF0A633D);

  /// Verde muy oscuro del menú lateral y del panel izquierdo del login.
  static const Color primarioOscuro = Color(0xFF05291A);

  /// Figma 13 — Perfil estudiante: fondo de destino seleccionado.
  static const Color sidebarSeleccion = Color(0xFF144730);

  /// Figma: texto e iconos de destinos no seleccionados.
  static const Color sidebarTexto = Color(0xFFC7DBCF);

  /// Figma: etiqueta del rol debajo de SAMÁN.
  static const Color sidebarRol = Color(0xFFA1C2AD);

  /// "Soft": fondos suaves (etiqueta "Disponible", avatar del perfil).
  static const Color suave = Color(0xFFE3F2E8);

  // ---------- Superficies ----------

  /// Fondo general de las pantallas.
  static const Color fondo = Color(0xFFF6F9F7);

  /// "Surface": tarjetas, campos de texto, botones secundarios.
  static const Color superficie = Colors.white;

  /// Borde de tarjetas, campos y botones secundarios.
  static const Color borde = Color(0xFFDBE3DE);

  // ---------- Texto ----------

  /// Texto principal (títulos y contenido).
  static const Color texto = Color(0xFF0A140F);

  /// Texto secundario (etiquetas de campos, descripciones, placeholders).
  static const Color textoSecundario = Color(0xFF57635C);

  // ---------- Estados ----------

  /// "Warning".
  static const Color advertencia = Color(0xFFE08F14);

  /// "Danger": errores y acciones destructivas.
  static const Color peligro = Color(0xFFC72929);

  /// "Info".
  static const Color info = Color(0xFF2963BF);

  // ---------- Etiquetas de cupos (se usarán en el catálogo, Hito 3) ----------
  // Figma: "Badge / Disponible", "Badge / Pocos cupos", "Badge / Completo".
  // Regla del Figma: el estado SIEMPRE lleva texto, nunca solo color.

  static const Color disponibleFondo = suave;
  static const Color disponibleTexto = primario;
  static const Color pocosCuposFondo = Color(0xFFFFF2D1);
  static const Color pocosCuposTexto = Color(0xFFA35E08);
  static const Color completoFondo = Color(0xFFFCE5E5);
  static const Color completoTexto = peligro;
}
