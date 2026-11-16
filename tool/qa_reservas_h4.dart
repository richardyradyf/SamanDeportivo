import 'package:saman_deportivo/features/admin/entrenadores/data/firestore_agenda_gateway.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/horario_sesion.dart';
import 'package:saman_deportivo/models/enums.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saman_deportivo/features/reservas/data/firestore_reservas_repository.dart';

const opciones = FirebaseOptions(
  apiKey: 'dummy-api-key',
  appId: '1:123456789012:web:0000000000000000000000',
  messagingSenderId: '123456789012',
  projectId: 'demo-saman-reservas-h4',
);

final resultados = <String>[];

void registrar(String mensaje) {
  resultados.add(mensaje);
  debugPrint(mensaje);
}

Future<FirestoreReservasRepository> conectarUsuario(
  String nombre,
  String correo,
) async {
  final app = await Firebase.initializeApp(name: nombre, options: opciones);

  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 9099);

  final db = FirebaseFirestore.instanceFor(app: app);
  db.useFirestoreEmulator('127.0.0.1', 8080);

  await auth.signInWithEmailAndPassword(email: correo, password: 'Prueba123!');

  registrar('Usuario conectado: ${auth.currentUser?.uid}');

  return FirestoreReservasRepository(firestore: db, auth: auth);
}

