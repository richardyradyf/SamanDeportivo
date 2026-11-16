# Hito 4 — Perfil del estudiante y teléfono internacional

**Responsable:** Alexander. **Integración con nómina/pagos:** Andrés.

## Contrato de datos

- `usuarios/{uid}.telefono`: texto en formato E.164, por ejemplo `+584121234567`.
- Los registros nuevos exigen teléfono en el formulario. En Firestore, el campo
  sigue siendo opcional para poder leer los perfiles históricos sin migración
  forzada. Si está presente, las reglas exigen E.164.
- El carnet nuevo o modificado contiene únicamente entre 4 y 24 dígitos; el
  índice único en `/carnets/{carnet}` sigue moviéndose de manera atómica.
- El correo de registro debe pertenecer a `@correo.unimet.edu.ve`.
- La cédula continúa siendo inmutable. El estudiante puede editar nombre,
  carnet y teléfono; el cambio de correo requiere verificación por Firebase Auth.
- El administrador puede ver nombre, cédula, carnet, correo y teléfono en su
  listado de estudiantes.

## Cambio de correo

1. El estudiante selecciona **Cambiar correo** e introduce la nueva dirección.
2. Firebase Auth envía el enlace de verificación con `verifyBeforeUpdateEmail`.
3. Al completar la verificación, vuelve a la sesión y selecciona
   **Sincronizar correo**. El cliente recarga el usuario y su token.
4. Firestore solo acepta el nuevo `correo` si coincide con el correo del token
   de Authentication. Puede requerirse iniciar sesión nuevamente.

No se permite modificar `correo` directamente en Firestore sin actualizar
Firebase Auth. Las inscripciones antiguas pueden conservar una copia histórica
del correo; los consumidores de nómina deben contemplar esa posibilidad.

## Pendiente de integración — Andrés

Andrés debe agregar `estudianteTelefono` al modelo de inscripción, copiar
`usuarios/{uid}.telefono` al crearla, actualizar la lista `hasOnly`/validación
de las reglas de inscripciones y presentarlo en la nómina del entrenador.
No debe modificar los estados del pago al implementar el reintento en sandbox.
Para inscripciones históricas sin teléfono, mostrar **No registrado** hasta que
se actualice o migre el dato. Coordinar con Richard la pantalla de entrenador.

## Verificación antes del PR

```bash
dart analyze
flutter test test/features/auth test/features/perfil test/features/admin/administracion
firebase emulators:exec --config firebase.security.test.json --project demo-saman-perfil --only firestore "node --test test/firestore/firestore.rules.test.mjs test/firestore/registro_unico.rules.test.mjs"
```

No desplegar reglas a producción hasta verificar las pruebas en el emulador y
coordinar con Richard el orden de integración.
