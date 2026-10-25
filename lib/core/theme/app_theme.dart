import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema visual de Samán Deportivo
///
/// Traduce el sistema de diseño de Figma a un ThemeData de Flutter.
/// Así cada botón, campo o tarjeta toma el estilo correcto sin que
/// las pantallas tengan que configurarlo una por una.
abstract final class AppTheme {
  /// Nombre de la familia declarada en pubspec.yaml.
  static const String fuente = 'DMSans';

  /// Figma: botones y campos con esquinas de 14 px.
  static const double radioControl = 14;

  /// Figma: tarjetas con esquinas de 16–24 px (usamos 20).
  static const double radioTarjeta = 20;

  /// Tema claro de la aplicación.
  static ThemeData get claro {
    // Material 3 genera una paleta completa a partir del color semilla;
    // luego fijamos con copyWith los colores exactos del Figma.
    final esquema =
        ColorScheme.fromSeed(
          seedColor: AppColors.primario,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primario,
          onPrimary: Colors.white,
          primaryContainer: AppColors.suave,
          onPrimaryContainer: AppColors.primario,
          secondary: AppColors.primarioMas,
          onSecondary: Colors.white,
          error: AppColors.peligro,
          onError: Colors.white,
          surface: AppColors.superficie,
          onSurface: AppColors.texto,
          onSurfaceVariant: AppColors.textoSecundario,
          outline: AppColors.borde,
          outlineVariant: AppColors.borde,
        );

    // Borde base de los campos de texto ("Input" en Figma).
    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radioControl),
      borderSide: const BorderSide(color: AppColors.borde),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      fontFamily: fuente,
      scaffoldBackgroundColor: AppColors.fondo,
      textTheme: _textos,

      // Barra superior plana, del mismo color que el fondo (como el Figma).
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fondo,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fuente,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.texto,
        ),
      ),

      // "Button / Primary": verde, texto blanco, 48 px de alto.
      elevatedButtonTheme: ElevatedButtonThemeData(style: _botonPrimario),
      filledButtonTheme: FilledButtonThemeData(style: _botonPrimario),

      // "Button / Secondary": blanco con borde gris.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          backgroundColor: AppColors.superficie,
          side: const BorderSide(color: AppColors.borde),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioControl),
          ),
          textStyle: const TextStyle(
            fontFamily: fuente,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Enlaces como "¿Olvidaste tu contraseña?" o "Crear cuenta".
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primario,
          textStyle: const TextStyle(
            fontFamily: fuente,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Campos de texto: fondo blanco, borde gris; verde al enfocar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: AppColors.textoSecundario),
        hintStyle: const TextStyle(color: AppColors.textoSecundario),
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.primario, width: 2),
        ),
        errorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.peligro),
        ),
        focusedErrorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.peligro, width: 2),
        ),
      ),

      // Tarjetas planas con borde, como "Card / Sport" y las del perfil.
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: const BorderSide(color: AppColors.borde),
        ),
      ),

      // Navegación (la usa el LayoutResponsivo de Gabriel).
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: AppColors.suave,
      ),
      // Figma: sidebar verde oscuro de 240 px en escritorio.
      // La barra inferior movil y el NavigationDrawer conservan su tema claro.
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.primarioOscuro,
        minExtendedWidth: 240,
        useIndicator: true,
        indicatorColor: AppColors.sidebarSeleccion,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: AppColors.sidebarTexto),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fuente,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fuente,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.sidebarTexto,
        ),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: AppColors.suave,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borde,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Estilo compartido por ElevatedButton y FilledButton.
  static final ButtonStyle _botonPrimario = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primario,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radioControl),
    ),
    textStyle: const TextStyle(
      fontFamily: fuente,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Escala tipográfica tomada del Figma.
  /// Uso: Theme.of(context).textTheme.headlineLarge, etc.
  static const TextTheme _textos = TextTheme(
    // "Dashboard / H1 — 36px SemiBold" (ej. "Mi perfil", "Buenos días…").
    headlineLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: AppColors.texto,
    ),
    // Títulos de formularios (ej. "Bienvenido de nuevo", "Crea tu cuenta").
    headlineMedium: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.texto,
    ),
    // Títulos de sección (ej. "Mis disciplinas").
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.texto,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.texto,
    ),
    // Nombre del deporte en las tarjetas (ej. "BALONCESTO").
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.texto,
    ),
    // Figma: el cuerpo de texto nunca baja de 16 px.
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.texto),
    bodyMedium: TextStyle(fontSize: 16, color: AppColors.texto),
    bodySmall: TextStyle(fontSize: 14, color: AppColors.textoSecundario),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    // Etiquetas sobre los campos (ej. "Correo institucional").
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario,
    ),
    // Encabezados de tabla y de tarjeta (ej. "INFORMACIÓN PERSONAL").
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario,
    ),
  );
}
