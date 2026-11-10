import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/theme/app_theme.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/medicion_rendimiento.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/widgets/imagen_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';

Deporte _deporte({String? imagenUrl}) => Deporte(
  codigo: 'NAT-01',
  nombre: 'Natación',
  descripcion: '',
  disciplina: Disciplina.acuatico,
  costo: 10,
  cupoMaximo: 10,
  imagenUrl: imagenUrl,
  creadoEn: DateTime(2026, 11, 1),
);

Future<void> _mostrarImagen(WidgetTester tester, Deporte deporte) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: Center(
        child: SizedBox(
          width: 300,
          height: 100,
          child: ImagenDeporte(deporte: deporte),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Imágenes livianas', () {
    test('se decodifican al ancho en pantalla por la densidad, con tope', () {
      expect(ImagenDeporte.anchoDecodificado(300, 2), 600);
      expect(ImagenDeporte.anchoDecodificado(300, 3), 900);
      expect(ImagenDeporte.anchoDecodificado(1200, 3), 1600);
    });

    testWidgets('con foto, la pide al tamaño de la tarjeta y no la original', (
      tester,
    ) async {
      await _mostrarImagen(
        tester,
        _deporte(imagenUrl: 'https://ejemplo.test/natacion.jpg'),
      );

      final imagen = tester.widget<Image>(find.byType(Image));
      expect(imagen.image, isA<ResizeImage>());
      expect((imagen.image as ResizeImage).width, 600);
    });

    testWidgets('si la foto no carga, se ve el ícono de la disciplina', (
      tester,
    ) async {
      // En las pruebas no hay internet: la descarga falla a propósito.
      await _mostrarImagen(
        tester,
        _deporte(imagenUrl: 'https://ejemplo.test/natacion.jpg'),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pool), findsOneWidget);
    });

    testWidgets('sin foto, muestra el ícono sin descargar nada', (
      tester,
    ) async {
      await _mostrarImagen(tester, _deporte());

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.pool), findsOneWidget);
    });
  });

  group('Mediciones', () {
    setUp(MedicionRendimiento.registro.clear);

    test('marca si cada tiempo cumple su límite', () {
      final rapida = MedicionRendimiento.registrar(
        'catálogo',
        const Duration(milliseconds: 1200),
        limite: MedicionRendimiento.limiteCarga,
      );
      final lenta = MedicionRendimiento.registrar(
        'cupos',
        const Duration(milliseconds: 2500),
        limite: MedicionRendimiento.limiteCupos,
      );

      expect(rapida.cumple, isTrue);
      expect(lenta.cumple, isFalse);
      expect(MedicionRendimiento.registro, hasLength(2));
      expect(lenta.toString(), contains('LENTO'));
    });

    test('los límites son los del Hito 4', () {
      expect(MedicionRendimiento.limiteCarga, const Duration(seconds: 3));
      expect(MedicionRendimiento.limiteCupos, const Duration(seconds: 2));
    });
  });
}
