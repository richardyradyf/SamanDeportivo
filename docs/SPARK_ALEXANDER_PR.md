# PR listo para adaptar — Migración de Alexander a Firebase Spark

**Título propuesto:** `refactor(spark): entrenadores, agenda y reseñas sin Cloud Functions`

**Base:** `develop` · **Head:** `refactor/alexander-spark-h3-paso2`

## Resumen

La migración sustituye el aprovisionamiento y la agenda basados en Cloud Functions por operaciones de Firebase Auth/Firestore aptas para Spark y protege los agregados de reseñas con escritura atómica. Se mantiene el modelo de roles y se agregan pruebas de permisos, integridad y concurrencia.

### Cambios

- Entrenadores: segunda app Auth; escritura atómica de perfil + índice; invitaciones por reset de contraseña. Rollback compensatorio de Auth si Firestore falla.
- Agenda: `FirestoreAgendaGateway`, versión global `control/agenda`, detección de solapamientos y actualización de deporte/control en transacción.
- Reseñas: estudiante solo con inscripción confirmada; actualización de promedio en la misma transacción; moderación con `control/resenas` y validaciones matemáticas en reglas.
- Pruebas: suite principal de reglas y nueva prueba de dos administradores.
- Se incluye un **git revert -m 1** de merge PR #24 para retirar el trigger obsoleto, **sin eliminar funciones de otros módulos**.

### Verificaciones

Pegar los resultados ejecutados localmente (no marcar hasta completar):

- [ ] `npm run test:rules`: ____/127
- [ ] `firebase emulators:exec ... spark_concurrencia.rules.test.mjs`: ____/5
- [ ] `flutter analyze`: ____
- [ ] `flutter test`: ____/339
- [ ] Prueba manual de dos administradores: ____
- [ ] Prueba manual de invitación de entrenador: ____
- [ ] Prueba manual de reseñas y visibilidad: ____
- [ ] Revert de PR #24 en commit separado: ____ (SHA)

### Límites y riesgos

Las reglas no pueden detectar por sí mismas todos los conflictos de agenda entre deportes. La comprobación del catálogo es responsabilidad del gateway de administración; las transacciones y el documento `control/agenda` evitan aceptar snapshots anteriores cuando los clientes usan el protocolo. Los documentos de control global pueden convertirse en punto de contención. Auth/Firestore no es transacción entre servicios.

### Fuera del PR

No se habilita ninguna escritura sobre `inscripciones`/`pagos`, ni se modifica la simulación de PayPal. No se borra `functions/`: el equipo debe migrar y comprobar primero sus restantes dependencias.

### Orden de integración

Solicitar revisión de Richard y coordinar despliegue de reglas con los módulos que están desarrollando Mariana y Andrés. No publicar en Firebase sin verificar funcionamiento en emuladores y datos de prueba.
