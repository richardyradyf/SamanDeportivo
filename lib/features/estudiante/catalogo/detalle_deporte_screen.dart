import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/estrellas.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/etiqueta_cupos.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/formulario_resena.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/tarjeta_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/repositories/resena_repository.dart';

/// Detalle de un deporte del catálogo (RF-05, RF-17).
///
/// Muestra la descripción, el entrenador, los horarios, los cupos y las
/// reseñas. El deporte se escucha en tiempo real: si alguien se inscribe
/// mientras la pantalla está abierta, los cupos se actualizan solos.
class DetalleDeporteScreen extends StatefulWidget {
  const DetalleDeporteScreen({
    super.key,
    required this.deporte,
    this.deportes,
    this.resenas,
    this.estudianteUid,
    this.estudianteNombre,
    this.puedeResenar = false,
    this.onInscribirse,
  });

  /// El deporte elegido en el catálogo. Se muestra mientras llega la
  /// versión en tiempo real.
  final Deporte deporte;
  final DeporteRepository? deportes;

  /// Reseñas del deporte. Si es null, la sección dice que no están
  /// disponibles.
  final ResenaRepository? resenas;
  final String? estudianteUid;
  final String? estudianteNombre;

  /// True si el estudiante tiene una inscripción confirmada en este
  /// deporte: solo entonces puede calificar (RF-17).
  final bool puedeResenar;

  /// Inscripción (módulo de Mariana). Si es null, el botón queda inactivo.
  final void Function(Deporte deporte)? onInscribirse;

  static const double anchoDosColumnas = 840;

  @override
  State<DetalleDeporteScreen> createState() => _DetalleDeporteScreenState();
}

class _DetalleDeporteScreenState extends State<DetalleDeporteScreen> {
  Stream<Deporte?>? _deporte;
  Stream<List<Resena>>? _resenas;

  @override
  void initState() {
    super.initState();
    final codigo = widget.deporte.codigo;
    final deportes =
        widget.deportes ??
        (Firebase.apps.isNotEmpty ? FirestoreDeporteRepository() : null);
    _deporte = deportes?.observar(codigo);
    _resenas = widget.resenas?.observar(codigo);
  }

  Future<void> _guardarResena(int puntuacion, String comentario) {
    return widget.resenas!.guardar(
      widget.deporte.codigo,
      Resena(
        estudianteUid: widget.estudianteUid!,
        estudianteNombre: widget.estudianteNombre ?? '',
        puntuacion: puntuacion,
        comentario: comentario,
        fecha: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Deporte?>(
      stream: _deporte,
      initialData: widget.deporte,
      builder: (context, snapshot) {
        final deporte = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(deporte?.nombre ?? 'Deporte')),
          body: deporte == null || !deporte.activo
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Este deporte ya no está disponible.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => _contenido(
                    context,
                    deporte,
                    ancho:
                        constraints.maxWidth >=
                        DetalleDeporteScreen.anchoDosColumnas,
                  ),
                ),
        );
      },
    );
  }

  Widget _contenido(BuildContext context, Deporte deporte, {required bool ancho}) {
    final encabezado = _Encabezado(deporte: deporte, grande: ancho);
    final portada = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radioTarjeta),
      child: SizedBox(
        height: ancho ? 240 : 160,
        child: _Portada(deporte: deporte),
      ),
    );
    final datos = _TarjetaDatos(deporte: deporte);
    final inscripcion = _TarjetaInscripcion(
      deporte: deporte,
      onInscribirse: widget.onInscribirse,
    );
    final espacio = SizedBox(height: ancho ? 32 : 20, width: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(ancho ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ancho)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: encabezado),
                    espacio,
                    Expanded(child: portada),
                  ],
                )
              else ...[
                portada,
                espacio,
                encabezado,
              ],
              espacio,
              if (ancho)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: datos),
                      espacio,
                      Expanded(flex: 2, child: inscripcion),
                    ],
                  ),
                )
              else ...[
                datos,
                espacio,
                inscripcion,
              ],
              espacio,
              _SeccionResenas(
                resenas: _resenas,
                estudianteUid: widget.estudianteUid,
                puedeResenar:
                    widget.puedeResenar &&
                    widget.resenas != null &&
                    widget.estudianteUid != null,
                onGuardar: _guardarResena,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.deporte, required this.grande});

  final Deporte deporte;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${deporte.codigo} · ${etiquetaCortaDisciplina(deporte.disciplina)}'
              .toUpperCase(),
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          deporte.nombre,
          style: grande
              ? tema.textTheme.headlineLarge
              : tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtiquetaCupos(deporte: deporte),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deporte.totalResenas > 0) ...[
                  Estrellas(valor: deporte.promedioCalificacion),
                  const SizedBox(width: 6),
                ],
                Text(
                  textoCalificacion(deporte),
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        if (deporte.descripcion.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(deporte.descripcion, style: tema.textTheme.bodyLarge),
        ],
      ],
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final respaldo = ColoredBox(
      color: colores.secondary,
      child: Center(
        child: Icon(
          TarjetaDeporte.iconoDe(deporte.disciplina),
          size: 64,
          color: colores.onSecondary,
        ),
      ),
    );
    final url = deporte.imagenUrl;
    if (url == null || url.isEmpty) return respaldo;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => respaldo,
    );
  }
}

