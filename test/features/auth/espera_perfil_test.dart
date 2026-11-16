import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/auth/controllers/espera_perfil.dart';

void main() {
  testWidgets('oculta el error transitorio durante el período de gracia', (
    tester,
  ) async {
    final espera = EsperaPerfil(duracion: const Duration(seconds: 4));
    addTearDown(espera.cancelar);
    var errores = 0;

    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 3));
    expect(errores, 0);
    expect(espera.pendiente, isTrue);

    await tester.pump(const Duration(seconds: 1));
    expect(errores, 1);
    expect(espera.pendiente, isFalse);
  });

  testWidgets('al llegar el perfil cancela el error pendiente', (tester) async {
    final espera = EsperaPerfil(duracion: const Duration(seconds: 4));
    addTearDown(espera.cancelar);
    var errores = 0;

    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 2));
    espera.cancelar();
    await tester.pump(const Duration(seconds: 8));

    expect(errores, 0);
    expect(espera.pendiente, isFalse);
  });

  testWidgets('snapshots vacíos repetidos no reinician la espera', (
    tester,
  ) async {
    final espera = EsperaPerfil(duracion: const Duration(seconds: 4));
    addTearDown(espera.cancelar);
    var errores = 0;

    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 3));
    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 1));

    expect(errores, 1);
  });

  testWidgets('una nueva sesión puede iniciar una nueva espera', (
    tester,
  ) async {
    final espera = EsperaPerfil(duracion: const Duration(seconds: 4));
    addTearDown(espera.cancelar);
    var errores = 0;

    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 1));
    espera.cancelar();
    espera.iniciar(() => errores++);
    await tester.pump(const Duration(seconds: 4));

    expect(errores, 1);
  });
}
