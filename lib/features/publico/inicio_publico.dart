import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/auth/screens/login_screen.dart';
import 'package:saman_deportivo/features/auth/screens/registro_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/catalogo_screen.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/detalle_deporte_screen.dart';
import 'package:saman_deportivo/features/publico/landing/landing_screen.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/busqueda_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

/// Lo que ve quien no ha iniciado sesión: el landing, el catálogo y el
/// detalle de cada deporte (Hito 4, "catálogo sin iniciar sesión").
///
/// El AuthGate lo muestra cuando no hay sesión. Desde aquí se abren el
/// login y el registro; cuando el usuario entra, el AuthGate cambia a su
/// pantalla de inicio y esta clase cierra las páginas que abrió.
class InicioPublico extends StatefulWidget {
  const InicioPublico({
    super.key,
    this.deportes,
    this.resenas,
    this.busquedas,
    this.construirLogin,
    this.construirRegistro,
  });

  /// Repositorios para las pruebas; si son null se usa Firestore.
  final DeporteRepository? deportes;
  final ResenaRepository? resenas;
  final BusquedaRepository? busquedas;

  /// Pantallas de login y registro; en las pruebas se cambian por otras.
  final WidgetBuilder? construirLogin;
  final WidgetBuilder? construirRegistro;

  @override
  State<InicioPublico> createState() => _InicioPublicoState();
}

class _InicioPublicoState extends State<InicioPublico> {
  NavigatorState? _navegador;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navegador = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    // Al iniciar sesión el AuthGate quita esta pantalla, pero el login, el
    // catálogo o el detalle que se abrieron desde aquí siguen encima. Se
    // cierran después de este cuadro para que se vea el inicio del rol.
    final navegador = _navegador;
    if (navegador != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navegador.mounted) navegador.popUntil((ruta) => ruta.isFirst);
      });
    }
    super.dispose();
  }

  void _abrir(WidgetBuilder pagina) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: pagina));
  }

  /// La pantalla de login no tiene barra superior porque antes era la
  /// primera de la app. Ahora se abre desde el landing, así que se le pone
  /// una barra con la flecha para volver.
  void _abrirLogin() {
    final login = widget.construirLogin ?? (_) => const LoginScreen();
    _abrir(
      (contexto) => Scaffold(
        appBar: AppBar(title: const Text('Iniciar sesión')),
        body: login(contexto),
      ),
    );
  }

  void _abrirRegistro() =>
      _abrir(widget.construirRegistro ?? (_) => const RegistroScreen());

  void _abrirCatalogo(String texto) {
    _abrir(
      (contexto) => Scaffold(
        appBar: AppBar(
          title: const Text('Deportes'),
          actions: [
            TextButton(
              onPressed: _abrirLogin,
              child: const Text('Iniciar sesión'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: CatalogoScreen(
          repositorio: widget.deportes,
          busquedas: widget.busquedas,
          textoInicial: texto,
          onVerDeporte: _abrirDetalle,
        ),
      ),
    );
  }

  void _abrirDetalle(Deporte deporte) {
    _abrir(
      (contexto) => DetalleDeporteScreen(
        deporte: deporte,
        deportes: widget.deportes,
        resenas: widget.resenas,
        // Sin sesión no se puede inscribir: "Inscribirme" lleva al login.
        onInscribirse: (_) => _abrirLogin(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LandingScreen(
      deportes: widget.deportes,
      onIniciarSesion: _abrirLogin,
      onCrearCuenta: _abrirRegistro,
      onExplorar: _abrirCatalogo,
      onVerDeporte: _abrirDetalle,
    );
  }
}
