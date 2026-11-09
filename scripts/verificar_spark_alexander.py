#!/usr/bin/env python3
"""Diagnóstico ESTÁTICO del tramo de Alexander; no sustituye pruebas reales.

No modifica archivos. Solo detecta restos del backend y la integridad del
pipeline Firestore de agenda y reseñas.
"""
from __future__ import annotations
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
checks = {
    'Reglas de agenda atómica': ('firestore.rules', ('function agendaConControl(', 'function controlAgendaValido(', "controlId == 'agenda'")),
    'Reglas de moderación atómica': ('firestore.rules', ('function moderacionConControl(', "controlId == 'resenas'", 'function agregadoEstudianteAutorizado(')),
    'Gateway agenda Spark': ('lib/features/admin/entrenadores/data/firestore_agenda_gateway.dart', ('class FirestoreAgendaGateway', "collection('control').doc('agenda')", 'runTransaction<void>')),
    'Moderación de reseñas': ('lib/features/estudiante/catalogo/data/firestore_resena_repository.dart', ("doc('resenas')", 'transaccion.update(documento', 'transaccion.update(deporte')),
    'Inyección del gateway': ('lib/features/admin/screens/inicio_admin_screen.dart', ('FirestoreAgendaGateway()',)),
    'Provisioner Spark': ('lib/features/admin/entrenadores/data/spark_entrenador_provisioner.dart', ('FirebaseAuth',)),
    'Pruebas de concurrencia': ('test/firestore/spark_concurrencia.rules.test.mjs', ('Promise.allSettled', 'dos administradores', 'version')),
}
errors = []
for label, (rel, markers) in checks.items():
    path = root / rel
    if not path.is_file():
        errors.append(f'Falta {rel}'); continue
    text = path.read_text(encoding='utf-8')
    missing = [m for m in markers if m not in text]
    if missing:
        errors.append(f'{label}: faltan {missing}')
    else:
        print(f'OK {label}')

# No ampliar a toda la aplicación: pagos e inscripciones todavía usan sus
# propias dependencias pendientes de integración.
for rel in [
    'lib/features/admin/entrenadores/data/firestore_agenda_gateway.dart',
    'lib/features/admin/entrenadores/data/spark_entrenador_provisioner.dart',
]:
    path = root / rel
    if path.is_file():
        source = path.read_text(encoding='utf-8')
        if "package:cloud_functions/cloud_functions.dart" in source or '.httpsCallable(' in source:
            errors.append(f'Cloud Functions todavía presente en {rel}')

for problem in errors:
    print('ERROR', problem, file=sys.stderr)
if errors:
    sys.exit(1)
print('OK: inspección estática de Alexander. Faltan las pruebas reales y revisión manual.')
