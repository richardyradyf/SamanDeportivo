import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/reservas/data/disponibilidad_repository.dart';
import 'package:saman_deportivo/features/reservas/data/reservas_repository.dart';
import 'package:saman_deportivo/features/reservas/domain/validaciones_reserva.dart';
import 'package:saman_deportivo/features/reservas/presentation/hora_caracas.dart';
import 'package:saman_deportivo/features/reservas/presentation/widgets_reservas.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';

/// Pantalla C: formulario para reservar un espacio.
///
/// Para estudiantes la interfaz limita la fecha a los próximos 21 días y la
/// duración a 2 horas; entrenadores y administradores no tienen esos
/// límites. Antes de enviar revisa la solicitud con
/// [ValidacionesReserva.validarSolicitud] para avisar del error en el
/// momento, pero quien decide es la transacción de [ReservasRepository].
///
/// Devuelve `true` al cerrarse si la reserva quedó guardada.
class CrearReservaScreen extends StatefulWidget {
  const CrearReservaScreen({
    super.key,
    required this.espacios,
    required this.deportes,
    required this.disponibilidad,
    required this.reservas,
    required this.rol,
    required this.reloj,
    this.espacioId,
    this.inicio,
    this.fin,
  });

  final List<EspacioDeportivo> espacios;
  final List<Deporte> deportes;
  final DisponibilidadRepository disponibilidad;
  final ReservasRepository reservas;
  final Rol rol;
  final DateTime Function() reloj;

  /// Valores iniciales, por ejemplo la franja elegida en Disponibilidad.
  final String? espacioId;
  final DateTime? inicio;
  final DateTime? fin;

  /// Horario en que se pueden reservar los espacios (hora de Caracas).
  static const int primeraHora = 6;
  static const int ultimaHora = 22;
  static const int pasoMinutos = 30;

  /// Horas de finalización que se ofrecen para un [inicio] (minutos desde
  /// la medianoche): cada media hora hasta las 22:00 y, para estudiantes,
  /// como máximo 2 horas después del inicio.
  static List<int> opcionesFin({required int? inicio, required Rol rol}) {
    if (inicio == null) return const [];
    final limite = rol == Rol.estudiante
        ? inicio + ValidacionesReserva.maximoEstudiante.inMinutes
        : ultimaHora * 60;
    return [
      for (
        var m = inicio + pasoMinutos;
        m <= ultimaHora * 60 && m <= limite;
        m += pasoMinutos
      )
        m,
    ];
  }

  @override
  State<CrearReservaScreen> createState() => _CrearReservaScreenState();
}

class _CrearReservaScreenState extends State<CrearReservaScreen> {
  final _formulario = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  String? _espacioId;
  late DateTime _dia;
  int? _inicio;
  int? _fin;
  bool _guardando = false;
  String? _error;

  bool get _esEstudiante => widget.rol == Rol.estudiante;

  @override
  void initState() {
    super.initState();
    final ids = widget.espacios.map((e) => e.id);
    _espacioId = ids.contains(widget.espacioId)
        ? widget.espacioId
        : (ids.isEmpty ? null : ids.first);

    final ahora = widget.reloj();
    final inicio = widget.inicio;
    _dia = HoraCaracas.diaDe(inicio ?? ahora);
    if (inicio != null) {
      final minutos = HoraCaracas.minutosDelDia(inicio);
      if (_opcionesInicio.contains(minutos)) _inicio = minutos;
      final fin = widget.fin;
      if (_inicio != null && fin != null) {
        final minutosFin = minutos + fin.difference(inicio).inMinutes;
        if (_opcionesFin.contains(minutosFin)) _fin = minutosFin;
      }
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  DateTime get _hoy => HoraCaracas.diaDe(widget.reloj());

  DateTime get _ultimoDia => _esEstudiante
      ? HoraCaracas.diaDe(
          widget.reloj().add(ValidacionesReserva.anticipacionEstudiante),
        )
      : _hoy.add(const Duration(days: 365));

  List<int> get _opcionesInicio => [
    for (
      var m = CrearReservaScreen.primeraHora * 60;
      m < CrearReservaScreen.ultimaHora * 60;
      m += CrearReservaScreen.pasoMinutos
    )
      m,
  ];

  List<int> get _opcionesFin =>
      CrearReservaScreen.opcionesFin(inicio: _inicio, rol: widget.rol);

  EspacioDeportivo? get _espacio {
    for (final espacio in widget.espacios) {
      if (espacio.id == _espacioId) return espacio;
    }
    return null;
  }

  Future<void> _elegirFecha() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: DateTime(_dia.year, _dia.month, _dia.day),
      firstDate: DateTime(_hoy.year, _hoy.month, _hoy.day),
      lastDate: DateTime(_ultimoDia.year, _ultimoDia.month, _ultimoDia.day),
      helpText: _esEstudiante
          ? 'Elige la fecha (próximos 21 días)'
          : 'Elige la fecha',
    );
    if (elegido == null) return;
    setState(() {
      _dia = DateTime.utc(elegido.year, elegido.month, elegido.day);
      _error = null;
    });
  }

