import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/datos_prueba/datos_de_prueba.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_dashboard.dart';
import 'package:saman_deportivo/models/enums.dart';

void main() {
  final usuarios = [
    const UsuarioDashboard(rol: 'administrador'),
    const UsuarioDashboard(rol: 'entrenador'),
    const UsuarioDashboard(rol: 'entrenador'),
    const UsuarioDashboard(rol: 'estudiante', estado: 'activo'),
    const UsuarioDashboard(rol: 'estudiante', estado: 'activo'),
    const UsuarioDashboard(rol: 'estudiante', estado: 'inactivo'),
  ];

  test('contabiliza catálogo, estudiantes, entrenadores y cupos', () {
    final resumen = ResumenDashboard.calcular(
      deportes: deportesDePrueba(),
      usuarios: usuarios,
    );
    expect(resumen.deportesTotales, 5);
    expect(resumen.deportesActivos, 5);
    expect(resumen.estudiantes, 3);
    expect(resumen.estudiantesActivos, 2);
    expect(resumen.entrenadores, 2);
    expect(resumen.cuposTotales, 59);
    expect(resumen.cuposDisponibles, 59);
    expect(resumen.cuposOcupados, 0);
    expect(resumen.cuposConfirmados, 0);
    expect(resumen.porcentajeOcupacion, 0);
    expect(resumen.porDisciplina[Disciplina.colectivo], 2);
  });

  test('separa cupos ocupados de confirmados y calcula 50%', () {
    final base = deportesDePrueba();
    final deportes = [
      base.first.copyWith(cuposOcupados: 10, cuposConfirmados: 6),
      base[1].copyWith(activo: false),
    ];
    final resumen = ResumenDashboard.calcular(
      deportes: deportes,
      usuarios: usuarios,
    );
    expect(resumen.deportesTotales, 2);
    expect(resumen.deportesActivos, 1);
    expect(resumen.cuposTotales, 20);
    expect(resumen.cuposOcupados, 10);
    expect(resumen.cuposConfirmados, 6);
    expect(resumen.cuposDisponibles, 10);
    expect(resumen.porcentajeOcupacion, 50);
    expect(resumen.porDisciplina[Disciplina.colectivo], 1);
  });

  test('excluye deportes inactivos, detecta completos y sin entrenador', () {
    final base = deportesDePrueba();
    final deportes = [
      base[0].copyWith(cuposOcupados: 20, cuposConfirmados: 20),
      base[1].copyWith(activo: false),
    ];
    final resumen = ResumenDashboard.calcular(
      deportes: deportes,
      usuarios: const [],
    );
    expect(resumen.deportesCompletos, 1);
    expect(resumen.deportesSinEntrenador, 1);
    expect(resumen.cuposTotales, 20);
    expect(resumen.cuposOcupados, 20);
    expect(resumen.cuposDisponibles, 0);
    expect(resumen.porcentajeOcupacion, 100);
  });

  test('sin datos no divide entre cero ni inventa actividad', () {
    final resumen = ResumenDashboard.calcular(
      deportes: const [],
      usuarios: const [],
    );
    expect(resumen.deportesActivos, 0);
    expect(resumen.cuposDisponibles, 0);
    expect(resumen.porcentajeOcupacion, 0);
    expect(resumen.ocupacionDeportes, isEmpty);
  });

  test('ordena por porcentaje de ocupación, no por volumen', () {
    final base = deportesDePrueba();
    final resumen = ResumenDashboard.calcular(
      deportes: [
        base.first.copyWith(cuposOcupados: 5), // 25%
        base[2].copyWith(cuposOcupados: 2), // 100%
      ],
      usuarios: const [],
    );
    expect(resumen.ocupacionDeportes.first.codigo, 'TEN-01');
    expect(resumen.ocupacionDeportes.first.porcentaje, 100);
  });

  test('lee usuarios con campos mínimos sin exigir uid embebido', () {
    final usuario = UsuarioDashboard.fromMap({
      'rol': 'estudiante',
      'estado': 'activo',
      'correo': 'test@example.com',
    });
    expect(usuario.rol, 'estudiante');
    expect(usuario.estado, 'activo');
  });
  test('estado ausente sigue convención del modelo Estudiante', () {
    final resumen = ResumenDashboard.calcular(
      deportes: const [],
      usuarios: const [
        UsuarioDashboard(rol: 'estudiante'),
        UsuarioDashboard(rol: 'estudiante', estado: 'activo'),
        UsuarioDashboard(rol: 'estudiante', estado: 'inactivo'),
        UsuarioDashboard(rol: 'entrenador'),
      ],
    );
    expect(resumen.estudiantes, 3);
    expect(resumen.estudiantesActivos, 2);
  });
}