Future<String?> intentarReserva(
  FirestoreReservasRepository repo,
  String usuario,
  DateTime inicio,
  DateTime fin,
) async {
  try {
    final id = await repo.crear(
      espacioId: 'cancha-qa',
      inicio: inicio,
      fin: fin,
      motivo: 'Prueba de concurrencia H4',
    );

    registrar('$usuario: reserva exitosa ($id)');
    return id;
  } catch (error) {
    registrar('$usuario: reserva rechazada ($error)');
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    registrar('Iniciando pruebas de integracion H4...');

    final a = await conectarUsuario(
      'qa-estudiante-a',
      'qa1@correo.unimet.edu.ve',
    );

    final b = await conectarUsuario(
      'qa-estudiante-b',
      'qa2@correo.unimet.edu.ve',
    );

    final inicio = DateTime.now().add(const Duration(days: 2));

    final fin = inicio.add(const Duration(hours: 1));

    registrar('INT-01: reservas simultaneas');

    final ids = await Future.wait([
      intentarReserva(a, 'Estudiante A', inicio, fin),
      intentarReserva(b, 'Estudiante B', inicio, fin),
    ]);

    final exitosas = ids.whereType<String>().length;

    if (exitosas == 1) {
      registrar('INT-01: APROBADA');
    } else {
      registrar('INT-01: FALLIDA. Reservas exitosas: $exitosas');
    }

    // Limpiar las reservas creadas por esta prueba.
    if (ids[0] != null) {
      await a.cancelar(ids[0]!);
    }

    if (ids[1] != null) {
      await b.cancelar(ids[1]!);
    }

    registrar('Limpieza de reservas completada.');

    // INT-02: comprobar el rechazo de una reserva solapada.
    registrar('INT-02: reserva sobre otra reserva existente');

    final inicio2 = inicio.add(const Duration(hours: 3));
    final fin2 = inicio2.add(const Duration(hours: 1));

    final reservaOriginal = await a.crear(
      espacioId: 'cancha-qa',
      inicio: inicio2,
      fin: fin2,
      motivo: 'Reserva original QA',
    );

    String? reservaSolapada;
    Object? errorSolape;

    try {
      reservaSolapada = await b.crear(
        espacioId: 'cancha-qa',
        inicio: inicio2,
        fin: fin2,
        motivo: 'Reserva solapada QA',
      );
    } catch (error) {
      errorSolape = error;
      registrar('Conflicto detectado: $error');
    }

    if (reservaSolapada == null &&
        errorSolape != null &&
        errorSolape.toString().contains(
          'Ese espacio ya tiene una reserva durante el horario solicitado.',
        )) {
      registrar('INT-02: APROBADA');
    } else {
      registrar('INT-02: FALLIDA O REQUIERE REVISION');
    }

    if (reservaSolapada != null) {
      await b.cancelar(reservaSolapada);
    }

    // INT-05: cancelar y reutilizar el horario.
    registrar('INT-05: cancelacion y reutilizacion del horario');

    await a.cancelar(reservaOriginal);

    final dbA = FirebaseFirestore.instanceFor(
      app: Firebase.app('qa-estudiante-a'),
    );

    final privada = await dbA
        .collection('reservasEspacios')
        .doc(reservaOriginal)
        .get(const GetOptions(source: Source.server));

    final publica = await dbA
        .collection('ocupacionesEspacios')
        .doc(reservaOriginal)
        .get(const GetOptions(source: Source.server));

    final nuevaReserva = await b.crear(
      espacioId: 'cancha-qa',
      inicio: inicio2,
      fin: fin2,
      motivo: 'Reutilizacion de horario QA',
    );

    final nuevaOcupacion = await dbA
        .collection('ocupacionesEspacios')
        .doc(nuevaReserva)
        .get(const GetOptions(source: Source.server));

    if (privada.data()?['estado'] == 'cancelada' &&
        !publica.exists &&
        nuevaOcupacion.exists &&
        nuevaReserva != reservaOriginal) {
      registrar('INT-05: APROBADA');
    } else {
      registrar('INT-05: FALLIDA');
    }

    await b.cancelar(nuevaReserva);

    registrar('Limpieza adicional completada.');

    // Preparar una sesion administrativa independiente.
    final appAdmin = await Firebase.initializeApp(
      name: 'qa-administrador',
      options: opciones,
    );

    final authAdmin = FirebaseAuth.instanceFor(app: appAdmin);
    await authAdmin.useAuthEmulator('127.0.0.1', 9099);

    final dbAdmin = FirebaseFirestore.instanceFor(app: appAdmin);
    dbAdmin.useFirestoreEmulator('127.0.0.1', 8080);

    await authAdmin.signInWithEmailAndPassword(
      email: 'admin@saman.test',
      password: 'Prueba123!',
    );

    final agenda = FirestoreAgendaGateway(firestore: dbAdmin, auth: authAdmin);

    final deporteRef = dbAdmin.collection('deportes').doc('TEN-01');

    Future<Deporte> leerDeporte() async {
      final snap = await deporteRef.get(
        const GetOptions(source: Source.server),
      );

      return Deporte.fromMap(snap.id, snap.data()!);
    }

    final fecha = DateTime.now().toUtc().add(const Duration(days: 5));

    final inicioClase = DateTime.utc(fecha.year, fecha.month, fecha.day, 20);

    final finReservaClase = inicioClase.add(const Duration(hours: 1));

    final horario = HorarioSesion(
      dia: DiaSemana.values[inicioClase.weekday - 1],
      horaInicio: '16:00',
      horaFin: '18:00',
      lugar: 'Cancha QA',
      espacioId: 'cancha-qa',
    );

    // INT-03: una clase existente impide una reserva.
    registrar('INT-03: reserva sobre una clase oficial');

    await agenda.guardarAgenda(
      deporte: await leerDeporte(),
      entrenadorUid: 'ent-qa-1',
      horarios: [horario],
    );

    String? reservaSobreClase;
    Object? errorClase;

    try {
      try {
        reservaSobreClase = await a.crear(
          espacioId: 'cancha-qa',
          inicio: inicioClase,
          fin: finReservaClase,
          motivo: 'Reserva sobre clase QA',
        );
      } catch (error) {
        errorClase = error;
        registrar('Conflicto con clase: $error');
      }

      if (reservaSobreClase == null &&
          errorClase.toString().contains('ocupado por Tenis en ese horario')) {
        registrar('INT-03: APROBADA');
      } else {
        registrar('INT-03: FALLIDA');
      }
    } finally {
      if (reservaSobreClase != null) {
        await a.cancelar(reservaSobreClase);
      }

      await agenda.guardarAgenda(
        deporte: await leerDeporte(),
        entrenadorUid: null,
        horarios: [],
      );
    }

    // INT-04: una reserva existente impide crear una clase.
    registrar('INT-04: clase sobre una reserva activa');

    final reservaPrevia = await a.crear(
      espacioId: 'cancha-qa',
      inicio: inicioClase,
      fin: finReservaClase,
      motivo: 'Reserva previa QA',
    );

    Object? errorAgenda;

    try {
      try {
        await agenda.guardarAgenda(
          deporte: await leerDeporte(),
          entrenadorUid: 'ent-qa-1',
          horarios: [horario],
        );
      } catch (error) {
        errorAgenda = error;
        registrar('Conflicto de agenda: $error');
      }

      final deporteFinal = await leerDeporte();

      final reservaActiva = await dbA
          .collection('reservasEspacios')
          .doc(reservaPrevia)
          .get(const GetOptions(source: Source.server));

      if (errorAgenda.toString().contains(
            'Una reserva existente utiliza ese espacio y horario',
          ) &&
          deporteFinal.horarios.isEmpty &&
          reservaActiva.data()?['estado'] == 'activa') {
        registrar('INT-04: APROBADA');
      } else {
        registrar('INT-04: FALLIDA');
      }
    } finally {
      if ((await leerDeporte()).horarios.isNotEmpty) {
        await agenda.guardarAgenda(
          deporte: await leerDeporte(),
          entrenadorUid: null,
          horarios: [],
        );
      }

      await a.cancelar(reservaPrevia);
    }

    // INT-06 e INT-07: cancelaciones fuera del plazo permitido.

    final casosTemporales = {
      'INT-06': 'qa-reserva-en-curso',
      'INT-07': 'qa-reserva-finalizada',
    };

    for (final caso in casosTemporales.entries) {
      registrar('${caso.key}: ${caso.value}');

      final privadaRef = dbA.collection('reservasEspacios').doc(caso.value);

      final publicaRef = dbA.collection('ocupacionesEspacios').doc(caso.value);

      final controlRef = dbA.collection('control').doc('agenda');

      final controlAntes = await controlRef.get(
        const GetOptions(source: Source.server),
      );

      Object? errorTemporal;

      try {
        await a.cancelar(caso.value);
      } catch (error) {
        errorTemporal = error;
        registrar('Cancelacion rechazada: $error');
      }

      final privadaDespues = await privadaRef.get(
        const GetOptions(source: Source.server),
      );

      final publicaDespues = await publicaRef.get(
        const GetOptions(source: Source.server),
      );

      final controlDespues = await controlRef.get(
        const GetOptions(source: Source.server),
      );

      if (errorTemporal != null &&
          errorTemporal.toString().contains(
            'Solo puedes cancelar una reserva antes de que comience.',
          ) &&
          privadaDespues.data()?['estado'] == 'activa' &&
          publicaDespues.exists &&
          controlAntes.data()?['version'] ==
              controlDespues.data()?['version']) {
        registrar('${caso.key}: APROBADA');
      } else {
        registrar('${caso.key}: FALLIDA');
      }
    }

    registrar('Pruebas de integracion finalizadas.');
  } catch (error, stack) {
    registrar('ERROR DE INTEGRACION: $error');
    debugPrintStack(stackTrace: stack);
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Samán Deportivo - QA H4')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: resultados.map((mensaje) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(mensaje),
            );
          }).toList(),
        ),
      ),
    ),
  );
}
