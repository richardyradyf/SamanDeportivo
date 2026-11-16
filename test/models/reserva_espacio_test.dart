import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/reserva_espacio.dart';

void main() {
  test('reserva privada conserva todos los campos en Firestore', () {
    final creado = DateTime.utc(2026, 11, 15);
    final original = ReservaEspacio(
      id: 'reserva-1',
      espacioId: 'cancha-tenis-1',
      usuarioUid: 'estudiante-1',
      rol: Rol.estudiante,
      inicio: DateTime.utc(2026, 11, 16, 15),
      fin: DateTime.utc(2026, 11, 16, 17),
      motivo: 'Práctica individual',
      creadoEn: creado,
    );
    final mapa = original.toMap();
    expect(mapa['inicio'], isA<Timestamp>());
    final restaurada = ReservaEspacio.fromMap(original.id, mapa);
    expect(restaurada.usuarioUid, 'estudiante-1');
    expect(restaurada.rol, Rol.estudiante);
    expect(restaurada.inicio.isAtSameMomentAs(original.inicio), isTrue);
    expect(restaurada.estado, EstadoReservaEspacio.activa);

    final cancelada = restaurada.cancelar(creado.add(const Duration(days: 1)));
    expect(cancelada.estaActiva, isFalse);
    expect(cancelada.id, original.id);
  });

  test('proyección de disponibilidad nunca contiene datos personales', () {
    final publica = OcupacionEspacio(
      id: 'reserva-1',
      espacioId: 'cancha-tenis-1',
      inicio: DateTime.utc(2026, 11, 16, 15),
      fin: DateTime.utc(2026, 11, 16, 17),
    );
    final mapa = publica.toMap();
    expect(mapa.keys.toSet(), {'espacioId', 'inicio', 'fin'});
    expect(mapa.containsKey('usuarioUid'), isFalse);
    expect(mapa.containsKey('motivo'), isFalse);
    expect(
      OcupacionEspacio.fromMap(
        publica.id,
        mapa,
      ).fin.isAtSameMomentAs(publica.fin),
      isTrue,
    );
  });
}
