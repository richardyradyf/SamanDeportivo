import 'package:saman_deportivo/core/utils/busqueda_normalizada.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Franja del día en que empieza una sesión, para filtrar por horario.
enum Turno {
  manana('Mañana'),
  tarde('Tarde'),
  noche('Noche');

  const Turno(this.etiqueta);

  final String etiqueta;

  /// Mañana: antes de las 12:00. Tarde: de 12:00 a 17:59. Noche: desde 18:00.
  static Turno deMinutos(int minutos) {
    if (minutos < 12 * 60) return Turno.manana;
    if (minutos < 18 * 60) return Turno.tarde;
    return Turno.noche;
  }
}

/// Búsqueda y filtros del catálogo de deportes (RF-06).
///
/// Es inmutable: cada cambio en la pantalla crea un filtro nuevo con
/// [copyWith]. La lógica no depende de Firebase, así que se prueba sola.
class FiltroCatalogo {
  const FiltroCatalogo({
    this.texto = '',
    this.disciplina,
    this.dia,
    this.turno,
    this.especialidad,
    this.soloConCupo = false,
  });

  /// Texto escrito en el buscador. Se compara con el nombre y el código.
  final String texto;
  final Disciplina? disciplina;
  final DiaSemana? dia;
  final Turno? turno;

  /// Especialidad del entrenador asignado (ej. "Fútbol").
  final String? especialidad;
  final bool soloConCupo;

  bool get estaVacio =>
      texto.trim().isEmpty &&
      disciplina == null &&
      dia == null &&
      turno == null &&
      especialidad == null &&
      !soloConCupo;

  /// Cantidad de filtros activos, sin contar el texto (para el botón "Filtros").
  int get cantidadFiltros => [
        disciplina != null,
        dia != null,
        turno != null,
        especialidad != null,
        soloConCupo,
      ].where((activo) => activo).length;

  /// True si el deporte cumple el texto y todos los filtros activos.
  bool cumple(Deporte deporte) {
    final consulta = normalizarBusqueda(texto);
    if (consulta.isNotEmpty &&
        !normalizarBusqueda(deporte.nombre).contains(consulta) &&
        !normalizarBusqueda(deporte.codigo).contains(consulta)) {
      return false;
    }
    if (disciplina != null && deporte.disciplina != disciplina) return false;
    if (soloConCupo && !deporte.tieneCupo) return false;
    if (especialidad != null &&
        normalizarBusqueda(deporte.entrenadorEspecialidad ?? '') !=
            normalizarBusqueda(especialidad!)) {
      return false;
    }
    if (dia != null || turno != null) {
      // Día y turno se exigen en la MISMA sesión: "lunes en la tarde"
      // no acepta un deporte que solo va los lunes en la mañana.
      final hayHorario = deporte.horarios.any(
        (h) =>
            (dia == null || h.dia == dia) &&
            (turno == null || Turno.deMinutos(h.inicioEnMinutos) == turno),
      );
      if (!hayHorario) return false;
    }
    return true;
  }

  /// Deportes que cumplen el filtro, ordenados por nombre.
  List<Deporte> aplicar(List<Deporte> deportes) {
    final resultado = deportes.where(cumple).toList()
      ..sort((a, b) =>
          normalizarBusqueda(a.nombre).compareTo(normalizarBusqueda(b.nombre)));
    return resultado;
  }

  /// Filtros en el formato que guarda `Busqueda.filtros` (RF-18).
  Map<String, dynamic> aMapa() {
    return {
      if (disciplina != null) 'disciplina': disciplina!.name,
      if (dia != null) 'dia': dia!.name,
      if (turno != null) 'turno': turno!.name,
      if (especialidad != null) 'especialidad': especialidad,
      if (soloConCupo) 'soloConCupo': true,
    };
  }

  /// Copia cambiando solo lo indicado. Para quitar un filtro usar
  /// [sinDisciplina], [sinDia], [sinTurno] o [sinEspecialidad].
  FiltroCatalogo copyWith({
    String? texto,
    Disciplina? disciplina,
    DiaSemana? dia,
    Turno? turno,
    String? especialidad,
    bool? soloConCupo,
    bool sinDisciplina = false,
    bool sinDia = false,
    bool sinTurno = false,
    bool sinEspecialidad = false,
  }) {
    return FiltroCatalogo(
      texto: texto ?? this.texto,
      disciplina: sinDisciplina ? null : (disciplina ?? this.disciplina),
      dia: sinDia ? null : (dia ?? this.dia),
      turno: sinTurno ? null : (turno ?? this.turno),
      especialidad:
          sinEspecialidad ? null : (especialidad ?? this.especialidad),
      soloConCupo: soloConCupo ?? this.soloConCupo,
    );
  }

  /// Deja solo el texto y quita los filtros.
  FiltroCatalogo limpiarFiltros() => FiltroCatalogo(texto: texto);

  /// Especialidades de los entrenadores del catálogo, sin repetir y en
  /// orden alfabético, para llenar el selector.
  static List<String> especialidadesDe(List<Deporte> deportes) {
    final especialidades = <String>{
      for (final deporte in deportes)
        if ((deporte.entrenadorEspecialidad ?? '').trim().isNotEmpty)
          deporte.entrenadorEspecialidad!.trim(),
    }.toList()
      ..sort((a, b) =>
          normalizarBusqueda(a).compareTo(normalizarBusqueda(b)));
    return especialidades;
  }
}
