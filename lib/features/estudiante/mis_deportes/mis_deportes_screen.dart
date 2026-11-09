import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/data/firestore_asistencia_repository.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/imagen_deporte.dart';
import 'package:saman_deportivo/features/estudiante/mis_deportes/proxima_sesion.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// Pestaña "Mis deportes" del estudiante: su próxima sesión, los deportes
/// en los que tiene la inscripción confirmada y su asistencia en cada uno.
class MisDeportesScreen extends StatelessWidget {
  const MisDeportesScreen({
    super.key,
    required this.inscripciones,
    this.deportes,
    this.asistencias,
    this.estudianteUid,
    this.reloj,
    this.onVerDeporte,
    this.onExplorar,
    this.onVerInscripciones,
  });

  /// Inscripciones del estudiante; null mientras cargan.
  final List<Inscripcion>? inscripciones;
  final DeporteRepository? deportes;
  final AsistenciaRepository? asistencias;
  final String? estudianteUid;
  final DateTime Function()? reloj;
  final ValueChanged<Deporte>? onVerDeporte;
  final VoidCallback? onExplorar;
  final VoidCallback? onVerInscripciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mis deportes',
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ResumenMisDeportes(
                inscripciones: inscripciones,
                deportes: deportes,
                asistencias: asistencias,
                estudianteUid: estudianteUid,
                reloj: reloj,
                mostrarAsistencia: true,
                onVerDeporte: onVerDeporte,
                onExplorar: onExplorar,
                onVerInscripciones: onVerInscripciones,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Próxima sesión y tarjetas de los deportes confirmados. Lo usan la
/// pestaña "Mis deportes" y el "Inicio" del estudiante (como en el Figma).
/// No se desplaza solo: va dentro de la pantalla que lo contiene.
class ResumenMisDeportes extends StatefulWidget {
  const ResumenMisDeportes({
    super.key,
    required this.inscripciones,
    this.deportes,
    this.asistencias,
    this.estudianteUid,
    this.reloj,
    this.mostrarAsistencia = false,
    this.onVerDeporte,
    this.onExplorar,
    this.onVerInscripciones,
  });

  final List<Inscripcion>? inscripciones;
  final DeporteRepository? deportes;
  final AsistenciaRepository? asistencias;
  final String? estudianteUid;
  final DateTime Function()? reloj;

  /// En "Mis deportes" cada tarjeta muestra el porcentaje de asistencia.
  final bool mostrarAsistencia;
  final ValueChanged<Deporte>? onVerDeporte;
  final VoidCallback? onExplorar;
  final VoidCallback? onVerInscripciones;

  /// Hasta cuántos días atrás se cuenta la asistencia: un semestre.
  static const diasDeAsistencia = 180;

  @override
  State<ResumenMisDeportes> createState() => _ResumenMisDeportesState();
}

class _ResumenMisDeportesState extends State<ResumenMisDeportes> {
  // Se crean una vez: si se crearan en build, cada redibujo abriría una
  // consulta nueva a Firestore.
  Stream<List<Deporte>>? _catalogo;
  Stream<List<Asistencia>>? _asistencia;

  DateTime _ahora() => (widget.reloj ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final deportes =
        widget.deportes ??
        (Firebase.apps.isNotEmpty ? FirestoreDeporteRepository() : null);
    _catalogo = deportes?.observarCatalogo();

    final uid = widget.estudianteUid;
    final asistencias =
        widget.asistencias ??
        (Firebase.apps.isNotEmpty ? FirestoreAsistenciaRepository() : null);
    if (widget.mostrarAsistencia && uid != null && asistencias != null) {
      final ahora = _ahora();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      _asistencia = asistencias.observarDeEstudiante(
        uid,
        desde: hoy.subtract(
          const Duration(days: ResumenMisDeportes.diasDeAsistencia),
        ),
        hasta: DateTime(hoy.year, hoy.month, hoy.day + 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inscripciones = widget.inscripciones;
    if (inscripciones == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final confirmadas = [
      for (final i in inscripciones)
        if (i.estado == EstadoInscripcion.confirmada) i,
    ]..sort((a, b) => a.deporteNombre.compareTo(b.deporteNombre));
    final pendientes = inscripciones
        .where((i) => i.estado == EstadoInscripcion.pendiente)
        .length;

    if (confirmadas.isEmpty) {
      return _SinDeportes(
        pendientes: pendientes,
        onExplorar: widget.onExplorar,
        onVerInscripciones: widget.onVerInscripciones,
      );
    }

    return StreamBuilder<List<Deporte>>(
      stream: _catalogo,
      builder: (context, catalogo) {
        final porCodigo = {
          for (final d in catalogo.data ?? const <Deporte>[]) d.codigo: d,
        };
        final mios = [
          for (final i in confirmadas)
            if (porCodigo[i.deporteId] != null) porCodigo[i.deporteId]!,
        ];
        final proxima = proximaSesion(mios, _ahora());

        return StreamBuilder<List<Asistencia>>(
          stream: _asistencia,
          builder: (context, asistencia) {
            final resumen = asistencia.hasData
                ? ResumenAsistenciaDeporte.porDeporte(asistencia.data!)
                : const <String, ResumenAsistenciaDeporte>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (proxima != null) ...[
                  const _Subtitulo('Tu próxima sesión'),
                  _TarjetaProximaSesion(
                    sesion: proxima,
                    ahora: _ahora(),
                    onVerDetalles: widget.onVerDeporte == null
                        ? null
                        : () => widget.onVerDeporte!(proxima.deporte),
                  ),
                  const SizedBox(height: 32),
                ],
                const _Subtitulo('Mis disciplinas'),
                _Cuadricula(
                  children: [
                    for (final inscripcion in confirmadas)
                      _TarjetaMiDeporte(
                        inscripcion: inscripcion,
                        deporte: porCodigo[inscripcion.deporteId],
                        asistencia: !widget.mostrarAsistencia
                            ? null
                            : _TextoAsistencia(
                                cargando:
                                    _asistencia != null &&
                                    asistencia.connectionState ==
                                        ConnectionState.waiting,
                                error: asistencia.hasError,
                                resumen: resumen[inscripcion.deporteId],
                              ),
                        onVer: widget.onVerDeporte,
                      ),
                  ],
                ),
                if (pendientes > 0) ...[
                  const SizedBox(height: 24),
                  _AvisoPendientes(
                    pendientes: pendientes,
                    onVerInscripciones: widget.onVerInscripciones,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// "Tu próxima actividad" del Figma: deporte, día y hora, lugar.
class _TarjetaProximaSesion extends StatelessWidget {
  const _TarjetaProximaSesion({
    required this.sesion,
    required this.ahora,
    this.onVerDetalles,
  });

  final ProximaSesion sesion;
  final DateTime ahora;
  final VoidCallback? onVerDetalles;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lugar = sesion.horario.lugar.trim();
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sesion.deporte.nombre.toUpperCase(),
          style: tema.textTheme.labelLarge?.copyWith(
            color: tema.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cuandoEs(sesion.inicio, ahora),
          key: const Key('proximaSesionCuando'),
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (lugar.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(lugar, style: tema.textTheme.bodyMedium),
        ],
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final boton = onVerDetalles == null
                ? null
                : OutlinedButton(
                    onPressed: onVerDetalles,
                    child: const Text('Ver detalles'),
                  );
            // En celular el botón va debajo; en computadora, a la derecha.
            if (restricciones.maxWidth < 480 || boton == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  datos,
                  if (boton != null) ...[const SizedBox(height: 16), boton],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: datos),
                const SizedBox(width: 16),
                boton,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjetas en columnas que se ajustan al ancho: una en celular, dos o
/// tres en computadora.
class _Cuadricula extends StatelessWidget {
  const _Cuadricula({required this.children});

  final List<Widget> children;

  static const _anchoMinimo = 260.0;
  static const _separacion = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth;
        final columnas = ((ancho + _separacion) / (_anchoMinimo + _separacion))
            .floor()
            .clamp(1, 3);
        final anchoTarjeta =
            (ancho - _separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: _separacion,
          runSpacing: _separacion,
          children: [
            for (final hijo in children)
              SizedBox(width: anchoTarjeta, child: hijo),
          ],
        );
      },
    );
  }
}

/// Tarjeta de un deporte confirmado ("Mis disciplinas" del Figma).
class _TarjetaMiDeporte extends StatelessWidget {
  const _TarjetaMiDeporte({
    required this.inscripcion,
    required this.deporte,
    this.asistencia,
    this.onVer,
  });

  final Inscripcion inscripcion;

  /// Null si el deporte ya no está en el catálogo (por ejemplo, si el
  /// administrador lo desactivó) o mientras carga.
  final Deporte? deporte;
  final Widget? asistencia;
  final ValueChanged<Deporte>? onVer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final secundario = tema.textTheme.bodySmall;
    final deporte = this.deporte;
    final alVer = deporte == null || onVer == null
        ? null
        : () => onVer!(deporte);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alVer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deporte != null)
              SizedBox(height: 80, child: ImagenDeporte(deporte: deporte))
            else
              SizedBox(height: 80, child: ColoredBox(color: colores.secondary)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (deporte?.nombre ?? inscripcion.deporteNombre).toUpperCase(),
                    style: tema.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    deporte == null
                        ? inscripcion.deporteId
                        : resumenHorarios(deporte.horarios),
                    style: secundario,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deporte?.entrenadorNombre case final entrenador?) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Entrenador: $entrenador',
                      style: secundario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    EstadoInscripcion.confirmada.etiqueta,
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: colores.primary,
                    ),
                  ),
                  if (asistencia != null) ...[
                    const SizedBox(height: 4),
                    asistencia!,
                  ],
                  if (alVer != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Ver disciplina',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelLarge?.copyWith(
                              color: colores.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: colores.onSurface,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextoAsistencia extends StatelessWidget {
  const _TextoAsistencia({
    required this.cargando,
    required this.error,
    this.resumen,
  });

  final bool cargando;
  final bool error;
  final ResumenAsistenciaDeporte? resumen;

  @override
  Widget build(BuildContext context) {
    final resumen = this.resumen;
    final texto = cargando
        ? 'Cargando asistencia…'
        : error
        ? 'No se pudo cargar tu asistencia.'
        : resumen == null
        ? 'Todavía no hay sesiones registradas.'
        : 'Asistencia: ${resumen.porcentaje}% '
              '(${resumen.presentes} de ${resumen.total} sesiones)';
    return Text(texto, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _SinDeportes extends StatelessWidget {
  const _SinDeportes({
    required this.pendientes,
    this.onExplorar,
    this.onVerInscripciones,
  });

  final int pendientes;
  final VoidCallback? onExplorar;
  final VoidCallback? onVerInscripciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todavía no tienes deportes confirmados.',
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pendientes > 0
                  ? _textoPendientes(pendientes)
                  : 'Cuando pagues una inscripción, el deporte aparece aquí '
                        'con tu horario y tu asistencia.',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (pendientes > 0 && onVerInscripciones != null)
                  FilledButton(
                    onPressed: onVerInscripciones,
                    child: const Text('Ver inscripciones'),
                  ),
                if (onExplorar != null)
                  OutlinedButton(
                    onPressed: onExplorar,
                    child: const Text('Explorar deportes'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _textoPendientes(int pendientes) => pendientes == 1
    ? 'Tienes 1 inscripción pendiente de pago. Cuando se confirme, el '
          'deporte aparece aquí.'
    : 'Tienes $pendientes inscripciones pendientes de pago. Cuando se '
          'confirmen, los deportes aparecen aquí.';

class _AvisoPendientes extends StatelessWidget {
  const _AvisoPendientes({required this.pendientes, this.onVerInscripciones});

  final int pendientes;
  final VoidCallback? onVerInscripciones;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_outlined),
        title: Text(_textoPendientes(pendientes)),
        trailing: onVerInscripciones == null
            ? null
            : TextButton(
                onPressed: onVerInscripciones,
                child: const Text('Ver'),
              ),
      ),
    );
  }
}
