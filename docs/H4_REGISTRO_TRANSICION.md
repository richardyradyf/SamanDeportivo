# Hito 4 — Transición de registro a sesión

## Problema observado

Después de crear la cuenta, Firebase Authentication inicia la sesión antes de
que `UsuarioService.guardarEstudiante()` termine la transacción que guarda
`usuarios/{uid}`, `cedulas/{cedula}` y `carnets/{carnet}`.

El listener de `SesionController` puede recibir entonces un primer snapshot
sin `usuarios/{uid}`. Antes, la aplicación cambiaba inmediatamente a
`EstadoSesion.sinPerfil`, por lo que `AuthGate` mostraba brevemente la pantalla
«No pudimos cargar tu perfil». Cuando llegaba el perfil, cambiaba a la pantalla
del estudiante. El registro real no había fallado.

## Corrección

- El primer snapshot sin perfil mantiene `EstadoSesion.cargando` hasta 10 s.
- Si llega un perfil válido, se cancela la espera y se abre el inicio del rol.
- Si la ausencia persiste, se muestra la pantalla de error habitual.
- Si Firestore devuelve un error de lectura o un perfil inválido, se reporta
  directamente sin esperar.
- Al cerrar o cambiar sesión se cancela el temporizador y se ignoran callbacks
  tardíos que correspondan a otra cuenta.

El cambio no altera la creación de cuentas, los índices ni las reglas de
Firestore. Tampoco modifica el caso `Rol.entrenador` de `AuthGate`, reservado a
la rama de Richard.

## Comprobaciones

1. Crear una cuenta nueva y confirmar que nunca aparezca la pantalla de error
   temporal mientras se escribe el perfil.
2. Comprobar que al terminar abre el panel del estudiante.
3. Iniciar sesión con una cuenta de Firebase Auth sin documento en `usuarios`:
   durante la espera debe aparecer el indicador de carga, y después el error.
4. Cerrar sesión y entrar con otra cuenta para confirmar que un temporizador
   anterior no cambie su pantalla.

```bash
dart analyze
flutter test test/features/auth/espera_perfil_test.dart test/features/auth/sesion_controller_transicion_test.dart test/core/router/auth_gate_test.dart
```
