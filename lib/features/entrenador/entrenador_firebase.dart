import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:saman_deportivo/features/admin/deportes/data/firestore_deporte_repository.dart';
import 'package:saman_deportivo/features/admin/dashboard/domain/resumen_asistencia_admin.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/data/firestore_asistencia_repository.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/historial_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/asistencia/presentation/tomar_asistencia_screen.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/dashboard_entrenador_screen.dart';
import 'package:saman_deportivo/features/entrenador/dashboard/resumen_en_vivo.dart';
import 'package:saman_deportivo/features/entrenador/disciplinas/detalle_disciplina_screen.dart';
import 'package:saman_deportivo/features/entrenador/disciplinas/mis_disciplinas_screen.dart';
import 'package:saman_deportivo/features/entrenador/nomina/presentation/nomina_screen.dart';
import 'package:saman_deportivo/features/entrenador/widgets/con_deporte.dart';
import 'package:saman_deportivo/features/estudiante/catalogo/data/firestore_resena_repository.dart';
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
        .map(
          (s) => [for (final d in s.docs) Inscripcion.fromMap(d.id, d.data())],
        );

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

class MisDisciplinasFirebase extends StatelessWidget {
  const MisDisciplinasFirebase({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => _conFirebase(
    () => MisDisciplinasScreen(
      deportes: _deportesDe(uid),
      onAbrir: (deporte) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleDisciplinaScreen(
            deporte: deporte,
            resenas: FirestoreResenaRepository().observar(deporte.codigo),
          ),
        ),
      ),
    ),
  );
}

class DashboardEntrenadorFirebase extends StatelessWidget {
  const DashboardEntrenadorFirebase({
    super.key,
    required this.uid,
    required this.nombre,
  });

  final String uid;
  final String nombre;

  @override
  Widget build(BuildContext context) => _conFirebase(() {
    final asistencias = FirestoreAsistenciaRepository(entrenadorUid: uid);
    return DashboardEntrenadorScreen(
      nombre: nombre,
      resumen: resumenEnVivo(
        deportes: _deportesDe(uid),
        asistenciasDe: (codigo) {
          final hoy = DateTime.now();
          return asistencias.observarDeDeporte(
            codigo,
            desde: ResumenAsistenciaAdmin.inicioTresMeses(hoy),
            hasta: DateTime(hoy.year, hoy.month, hoy.day + 1),
          );
        },
      ),
    );
  });
}
