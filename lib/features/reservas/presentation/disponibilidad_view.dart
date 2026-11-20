import 'package:flutter/material.dart';

import 'package:saman_deportivo/core/theme/app_colors.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/franjas_disponibilidad.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

/// Pantalla B: franjas de una hora de un espacio en un día, filtrables por
/// espacio, fecha y parte del día.
class DisponibilidadView extends StatefulWidget {
  const DisponibilidadView({
    super.key,
    required this.espacios,
    required this.deportes,
    required this.disponibilidad,
    required this.rol,
    required this.reloj,
    required this.onReservar,
    this.espacioId,
    this.onCambiarEspacio,
  });

  final List<EspacioDeportivo> espacios;
  final List<Deporte> deportes;
  final DisponibilidadRepository disponibilidad;
  final Rol rol;
  final DateTime Function() reloj;

  /// Abre el formulario con el espacio y la franja elegidos.
  final void Function(EspacioDeportivo espacio, DateTime inicio, DateTime fin)
  onReservar;

  /// Espacio elegido; si es null se usa el primero.
  final String? espacioId;
  final ValueChanged<String>? onCambiarEspacio;

  /// Días que se ofrecen como chips (el estudiante, además, no puede pasar
  /// de [ValidacionesReserva.anticipacionEstudiante]).
  static const int diasVisibles = 14;

  @override
  State<DisponibilidadView> createState() => _DisponibilidadViewState();
}

