import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/espacio_deportivo.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/enums.dart';

void main() {
  test('espacio conserva ID y fecha al editar el nombre', () {
    final creado = DateTime(2026, 11, 15);
    final original = EspacioDeportivo(
      id: 'instalacion-1',
      nombre: 'Cancha 1',
      tipo: 'Tenis',
      creadoEn: creado,
    );
    final editado = original.copyWith(nombre: 'Cancha de tenis 1');
    expect(editado.id, 'instalacion-1');
    expect(editado.creadoEn, creado);
    expect(editado.nombre, 'Cancha de tenis 1');
    expect(editado.toMap()['creadoEn'], isA<Timestamp>());
  });

  test('horario lee datos históricos sin espacioId', () {
    final horario = HorarioSesion.fromMap({
      'dia': 'lunes', 'horaInicio': '16:00',
      'horaFin': '18:00', 'lugar': 'Cancha A',
    });
    expect(horario.espacioId, isNull);
    expect(horario.lugar, 'Cancha A');
  });

  test('horario guarda referencia estable al espacio', () {
    const horario = HorarioSesion(
      dia: DiaSemana.lunes,
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha de tenis 1',
      espacioId: 'instalacion-1',
    );
    expect(horario.toMap()['espacioId'], 'instalacion-1');
    expect(HorarioSesion.fromMap(horario.toMap()).espacioId, 'instalacion-1');
  });
}
