import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:saman_deportivo/features/admin/dashboard/data/operaciones_dashboard_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_operativo.dart';
import 'package:saman_deportivo/models/busqueda.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';

/// A3.4: indicadores operativos disponibles de forma independiente.
/// Si no hay permiso de lectura, nunca se inventan ceros.
class PanelIndicadoresOperativos extends StatefulWidget {
  const PanelIndicadoresOperativos({
    super.key,
    this.repositorio,
    this.compacto = false,
  });

  final OperacionesDashboardRepository? repositorio;
  final bool compacto;

  @override
  State<PanelIndicadoresOperativos> createState() =>
      _PanelIndicadoresOperativosState();
}

class _PanelIndicadoresOperativosState
    extends State<PanelIndicadoresOperativos> {
  Stream<List<Inscripcion>>? _inscripciones;
  Stream<List<Pago>>? _pagos;
  Stream<List<Busqueda>>? _busquedas;

  @override
  void initState() {
    super.initState();
    _configurarFuentes();
  }

  @override
  void didUpdateWidget(covariant PanelIndicadoresOperativos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repositorio != widget.repositorio) _configurarFuentes();
  }

  void _configurarFuentes() {
    final repositorio =
        widget.repositorio ??
        (Firebase.apps.isNotEmpty
            ? FirestoreOperacionesDashboardRepository()
            : null);
    _inscripciones = repositorio?.observarInscripciones();
    _pagos = repositorio?.observarPagos();
    _busquedas = repositorio?.observarBusquedasRecientes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Indicadores operativos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Fuentes independientes. Una consulta sin permiso no equivale a cero registros.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        _FuentePanel<Inscripcion>(
          titulo: 'Inscripciones',
          clave: 'inscripciones',
          flujo: _inscripciones,
          contenido: (datos) {
            final r = ResumenInscripciones.calcular(datos);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _Cifra(etiqueta: 'Registradas', valor: '${r.total}'),
                    _Cifra(etiqueta: 'Pendientes', valor: '${r.pendientes}'),
                    _Cifra(etiqueta: 'Confirmadas', valor: '${r.confirmadas}'),
                    _Cifra(
                      etiqueta: 'Últimos 30 días',
                      valor: '${r.recientes}',
                    ),
                  ],
                ),
                if (!widget.compacto) ...[
                  const SizedBox(height: 16),
                  for (final estado in EstadoInscripcion.values) ...[
                    Row(
                      children: [
                        Expanded(child: Text(estado.etiqueta)),
                        Text('${r.porEstado[estado] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: r.total == 0
                          ? 0
                          : (r.porEstado[estado] ?? 0) / r.total,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 8),
                const Text(
                  'Se cuentan los documentos actuales; las reinscripciones no '
                  'se contabilizan como registros históricos adicionales.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _FuentePanel<Pago>(
          titulo: 'Pagos',
          clave: 'pagos',
          flujo: _pagos,
          contenido: (datos) {
            final r = ResumenPagos.calcular(datos);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _Cifra(etiqueta: 'Pagos registrados', valor: '${r.total}'),
                    _Cifra(
                      etiqueta: 'Aprobados USD',
                      valor: '${r.aprobadosUsd}',
                    ),
                    _Cifra(
                      etiqueta: 'Monto aprobado USD',
                      valor: 'USD ${r.montoAprobadoUsd.toStringAsFixed(2)}',
                      clave: 'monto-aprobado',
                    ),
                    if (!widget.compacto)
                      _Cifra(
                        etiqueta: 'Reembolsados',
                        valor: '${r.reembolsados}',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Monto bruto de documentos aprobados en USD; no son '
                  'ingresos netos. ${r.aprobadosOtrasMonedas} pago(s) '
                  'aprobado(s) en otras monedas excluido(s).',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _FuentePanel<Busqueda>(
          titulo: 'Búsquedas de los últimos 30 días',
          clave: 'busquedas',
          flujo: _busquedas,
          contenido: (datos) {
            final r = ResumenBusquedas.calcular(datos);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cifra(
                  etiqueta: 'Búsquedas registradas',
                  valor: '${r.eventos}',
                ),
                if (!widget.compacto) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Términos más consultados',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (r.topTerminos.isEmpty)
                    const Text('No hay términos registrados en este período.'),
                  for (final termino in r.topTerminos)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(termino.termino)),
                          Text('${termino.cantidad}'),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Mide eventos de búsqueda, no clics ni inscripciones. '
                  'No se atribuyen búsquedas a un deporte por aparecer '
                  'en los resultados.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FuentePanel<T> extends StatelessWidget {
  const _FuentePanel({
    required this.titulo,
    required this.clave,
    required this.flujo,
    required this.contenido,
  });

  final String titulo;
  final String clave;
  final Stream<List<T>>? flujo;
  final Widget Function(List<T>) contenido;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (flujo == null)
              Text(
                'Fuente no conectada. Inicia Firebase para consultar datos reales.',
                key: Key('a34-no-conectada-$clave'),
              )
            else
              StreamBuilder<List<T>>(
                stream: flujo,
                builder: (context, estado) {
                  if (estado.hasError) {
                    return Text(
                      'Fuente no disponible: revisa los permisos y la '
                      'integración del módulo. No se muestra un valor cero.',
                      key: Key('a34-no-disponible-$clave'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  if (!estado.hasData) {
                    return const Text('Consultando fuente…');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (estado.data!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Consulta permitida; colección sin registros.',
                          ),
                        ),
                      contenido(estado.data!),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor, this.clave});
  final String etiqueta;
  final String valor;
  final String? clave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          key: clave == null ? null : Key('a34-$clave'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
