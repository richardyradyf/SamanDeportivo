import 'enums.dart';

/// Una sesión semanal de un deporte: día, hora y lugar (RF-16).
/// Se guarda como un mapa dentro de la lista `horarios` del deporte.
class HorarioSesion {
  final DiaSemana dia;

  /// Formato 24 h: "16:00".
  final String horaInicio;
  final String horaFin;
  final String lugar;

  const HorarioSesion({
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.lugar,
  });

  /// Minutos desde las 00:00, para comparar horas.
  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  int get inicioEnMinutos => _minutos(horaInicio);
  int get finEnMinutos => _minutos(horaFin);

  bool get esValido => finEnMinutos > inicioEnMinutos;

  /// True si las dos sesiones caen el mismo día y sus horas se cruzan.
  /// Sirve para validar que un entrenador no tenga horarios solapados (RF-16).
  bool seCruzaCon(HorarioSesion otro) {
    return dia == otro.dia &&
        inicioEnMinutos < otro.finEnMinutos &&
        otro.inicioEnMinutos < finEnMinutos;
  }

  /// Texto para mostrar: "Lun · 16:00 - 18:00".
  String get resumen => '${dia.abreviatura} · $horaInicio - $horaFin';

  Map<String, dynamic> toMap() {
    return {
      'dia': dia.name,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'lugar': lugar,
    };
  }

  factory HorarioSesion.fromMap(Map<String, dynamic> datos) {
    return HorarioSesion(
      dia: DiaSemana.desdeTexto(datos['dia'] as String?),
      horaInicio: datos['horaInicio'] as String? ?? '00:00',
      horaFin: datos['horaFin'] as String? ?? '00:00',
      lugar: datos['lugar'] as String? ?? '',
    );
  }
}
