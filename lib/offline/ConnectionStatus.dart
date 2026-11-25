import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Merkt sich, ob der Server beim letzten Versuch erreichbar war.
///
/// Es gibt bewusst keinen Blick auf WLAN/Mobilfunk: "verbunden" heisst im
/// Supermarkt-Keller noch lange nicht, dass Anfragen durchkommen. Massgeblich
/// ist allein, ob echte Requests ankommen - das meldet der
/// [ConnectivityInterceptor].
class ConnectionStatus {
  /// true = zuletzt kam nichts durch.
  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  final _reconnected = StreamController<void>.broadcast();

  bool get isOffline => offline.value;

  /// Feuert beim Wechsel von offline auf online.
  Stream<void> get onReconnected => _reconnected.stream;

  void reportSuccess() {
    if (!offline.value) return;
    offline.value = false;
    if (!_reconnected.isClosed) _reconnected.add(null);
  }

  void reportFailure(Object? error) {
    if (isConnectivityFailure(error)) offline.value = true;
  }

  void dispose() {
    _reconnected.close();
    offline.dispose();
  }
}

/// Wird geworfen, wenn weder der Server erreichbar ist noch lokale Daten da sind.
class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException: keine Verbindung und keine gespeicherten Daten';
}

/// true, wenn der Fehler "Server nicht erreichbar" bedeutet - im Gegensatz zu
/// "Server hat geantwortet und abgelehnt".
bool isConnectivityFailure(Object? error) {
  if (error is OfflineException) return true;
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status != null) {
      // Proxy/Gateway erreichbar, Dienst dahinter nicht.
      return status == 502 || status == 503 || status == 504;
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        final inner = error.error;
        return inner is SocketException ||
            inner is HttpException ||
            inner is TlsException ||
            inner is TimeoutException;
      default:
        return false;
    }
  }
  return error is SocketException || error is TimeoutException;
}

/// Haelt den [ConnectionStatus] anhand der tatsaechlichen Requests aktuell.
class ConnectivityInterceptor extends Interceptor {
  final ConnectionStatus status;

  ConnectivityInterceptor(this.status);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    status.reportSuccess();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isConnectivityFailure(err)) {
      status.reportFailure(err);
    } else if (err.response != null) {
      // Auch ein 404 oder 500 beweist: der Server ist erreichbar.
      status.reportSuccess();
    }
    handler.next(err);
  }
}
