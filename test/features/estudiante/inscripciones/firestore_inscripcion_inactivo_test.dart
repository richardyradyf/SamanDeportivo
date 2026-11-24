import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/features/estudiante/inscripciones/data/firestore_inscripcion_repository.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/enums.dart';
import 'package:saman_deportivo/models/estudiante.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';

const _estudiante = Estudiante(
  uid: 'est-1',
  cedula: '28000001',
  nombre: 'Ana Pérez',
  correo: 'ana@correo.unimet.edu.ve',
  carnet: '20231001',
);

final _deporte = Deporte(
  codigo: 'FUT-01',
  nombre: 'Fútbol sala',
  descripcion: '',
  disciplina: Disciplina.colectivo,
  costo: 10,
  cupoMaximo: 20,
  creadoEn: DateTime(2026, 11, 1),
);

void main() {
  test(
    'conserva el rechazo por inactividad al cruzar la transacción web',
    () async {
      final firestore = _FirestoreWebFalso(EstadoEstudiante.inactivo);
      final repositorio = FirestoreInscripcionRepository(
        firestore: firestore,
        auth: _AuthFalsa(),
      );

      // La copia local sigue activa; manda el estado leído en la transacción.
      await expectLater(
        repositorio.inscribirse(estudiante: _estudiante, deporte: _deporte),
        throwsA(same(InscripcionException.estudianteInactivo)),
      );

      expect(firestore.escrituras, isEmpty);
      expect(
        firestore.documentos.containsKey('inscripciones/est-1_FUT-01'),
        isFalse,
      );
      expect(firestore.documentos['deportes/FUT-01']!['cuposOcupados'], 0);
    },
  );

  test(
    'un estudiante activo en el servidor conserva el flujo de inscripción',
    () async {
      final firestore = _FirestoreWebFalso(EstadoEstudiante.activo);
      final repositorio = FirestoreInscripcionRepository(
        firestore: firestore,
        auth: _AuthFalsa(),
      );

      final inscripcion = await repositorio.inscribirse(
        estudiante: _estudiante.copyWith(estado: EstadoEstudiante.inactivo),
        deporte: _deporte,
      );

      expect(inscripcion.estado, EstadoInscripcion.pendiente);
      expect(firestore.escrituras, [
        'inscripciones/est-1_FUT-01',
        'deportes/FUT-01',
      ]);
      expect(firestore.documentos['deportes/FUT-01']!['cuposOcupados'], 1);
    },
  );

  test('un error de lectura no se presenta como estudiante inactivo', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final firestore = _FirestoreWebFalso(EstadoEstudiante.activo)
      ..errorPerfil = error;
    final repositorio = FirestoreInscripcionRepository(
      firestore: firestore,
      auth: _AuthFalsa(),
    );

    await expectLater(
      repositorio.inscribirse(estudiante: _estudiante, deporte: _deporte),
      throwsA(same(error)),
    );
    expect(firestore.escrituras, isEmpty);
  });
}

mixin _SinImplementar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _AuthFalsa with _SinImplementar implements FirebaseAuth {
  @override
  User get currentUser => _UsuarioFalso();
}

class _UsuarioFalso with _SinImplementar implements User {
  @override
  String get uid => _estudiante.uid;
}

class _FirestoreWebFalso with _SinImplementar implements FirebaseFirestore {
  _FirestoreWebFalso(EstadoEstudiante estado) {
    documentos['usuarios/est-1'] = _estudiante.copyWith(estado: estado).toMap();
    documentos['deportes/FUT-01'] = _deporte.toMap();
  }

  final documentos = <String, Map<String, dynamic>>{};
  final escrituras = <String>[];
  FirebaseException? errorPerfil;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _ColeccionFalsa(collectionPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaccion = _TransaccionFalsa(this);
    late T resultado;
    try {
      resultado = await transactionHandler(transaccion);
    } on InscripcionException catch (error) {
      // Simula el puente web: conserva el texto, pero cambia el tipo del error.
      throw StateError('Dart exception: $error');
    }
    documentos.addAll(transaccion.cambios);
    escrituras.addAll(transaccion.cambios.keys);
    return resultado;
  }
}

class _ColeccionFalsa
    with _SinImplementar
    implements CollectionReference<Map<String, dynamic>> {
  _ColeccionFalsa(this.ruta);

  final String ruta;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _ReferenciaFalsa('$ruta/$path');
}

class _ReferenciaFalsa
    with _SinImplementar
    implements DocumentReference<Map<String, dynamic>> {
  _ReferenciaFalsa(this.path);

  @override
  final String path;
}

class _DocumentoFalso<T extends Object?>
    with _SinImplementar
    implements DocumentSnapshot<T> {
  _DocumentoFalso(this.datos);

  final T? datos;

  @override
  bool get exists => datos != null;

  @override
  T? data() => datos;
}

class _TransaccionFalsa with _SinImplementar implements Transaction {
  _TransaccionFalsa(this.firestore);

  final _FirestoreWebFalso firestore;
  final cambios = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (documentReference.path == 'usuarios/est-1') {
      final error = firestore.errorPerfil;
      if (error != null) throw error;
    }
    return _DocumentoFalso<T>(
      firestore.documentos[documentReference.path] as T?,
    );
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    cambios[documentReference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    final datos = Map<String, dynamic>.from(
      firestore.documentos[documentReference.path]!,
    );
    for (final entrada in data.entries) {
      datos[entrada.key as String] = entrada.value;
    }
    cambios[documentReference.path] = datos;
    return this;
  }
}
