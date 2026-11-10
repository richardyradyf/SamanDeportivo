/// Funciones para leer de forma segura los datos que llegan de Firestore.
/// Se usan en los `fromMap` de los modelos del Hito 3.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore devuelve las fechas como [Timestamp].
DateTime leerFecha(Object? valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? leerFechaOpcional(Object? valor) {
  return valor == null ? null : leerFecha(valor);
}

/// Firestore puede devolver un número como int o como double.
int leerEntero(Object? valor) => (valor as num?)?.toInt() ?? 0;

double leerDecimal(Object? valor) => (valor as num?)?.toDouble() ?? 0;

List<String> leerListaTexto(Object? valor) {
  return (valor as List<dynamic>?)?.map((e) => e.toString()).toList() ??
      const [];
}

/// Fecha sin hora (00:00), para comparar días.
DateTime soloDia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

/// Formato AAAA-MM-DD, usado en los IDs de asistencia.
String fechaComoId(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$mes-$dia';
}