/// Entrenador, horarios, lugar y costo.
class _TarjetaDatos extends StatelessWidget {
  const _TarjetaDatos({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final especialidad = deporte.entrenadorEspecialidad;
    final horarios = [...deporte.horarios]
      ..sort((a, b) {
        final porDia = a.dia.index.compareTo(b.dia.index);
        return porDia != 0 ? porDia : a.inicioEnMinutos - b.inicioEnMinutos;
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Campo(
              titulo: 'Entrenador',
              child: Text(
                deporte.entrenadorNombre ?? 'Por asignar',
                style: tema.textTheme.titleMedium,
              ),
            ),
            if (especialidad != null && especialidad.trim().isNotEmpty)
              Text(especialidad, style: tema.textTheme.bodySmall),
            const SizedBox(height: 16),
            _Campo(
              titulo: 'Horario',
              child: horarios.isEmpty
                  ? Text('Por definir', style: tema.textTheme.bodyLarge)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final h in horarios)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${h.dia.etiqueta} · ${h.horaInicio} - '
                              '${h.horaFin}'
                              '${h.lugar.trim().isEmpty ? '' : ' · ${h.lugar}'}',
                              style: tema.textTheme.bodyLarge,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            _Campo(
              titulo: 'Costo de la reserva',
              child: Text(
                '\$${deporte.costo.toStringAsFixed(2)}',
                style: tema.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// Cupos ocupados con su barra y el botón de inscripción.
class _TarjetaInscripcion extends StatelessWidget {
  const _TarjetaInscripcion({required this.deporte, this.onInscribirse});

  final Deporte deporte;
  final void Function(Deporte deporte)? onInscribirse;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final maximo = deporte.cupoMaximo;
    final ocupados = deporte.cuposOcupados.clamp(0, maximo);
    final inscribirse = onInscribirse;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inscripción', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '$ocupados de $maximo cupos ocupados',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: maximo == 0 ? 1 : ocupados / maximo,
                minHeight: 8,
                backgroundColor: tema.colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaCupos(deporte: deporte),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: deporte.tieneCupo && inscribirse != null
                  ? () => inscribirse(deporte)
                  : null,
              child: Text(deporte.tieneCupo ? 'Inscribirme' : 'Sin cupos'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calificaciones y comentarios del deporte (RF-17).
class _SeccionResenas extends StatelessWidget {
  const _SeccionResenas({
    required this.resenas,
    required this.estudianteUid,
    required this.puedeResenar,
    required this.onGuardar,
  });

  final Stream<List<Resena>>? resenas;
  final String? estudianteUid;
  final bool puedeResenar;
  final Future<void> Function(int puntuacion, String comentario) onGuardar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final titulo = Text(
      'Calificaciones y comentarios',
      style: tema.textTheme.headlineSmall,
    );
    final stream = resenas;

    if (stream == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titulo,
          const SizedBox(height: 8),
          Text(
            'Las reseñas no están disponibles por ahora.',
            style: tema.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return StreamBuilder<List<Resena>>(
      stream: stream,
      builder: (context, snapshot) {
        // Por si acaso: el repositorio ya no entrega las ocultas.
        final lista = (snapshot.data ?? const <Resena>[])
            .where((r) => !r.oculta)
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
        Resena? propia;
        for (final r in lista) {
          if (r.estudianteUid == estudianteUid) propia = r;
        }

        final Widget cuerpo;
        if (snapshot.hasError) {
          cuerpo = Text(
            'No pudimos cargar las reseñas.',
            style: tema.textTheme.bodyMedium,
          );
        } else if (!snapshot.hasData) {
          cuerpo = const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (lista.isEmpty) {
          cuerpo = Text(
            'Todavía nadie ha calificado este deporte.',
            style: tema.textTheme.bodyMedium,
          );
        } else {
          cuerpo = Column(
            children: [
              for (final resena in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TarjetaResena(
                    resena: resena,
                    esPropia: resena.estudianteUid == estudianteUid,
                  ),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titulo,
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: puedeResenar
                    ? FormularioResena(inicial: propia, onGuardar: onGuardar)
                    : Text(
                        'Solo los estudiantes con inscripción confirmada '
                        'pueden calificar este deporte.',
                        style: tema.textTheme.bodyMedium,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            cuerpo,
          ],
        );
      },
    );
  }
}

class _TarjetaResena extends StatelessWidget {
  const _TarjetaResena({required this.resena, required this.esPropia});

  final Resena resena;
  final bool esPropia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = resena.estudianteNombre.trim().isEmpty
        ? 'Estudiante'
        : resena.estudianteNombre;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    esPropia ? '$nombre (tú)' : nombre,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
                Text(fechaCorta(resena.fecha), style: tema.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Estrellas(valor: resena.puntuacion.toDouble()),
            if (resena.comentario.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(resena.comentario, style: tema.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
