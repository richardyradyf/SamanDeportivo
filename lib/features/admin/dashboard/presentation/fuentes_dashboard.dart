import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';
import 'package:saman_deportivo/models/deporte.dart';

/// Gestiona dos fuentes independientes y hace explícitos errores/permisos.
/// Nunca interpreta una lectura fallida como ausencia de usuarios o deportes.
class FuentesDashboard extends StatefulWidget {
  const FuentesDashboard({
    super.key,
    this.repositorio,
    required this.construir,
  });

  final DashboardRepository? repositorio;
  final Widget Function(BuildContext, ResumenDashboard) construir;

  @override
  State<FuentesDashboard> createState() => _FuentesDashboardState();
}

class _FuentesDashboardState extends State<FuentesDashboard> {
  late final Stream<List<Deporte>>? _deportes;
  late final Stream<List<UsuarioDashboard>>? _usuarios;

  @override
  void initState() {
    super.initState();
    final repo =
        widget.repositorio ??
        (Firebase.apps.isNotEmpty ? FirestoreDashboardRepository() : null);
    _deportes = repo?.observarDeportes();
    _usuarios = repo?.observarUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    if (_deportes == null || _usuarios == null) {
      return const Text('Firebase no está inicializado.');
    }
    return StreamBuilder<List<Deporte>>(
      stream: _deportes,
      builder: (context, deportes) {
        if (deportes.hasError) {
          return _ErrorDashboard(error: deportes.error);
        }
        if (!deportes.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<List<UsuarioDashboard>>(
          stream: _usuarios,
          builder: (context, usuarios) {
            if (usuarios.hasError) {
              return _ErrorDashboard(error: usuarios.error);
            }
            if (!usuarios.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final resumen = ResumenDashboard.calcular(
              deportes: deportes.data!,
              usuarios: usuarios.data!,
            );
            return widget.construir(context, resumen);
          },
        );
      },
    );
  }
}

class _ErrorDashboard extends StatelessWidget {
  const _ErrorDashboard({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Text(
      'No fue posible consultar los indicadores. '
      'Comprueba que iniciaste sesión como administrador y que '
      'Firestore está disponible. Detalle: $error',
      key: const Key('a3-error-fuentes'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