  Future<void> _confirmar() async {
    setState(() => _error = null);
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final espacio = _espacio;
    final inicioMin = _inicio;
    final finMin = _fin;
    if (espacio == null || inicioMin == null || finMin == null) return;

    final inicio = HoraCaracas.instante(_dia, 0).add(Duration(minutes: inicioMin));
    final fin = HoraCaracas.instante(_dia, 0).add(Duration(minutes: finMin));
    final motivo = _motivo.text.trim();

    setState(() => _guardando = true);
    try {
      // Aviso inmediato con las mismas reglas que usa la transacción.
      final desde = HoraCaracas.instante(_dia, 0);
      final ocupaciones = await widget.disponibilidad
          .observarOcupaciones(
            espacioId: espacio.id,
            desde: desde,
            hasta: desde.add(const Duration(days: 1)),
          )
          .first
          .timeout(const Duration(seconds: 15));
      ValidacionesReserva.validarSolicitud(
        espacio: espacio,
        rol: widget.rol,
        inicio: inicio,
        fin: fin,
        ahora: widget.reloj(),
        motivo: motivo,
        deportes: widget.deportes,
        ocupaciones: ocupaciones,
      );

      await widget.reservas.crear(
        espacioId: espacio.id,
        inicio: inicio,
        fin: fin,
        motivo: motivo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReservaEspacioException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar la reserva. Revisa tu conexión e '
            'inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva reserva')),
      body: widget.espacios.isEmpty
          ? const AvisoReservas(
              icono: Icons.stadium_outlined,
              titulo: 'No hay espacios para reservar',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formulario,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Reserva un espacio',
                              style: tema.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            RecuadroAviso(
                              key: const Key('limitesReserva'),
                              texto: _esEstudiante
                                  ? 'Como estudiante puedes reservar hasta 2 '
                                        'horas seguidas y con un máximo de 21 '
                                        'días de anticipación.'
                                  : 'Como ${widget.rol.etiqueta.toLowerCase()} '
                                        'no tienes límite de duración ni de '
                                        'anticipación. El espacio no debe '
                                        'chocar con clases ni otras reservas.',
                            ),
                            const SizedBox(height: 20),
                            ..._campos(context),
                            if (_error != null) ...[
                              const SizedBox(height: 4),
                              RecuadroAviso(
                                key: const Key('errorReserva'),
                                texto: _error!,
                                error: true,
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              key: const Key('confirmarReserva'),
                              onPressed: _guardando ? null : _confirmar,
                              child: _guardando
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Confirmar reserva'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _campos(BuildContext context) {
    const separacion = SizedBox(height: 16);
    final opcionesFin = _opcionesFin;
    return [
      DropdownButtonFormField<String>(
        key: const Key('reservaEspacio'),
        initialValue: _espacioId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '1. Espacio'),
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
        onChanged: _guardando
            ? null
            : (id) => setState(() {
                _espacioId = id;
                _error = null;
              }),
        validator: (id) => id == null ? 'Elige un espacio' : null,
      ),
      separacion,
      InkWell(
        key: const Key('reservaFecha'),
        onTap: _guardando ? null : _elegirFecha,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: '2. Fecha',
            suffixIcon: Icon(Icons.calendar_month_outlined),
          ),
          child: Text(HoraCaracas.diaLargo(HoraCaracas.instante(_dia, 12))),
        ),
      ),
      separacion,
      // Las dos horas lado a lado en pantallas anchas; una debajo de la
      // otra en el celular, para que no se corten.
      LayoutBuilder(
        builder: (context, constraints) {
          final inicio = DropdownButtonFormField<int>(
            key: const Key('reservaInicio'),
            initialValue: _inicio,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '3. Hora de inicio'),
            items: [
              for (final m in _opcionesInicio)
                DropdownMenuItem(
                  value: m,
                  child: Text(HoraCaracas.desdeMinutos(m)),
                ),
            ],
            onChanged: _guardando
                ? null
                : (m) => setState(() {
                    _inicio = m;
                    _error = null;
                    if (_fin != null && !_opcionesFin.contains(_fin)) {
                      _fin = null;
                    }
                  }),
            validator: (m) => m == null ? 'Elige la hora de inicio' : null,
          );
          final fin = DropdownButtonFormField<int>(
            // La llave cambia con el inicio: así las opciones y el valor
            // elegido se reinician juntos.
            key: ValueKey('reservaFin-$_inicio'),
            initialValue: opcionesFin.contains(_fin) ? _fin : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '4. Hora de finalización',
              helperText: _esEstudiante ? 'Máximo 2 horas' : null,
            ),
            items: [
              for (final m in opcionesFin)
                DropdownMenuItem(
                  value: m,
                  child: Text(HoraCaracas.desdeMinutos(m)),
                ),
            ],
            onChanged: _guardando || _inicio == null
                ? null
                : (m) => setState(() {
                    _fin = m;
                    _error = null;
                  }),
            validator: (m) =>
                m == null ? 'Elige la hora de finalización' : null,
          );
          if (constraints.maxWidth < 420) {
            return Column(children: [inicio, separacion, fin]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: inicio),
              const SizedBox(width: 12),
              Expanded(child: fin),
            ],
          );
        },
      ),
      separacion,
      TextFormField(
        key: const Key('reservaMotivo'),
        controller: _motivo,
        enabled: !_guardando,
        maxLength: 200,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: '5. Motivo o descripción',
          hintText: 'Por ejemplo: práctica libre de tenis',
          alignLabelWithHint: true,
        ),
        validator: (texto) {
          final largo = texto?.trim().length ?? 0;
          if (largo < 3) return 'Escribe al menos 3 caracteres';
          if (largo > 200) return 'Máximo 200 caracteres';
          return null;
        },
      ),
    ];
  }
}
