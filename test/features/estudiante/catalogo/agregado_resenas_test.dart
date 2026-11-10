import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/data/agregado_resenas.dart';

void main() {
  const vacio = AgregadoResenas(promedio: 0, total: 0);
  // Dos reseñas visibles: 4 y 5 estrellas.
  const dos = AgregadoResenas(promedio: 4.5, total: 2);

  group('Al guardar una reseña', () {
    test('la primera reseña deja el promedio en su puntuación', () {
      expect(
        vacio.alGuardar(nueva: 3),
        const AgregadoResenas(promedio: 3, total: 1),
      );
    });

    test('una reseña nueva sube el total en 1', () {
      // (4 + 5 + 3) / 3 = 4
      expect(
        dos.alGuardar(nueva: 3),
        const AgregadoResenas(promedio: 4, total: 3),
      );
    });

    test('editar una reseña deja el total igual y corrige el promedio', () {
      // El que puso 5 cambia a 2: (4 + 2) / 2 = 3
      expect(
        dos.alGuardar(nueva: 2, anterior: 5),
        const AgregadoResenas(promedio: 3, total: 2),
      );
    });

    test('editar con la misma puntuación no cambia nada', () {
      expect(dos.alGuardar(nueva: 4, anterior: 4), dos);
    });

    test('editar una reseña oculta no cambia nada, porque no cuenta', () {
      expect(dos.alGuardar(nueva: 1, anterior: 5, anteriorOculta: true), dos);
    });

    test('si los datos guardados estaban mal, no divide entre cero', () {
      expect(
        vacio.alGuardar(nueva: 4, anterior: 2),
        const AgregadoResenas(promedio: 4, total: 1),
      );
    });
  });

  group('Al ocultar o mostrar una reseña', () {
    test('ocultar la saca del promedio', () {
      // Se oculta la de 5: queda solo la de 4.
      expect(dos.quitar(5), const AgregadoResenas(promedio: 4, total: 1));
    });

    test('ocultar la última deja el deporte sin calificaciones', () {
      const una = AgregadoResenas(promedio: 4, total: 1);

      expect(una.quitar(4), vacio);
    });

    test('mostrarla otra vez la vuelve a sumar', () {
      const una = AgregadoResenas(promedio: 4, total: 1);

      expect(una.agregar(5), dos);
    });
  });

  test('el promedio nunca sale de 0 a 5 aunque los datos estén mal', () {
    const raro = AgregadoResenas(promedio: 5, total: 1);

    expect(raro.alGuardar(nueva: 5, anterior: 1).promedio, 5);
  });
}
