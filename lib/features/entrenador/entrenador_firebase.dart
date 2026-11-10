import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/data/firestore_asistencia_repository.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/historial_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/tomar_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/nomina/presentation/nomina_screen.dart';
import 'package:saman_deportivo/features/entrenador/widgets/con_deporte.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';

/// Las pestañas del entrenador se construyen todas al abrir su pantalla.
/// Sin Firebase inicializado (en las pruebas) se deja la sección vacía
/// en vez de fallar.
Widget _conFirebase(Widget Function() construir) =>
    Firebase.apps.isEmpty ? const SizedBox.shrink() : construir();

Stream<List<Deporte>> _deportesDe(String uid) =>
    FirestoreDeporteRepository().observarPorEntrenador(uid);

/// Confirmadas de un deporte. Filtra también por entrenador: lo exigen las reglas.
ConfirmadasDeDeporte _confirmadasDe(String uid) =>
    (codigo) => FirebaseFirestore.instance
        .collection('inscripciones')
        .where('entrenadorUid', isEqualTo: uid)
        .where('deporteId', isEqualTo: codigo)
        .where('estado', isEqualTo: 'confirmada')
        .snapshots()
        .map((s) => [for (final d in s.docs) Inscripcion.fromMap(d.id, d.data())]);

class NominaFirebase extends StatelessWidget {
  const NominaFirebase({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => _conFirebase(
        () => NominaScreen(
          deportes: _deportesDe(uid),
          confirmadas: _confirmadasDe(uid),
        ),
      );
}

class TomarAsistenciaFirebase extends StatelessWidget {
  const TomarAsistenciaFirebase({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => _conFirebase(
        () => TomarAsistenciaScreen(
          deportes: _deportesDe(uid),
          confirmadas: _confirmadasDe(uid),
          asistencias: FirestoreAsistenciaRepository(entrenadorUid: uid),
          entrenadorUid: uid,
        ),
      );
}

class HistorialAsistenciaFirebase extends StatelessWidget {
  const HistorialAsistenciaFirebase({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => _conFirebase(
        () => HistorialAsistenciaScreen(
          deportes: _deportesDe(uid),
          asistencias: FirestoreAsistenciaRepository(entrenadorUid: uid),
        ),
      );
}