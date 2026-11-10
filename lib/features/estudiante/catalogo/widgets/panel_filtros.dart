import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/estudiante/catalogo/filtro_catalogo.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/formato_catalogo.dart';
import 'package:saman_deportivo/models/enums.dart';

/// Filtros del catálogo (RF-06): cupos, disciplina, día, turno y
/// especialidad del entrenador.
///
/// No guarda estado: recibe el filtro actual y avisa cada cambio con
/// [onCambio]. Así el mismo panel sirve en el lateral de escritorio y en
/// la hoja inferior del celular.
class PanelFiltros extends StatelessWidget {
  const PanelFiltros({
    super.key,
    required this.filtro,
    required this.especialidades,
    required this.onCambio,
  });

  final FiltroCatalogo filtro;

  /// Especialidades que aparecen en el catálogo.
  final List<String> especialidades;
  final ValueChanged<FiltroCatalogo> onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('Filtros', style: tema.textTheme.titleMedium)),
            if (filtro.cantidadFiltros > 0)
              TextButton(
                onPressed: () => onCambio(filtro.limpiarFiltros()),
                child: const Text('Limpiar'),
              ),
          ],
        ),
        CheckboxListTile(
          value: filtro.soloConCupo,
          onChanged: (valor) =>
              onCambio(filtro.copyWith(soloConCupo: valor ?? false)),
          title: const Text('Solo con cupos'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        _Grupo(
          titulo: 'Disciplina',
          opciones: [
            for (final disciplina in Disciplina.values)
              _Opcion(
                etiqueta: etiquetaCortaDisciplina(disciplina),
                elegida: filtro.disciplina == disciplina,
                alPulsar: () => onCambio(
                  filtro.disciplina == disciplina
                      ? filtro.copyWith(sinDisciplina: true)
                      : filtro.copyWith(disciplina: disciplina),
                ),
              ),
          ],
        ),
        _Grupo(
          titulo: 'Día',
          opciones: [
            for (final dia in DiaSemana.values)
              _Opcion(
                etiqueta: dia.abreviatura,
                elegida: filtro.dia == dia,
                alPulsar: () => onCambio(
                  filtro.dia == dia
                      ? filtro.copyWith(sinDia: true)
                      : filtro.copyWith(dia: dia),
                ),
              ),
          ],
        ),
        _Grupo(
          titulo: 'Turno',
          opciones: [
            for (final turno in Turno.values)
              _Opcion(
                etiqueta: turno.etiqueta,
                elegida: filtro.turno == turno,
                alPulsar: () => onCambio(
                  filtro.turno == turno
                      ? filtro.copyWith(sinTurno: true)
                      : filtro.copyWith(turno: turno),
                ),
              ),
          ],
        ),
        if (especialidades.isNotEmpty)
          _Grupo(
            titulo: 'Especialidad del entrenador',
            opciones: [
              for (final especialidad in especialidades)
                _Opcion(
                  etiqueta: especialidad,
                  elegida: filtro.especialidad == especialidad,
                  alPulsar: () => onCambio(
                    filtro.especialidad == especialidad
                        ? filtro.copyWith(sinEspecialidad: true)
                        : filtro.copyWith(especialidad: especialidad),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Opcion {
  const _Opcion({
    required this.etiqueta,
    required this.elegida,
    required this.alPulsar,
  });

  final String etiqueta;
  final bool elegida;
  final VoidCallback alPulsar;
}

/// Un grupo de chips con su título. Pulsar el chip elegido lo quita.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.opciones});

  final String titulo;
  final List<_Opcion> opciones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in opciones)
                ChoiceChip(
                  label: Text(opcion.etiqueta),
                  selected: opcion.elegida,
                  onSelected: (_) => opcion.alPulsar(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