class _DisponibilidadViewState extends State<DisponibilidadView> {
  late DateTime _dia;
  ParteDelDia _parte = ParteDelDia.todo;
  String? _espacioId;
  Stream<List<OcupacionEspacio>>? _ocupaciones;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _dia = HoraCaracas.diaDe(widget.reloj());
    _espacioId = _elegirEspacio(widget.espacioId);
    _consultar();
  }

  @override
  void didUpdateWidget(DisponibilidadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final elegido = _elegirEspacio(widget.espacioId ?? _espacioId);
    if (elegido != _espacioId) {
      _espacioId = elegido;
      _consultar();
    }
  }

  String? _elegirEspacio(String? id) {
    if (widget.espacios.isEmpty) return null;
    return widget.espacios.any((e) => e.id == id)
        ? id
        : widget.espacios.first.id;
  }

  EspacioDeportivo? get _espacio {
    for (final espacio in widget.espacios) {
      if (espacio.id == _espacioId) return espacio;
    }
    return null;
  }

  /// Último día que puede elegir el estudiante.
  DateTime? get _ultimoDia => widget.rol == Rol.estudiante
      ? HoraCaracas.diaDe(
          widget.reloj().add(ValidacionesReserva.anticipacionEstudiante),
        )
      : null;

  void _consultar() {
    final id = _espacioId;
    if (id == null) {
      _ocupaciones = null;
      return;
    }
    _desde = HoraCaracas.instante(_dia, 0);
    _hasta = _desde!.add(const Duration(days: 1));
    try {
      _ocupaciones = widget.disponibilidad.observarOcupaciones(
        espacioId: id,
        desde: _desde!,
        hasta: _hasta!,
      );
    } catch (_) {
      _ocupaciones = Stream.error('consulta');
    }
  }

  void _cambiarDia(DateTime dia) {
    setState(() {
      _dia = dia;
      _consultar();
    });
  }

  void _cambiarEspacio(String? id) {
    if (id == null || id == _espacioId) return;
    setState(() {
      _espacioId = id;
      _consultar();
    });
    widget.onCambiarEspacio?.call(id);
  }

  Future<void> _elegirOtraFecha() async {
    final hoy = HoraCaracas.diaDe(widget.reloj());
    final ultimo = _ultimoDia ?? hoy.add(const Duration(days: 365));
    final elegido = await showDatePicker(
      context: context,
      initialDate: DateTime(_dia.year, _dia.month, _dia.day),
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(ultimo.year, ultimo.month, ultimo.day),
      helpText: 'Elige la fecha',
    );
    if (elegido == null) return;
    _cambiarDia(DateTime.utc(elegido.year, elegido.month, elegido.day));
  }

  @override
  Widget build(BuildContext context) {
    final espacio = _espacio;
    if (espacio == null) {
      return const AvisoReservas(
        icono: Icons.stadium_outlined,
        titulo: 'Todavía no hay espacios disponibles',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filtros(context),
              const SizedBox(height: 16),
              const _Leyenda(),
              const SizedBox(height: 12),
              _franjas(context, espacio),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtros(BuildContext context) {
    final tema = Theme.of(context);
    final hoy = HoraCaracas.diaDe(widget.reloj());
    final ultimo = _ultimoDia;
    final dias = <DateTime>[
      for (var i = 0; i < DisponibilidadView.diasVisibles; i++)
        hoy.add(Duration(days: i)),
    ].where((d) => ultimo == null || !d.isAfter(ultimo)).toList();
    final diaFueraDeLosChips = !dias.contains(_dia);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              // La llave cambia con el espacio para que el menú muestre el
              // elegido también cuando llega desde la tarjeta de Espacios.
              key: ValueKey('disponibilidadEspacio-$_espacioId'),
              initialValue: _espacioId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Espacio'),
              items: [
                for (final e in widget.espacios)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.nombre} · ${e.tipo}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _cambiarEspacio,
            ),
            const SizedBox(height: 16),
            Text('FECHA', style: tema.textTheme.labelSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final dia in dias)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        etiqueta: dia == hoy
                            ? 'Hoy'
                            : HoraCaracas.diaCorto(dia),
                        elegido: dia == _dia,
                        alPulsar: () => _cambiarDia(dia),
                      ),
                    ),
                  if (diaFueraDeLosChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        etiqueta: HoraCaracas.diaCorto(_dia),
                        elegido: true,
                        alPulsar: () {},
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Otra fecha'),
                    onPressed: _elegirOtraFecha,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('FRANJA HORARIA', style: tema.textTheme.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final parte in ParteDelDia.values)
                  _Chip(
                    etiqueta: parte.etiqueta,
                    elegido: parte == _parte,
                    alPulsar: () => setState(() => _parte = parte),
                  ),
              ],
            ),
            if (widget.rol == Rol.estudiante) ...[
              const SizedBox(height: 16),
              const RecuadroAviso(
                texto:
                    'Como estudiante puedes reservar con un máximo de 21 '
                    'días de anticipación y hasta 2 horas seguidas.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _franjas(BuildContext context, EspacioDeportivo espacio) {
    final tema = Theme.of(context);
    return StreamBuilder<List<OcupacionEspacio>>(
      stream: _ocupaciones,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AvisoReservas(
            icono: Icons.error_outline,
            titulo: 'No pudimos consultar la disponibilidad',
            mensaje: 'Revisa tu conexión e inténtalo de nuevo.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final bloques = ValidacionesReserva.consultarOcupaciones(
          espacio: espacio,
          desde: _desde!,
          hasta: _hasta!,
          deportes: widget.deportes,
          ocupaciones: snapshot.data!,
        );
        final franjas = franjasDelDia(
          dia: _dia,
          bloques: bloques,
          ahora: widget.reloj(),
          parte: _parte,
        );
        final libres = franjas.where((f) => f.sePuedeReservar).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${espacio.nombre} · ${HoraCaracas.diaLargo(_desde!)}',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              libres == 1 ? '1 hora libre' : '$libres horas libres',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final franja in franjas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FilaFranja(
                  franja: franja,
                  onReservar: () =>
                      widget.onReservar(espacio, franja.inicio, franja.fin),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilaFranja extends StatelessWidget {
  const _FilaFranja({required this.franja, required this.onReservar});

  final FranjaHoraria franja;
  final VoidCallback onReservar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final descripcion = franja.descripcion;
    final horario = Text(
      HoraCaracas.rango(franja.inicio, franja.fin),
      maxLines: 1,
      softWrap: false,
      style: tema.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: franja.estado == EstadoFranja.pasada
            ? AppColors.textoSecundario
            : AppColors.texto,
      ),
    );
    final detalles = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        EtiquetaReserva.franja(franja.estado),
        if (descripcion != null)
          Text(descripcion, style: tema.textTheme.bodySmall),
      ],
    );
    final boton = franja.sePuedeReservar
        ? TextButton(onPressed: onReservar, child: const Text('Reservar'))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(AppTheme.radioControl),
        border: Border.all(color: AppColors.borde),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En móvil se separa el rango horario de las acciones para
          // evitar que "08:00 - 09:00" se parta en dos líneas.
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                horario,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EtiquetaReserva.franja(franja.estado),
                    if (descripcion != null)
                      Text(descripcion, style: tema.textTheme.bodySmall),
                    ?boton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 150, child: horario),
              Expanded(child: detalles),
              ?boton,
            ],
          );
        },
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        EtiquetaReserva.franja(EstadoFranja.disponible),
        EtiquetaReserva.franja(EstadoFranja.clase),
        EtiquetaReserva.franja(EstadoFranja.reserva),
      ],
    );
  }
}

/// Chip de selección sin check, con el mismo estilo que los filtros del
/// catálogo.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.elegido,
    required this.alPulsar,
  });

  final String etiqueta;
  final bool elegido;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: elegido,
      showCheckmark: false,
      onSelected: (_) => alPulsar(),
    );
  }
}
