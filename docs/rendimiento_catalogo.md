# Rendimiento del catálogo (Hito 4)

Responsable: Gabriel Cedeño.

Este documento explica cómo medimos los tres requisitos de rendimiento del
catálogo y dónde anotar los resultados.

| Requisito | Límite | Cómo se mide |
|---|---|---|
| Carga de la app | Menos de 3 s | Lighthouse sobre la app publicada en Firebase Hosting y medición interna del landing |
| Cupos actualizados | Menos de 2 s | Script `scripts/medir_cupos.mjs` en el emulador y prueba con dos navegadores |
| Imágenes livianas | Sin descargar ni decodificar fotos de más | `ImagenDeporte` y sus pruebas automáticas |

## 1. Carga de la app (menos de 3 s)

### Medición interna

El landing anota cuánto tardan en llegar los deportes desde que se abre la
pantalla. El tiempo sale en la consola así:

```
[rendimiento] landing: deportes visibles: 640 ms (límite 3000 ms) OK
```

1. Corre la app en modo perfil, que se parece al modo de producción:
   `flutter run -d chrome --profile`.
2. Abre la app sin iniciar sesión y espera a que salgan los deportes.
3. Copia el tiempo de la consola en la tabla de resultados.
4. Repite 5 veces, recargando la página, y anota el promedio.

### Lighthouse

La medición interna empieza cuando Flutter ya cargó. Para medir también la
descarga de la app usamos Lighthouse sobre la versión publicada.

1. Abre la app publicada en Chrome, en una ventana de incógnito.
2. Abre las herramientas de desarrollador (Cmd + Opción + I) y entra en la
   pestaña Lighthouse.
3. Marca solo "Rendimiento", elige "Computadora" y pulsa "Analizar la carga
   de la página".
4. Anota "Largest Contentful Paint" y "Speed Index".
5. Repite con "Móvil".

Lighthouse en "Móvil" simula una conexión 4G lenta. Si ahí pasa de 3 s,
anótalo igual: es el peor caso, y la segunda visita es más rápida porque la
PWA guarda la app en el navegador.

## 2. Cupos actualizados (menos de 2 s)

### En el emulador

El script crea un deporte de prueba, lo escucha en tiempo real como la
pantalla de detalle, cambia sus cupos 20 veces y mide cuánto tarda cada
cambio en llegar. Al final borra el deporte.

1. En una terminal: `npm run emulador`.
2. En otra terminal: `node scripts/medir_cupos.mjs`.
3. Anota el promedio, el 95 % y el máximo que imprime.

El script mide el tiempo de Firestore en tu computadora, sin internet de
por medio.

### Con la base de datos real

1. Abre la app en dos navegadores, cada uno con un estudiante distinto.
2. En el primero, abre el detalle de un deporte con cupos.
3. En el segundo, inscríbete en ese mismo deporte.
4. Graba la pantalla de los dos navegadores y mide en el video el tiempo
   entre el toque en "Inscribirme" y el cambio de cupos en el primero.
5. Repite 5 veces y anota el promedio.

## 3. Imágenes livianas

`ImagenDeporte` (en `lib/features/estudiante/catalogo/widgets/`) muestra las
fotos de los deportes en la tarjeta y en el detalle:

- Decodifica cada foto al ancho en que se muestra, por la densidad de la
  pantalla, con un tope de 1600 px. Una foto de 4000 px en una tarjeta de
  300 px se decodifica a 600 px en un celular con densidad 2.
- Mientras la foto llega, o si no llega, muestra el verde de la marca con el
  ícono de la disciplina, así la tarjeta nunca queda vacía.

Las pruebas de `test/features/estudiante/catalogo/rendimiento_test.dart`
comprueban las dos cosas.

Las fotos las sube el administrador. Para que pesen poco desde el origen,
conviene subirlas en JPG o WebP de máximo 1600 px de ancho.

## Resultados

Fecha de la medición: 9 de noviembre de 2026, en una MacBook Pro M1, con el
emulador de Firebase en la misma computadora y la app en modo perfil
(`flutter run -d chrome --profile --dart-define=USAR_EMULADOR=true`).

| Medición | Resultado | Límite | ¿Cumple? |
|---|---|---|---|
| Landing: deportes visibles (promedio de 5) | 73 ms (100, 110, 36, 84 y 36 ms) | 3000 ms | Sí |
| Landing: desde que se abre la página hasta ver los deportes (promedio de 5) | 1,2 s; la más lenta, 2,2 s | 3000 ms | Sí |
| Lighthouse computadora: Largest Contentful Paint | Pendiente: falta la app publicada en Hosting | 3000 ms | |
| Lighthouse móvil: Largest Contentful Paint | Pendiente: falta la app publicada en Hosting | 3000 ms | |
| Cupos en el emulador: máximo de 20 | 27 ms (promedio 4 ms; 95 %: 4 ms) | 2000 ms | Sí |
| Cupos con la base real: promedio de 5 | Pendiente: falta la app publicada en Hosting | 2000 ms | |

Cómo se sacó la segunda fila: la línea `[rendimiento]` mide desde que se abre
la pantalla del landing, no desde que se abre la página. Para el tiempo
completo se sumó, en cada carga, el momento en que la app abre la conexión
con Firestore (Resource Timing del navegador) y la medición interna. La
primera carga fue la más lenta porque el navegador todavía no tenía en caché
el motor gráfico de Flutter.
