import 'package:dio/dio.dart';

import '../offline/ConnectionStatus.dart';

/// Übersetzt eine beliebige Exception in eine Meldung, die man einem Nutzer
/// zeigen darf. Technische Details gehören ins Log, nicht ins UI.
String userMessage(Object? error) {
  if (error is OfflineException) {
    return 'Keine Verbindung zum Server und noch keine gespeicherten Daten. '
        'Prüfe deine Internetverbindung.';
  }

  if (error is DioException) {
    // 1. Hat das Backend einen ErrorResponse-Body geschickt? Den bevorzugen.
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    // 2. Sonst nach Statuscode entscheiden.
    switch (error.response?.statusCode) {
      case 400:
        return 'Die Eingaben sind unvollständig oder ungültig.';
      case 401:
      case 403:
        return 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';
      case 404:
        return 'Der Eintrag wurde nicht gefunden.';
      case 409:
        return 'Ein Rezept mit diesem Namen existiert bereits.';
      case 502:
      case 503:
      case 504:
        return 'Der Server ist gerade nicht erreichbar. Bitte später erneut versuchen.';
    }

    // 3. Gar keine Antwort bekommen -> Netzwerkproblem.
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Keine Verbindung zum Server. Prüfe deine Internetverbindung.';
      default:
        break;
    }

    // z.B. Verbindung mitten in der Uebertragung abgebrochen.
    if (isConnectivityFailure(error)) {
      return 'Keine Verbindung zum Server. Prüfe deine Internetverbindung.';
    }
  }

  return 'Es ist ein Fehler aufgetreten.';
}