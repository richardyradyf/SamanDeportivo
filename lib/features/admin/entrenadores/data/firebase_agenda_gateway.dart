// Compatibilidad temporal con imports de otros modulos.
// La implementacion real usa solo Firestore: sin Cloud Functions.
import 'firestore_agenda_gateway.dart';
@Deprecated('Usar FirestoreAgendaGateway')
typedef FirebaseAgendaGateway = FirestoreAgendaGateway;
