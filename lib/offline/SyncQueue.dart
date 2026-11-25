import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ConnectionStatus.dart';
import 'LocalStore.dart';

/// Eine Aenderung, die noch zum Server muss.
class PendingOp {
  final int seq;
  final String type;
  final Map<String, dynamic> data;

  /// Zaehlt nur Fehlversuche, bei denen der Server geantwortet hat (5xx).
  int attempts;

  PendingOp({
    required this.seq,
    required this.type,
    required this.data,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'type': type,
        'data': data,
        'attempts': attempts,
      };

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
        seq: (json['seq'] as num).toInt(),
        type: json['type'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// Eine Aenderung, die der Server endgueltig abgelehnt hat und die deshalb
/// verworfen wurde.
class SyncFailure {
  final PendingOp op;
  final Object error;

  SyncFailure(this.op, this.error);
}

typedef OpExecutor = Future<void> Function(PendingOp op);

/// Warteschlange fuer Aenderungen, die offline gemacht wurden.
///
/// Ablauf: Die App aendert zuerst ihre lokalen Daten und legt die Aenderung
/// hier ab. [flush] schickt die Eintraege strikt in ihrer Reihenfolge zum
/// Server. Ohne Verbindung bleibt alles liegen (auch ueber einen App-Neustart
/// hinweg) und wird beim naechsten Versuch nachgeholt.
///
/// Offline angelegte Eintraege haben noch keine Server-ID. Sie bekommen eine
/// negative vorlaeufige ID ([newTempId]); sobald der Server die echte vergeben
/// hat, wird sie mit [mapId] hinterlegt und [resolve] uebersetzt fortan.
class SyncQueue {
  static const _storeKey = 'sync_queue';

  /// So oft darf ein Eintrag an einem 5xx scheitern, bevor er verworfen wird.
  /// Ohne diese Grenze wuerde ein einziger kaputter Eintrag alle folgenden
  /// fuer immer blockieren.
  static const maxServerErrorAttempts = 3;

  static const _maxIdMappings = 2000;

  final LocalStore store;

  /// Anzahl wartender Aenderungen (fuer die Anzeige).
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  final _failures = StreamController<SyncFailure>.broadcast();

  final Map<String, OpExecutor> _executors = {};
  final List<PendingOp> _ops = [];
  final Map<String, int> _idMap = {};
  int _nextTempId = -1;
  int _nextSeq = 1;

  bool _loaded = false;
  Future<void>? _loading;
  Future<bool>? _running;

  SyncQueue({required this.store});

  int get pendingCount => _ops.length;

  /// Endgueltig abgelehnte Aenderungen.
  Stream<SyncFailure> get failures => _failures.stream;

  void register(String type, OpExecutor executor) {
    _executors[type] = executor;
  }

  /// Laedt den gespeicherten Stand. Mehrfach-Aufrufe sind harmlos.
  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await store.readJson(_storeKey);
      if (raw is Map) {
        final storedTemp = (raw['nextTempId'] as num?)?.toInt();
        // Nie hinter einen bereits vergebenen Wert zurueckfallen.
        if (storedTemp != null && storedTemp < _nextTempId) {
          _nextTempId = storedTemp;
        }
        _nextSeq = (raw['nextSeq'] as num?)?.toInt() ?? _nextSeq;
        final ops = raw['ops'];
        if (ops is List) {
          for (final entry in ops) {
            _ops.add(PendingOp.fromJson(Map<String, dynamic>.from(entry as Map)));
          }
        }
        final ids = raw['idMap'];
        if (ids is Map) {
          ids.forEach((key, value) {
            if (value is num) _idMap[key.toString()] = value.toInt();
          });
        }
      }
    } catch (e) {
      print('[SyncQueue] Gespeicherte Warteschlange nicht lesbar: $e');
      _ops.clear();
    }
    _loaded = true;
    _loading = null;
    pending.value = _ops.length;
  }

  void _persist() {
    // LocalStore serialisiert sofort und schreibt der Reihe nach - kein await noetig.
    store.writeJson(_storeKey, {
      'nextTempId': _nextTempId,
      'nextSeq': _nextSeq,
      'ops': _ops.map((op) => op.toJson()).toList(),
      'idMap': _idMap,
    });
  }

  void _changed() {
    pending.value = _ops.length;
    _persist();
  }

  // --- vorlaeufige IDs ------------------------------------------------------

  /// Neue vorlaeufige (negative) ID fuer einen lokal angelegten Eintrag.
  int newTempId() {
    final id = _nextTempId--;
    _persist();
    return id;
  }

  static bool isTempId(int id) => id < 0;

  /// Uebersetzt eine vorlaeufige ID in die echte, sofern schon bekannt.
  /// Echte IDs kommen unveraendert zurueck.
  int resolve(String kind, int id) {
    if (id >= 0) return id;
    return _idMap['$kind:$id'] ?? id;
  }

  void mapId(String kind, int tempId, int realId) {
    _idMap['$kind:$tempId'] = realId;
    while (_idMap.length > _maxIdMappings) {
      _idMap.remove(_idMap.keys.first);
    }
    _persist();
  }

  // --- Schlange -------------------------------------------------------------

  /// Haengt eine Aenderung an und stoesst die Uebertragung an. Kehrt sofort
  /// zurueck - gewartet wird auf das Netz nie.
  void enqueue(String type, Map<String, dynamic> data) {
    _ops.add(PendingOp(seq: _nextSeq++, type: type, data: data));
    _changed();
    unawaited(flush());
  }

  /// Uebertraegt alle wartenden Aenderungen.
  ///
  /// Liefert true, wenn die Schlange danach leer ist - erst dann stimmt der
  /// Serverstand mit dem lokalen ueberein. Wirft nie.
  Future<bool> flush() {
    final running = _running;
    if (running != null) return running;
    final future = _run();
    _running = future;
    return future;
  }

  Future<bool> _run() async {
    try {
      await load();

      while (_ops.isNotEmpty) {
        final op = _ops.first;
        final executor = _executors[op.type];
        if (executor == null) {
          // Kein Handler angemeldet ist ein Verdrahtungsfehler, keine Absage
          // des Servers - die Aenderung bleibt liegen statt verloren zu gehen.
          print('[SyncQueue] Kein Handler fuer "${op.type}" - bleibt in der Schlange');
          return false;
        }

        Object? failure;
        try {
          await executor(op);
        } catch (e) {
          failure = e;
        }

        // Waehrend des Requests kann die Schlange geleert worden sein (Logout).
        if (_ops.isEmpty || !identical(_ops.first, op)) continue;

        if (failure == null) {
          _ops.removeAt(0);
          _changed();
          continue;
        }

        if (_shouldRetryLater(failure, op)) {
          _persist(); // attempts merken
          return false;
        }

        print('[SyncQueue] ${op.type} endgueltig fehlgeschlagen, verworfen: '
            '${_describe(failure)}');
        _ops.removeAt(0);
        _changed();
        if (!_failures.isClosed) _failures.add(SyncFailure(op, failure));
      }

      return true;
    } catch (e) {
      print('[SyncQueue] Unerwarteter Fehler: $e');
      return false;
    } finally {
      // Kein await zwischen der letzten Pruefung von _ops und diesem Punkt:
      // ein enqueue() kann sich hier nicht "dazwischenschieben".
      _running = null;
    }
  }

  static String _describe(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      return code != null ? 'HTTP $code' : error.type.name;
    }
    return error.toString();
  }

  /// true = Eintrag behalten und spaeter erneut versuchen.
  bool _shouldRetryLater(Object error, PendingOp op) {
    if (isConnectivityFailure(error)) return true;

    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == null) {
        // Weder Antwort noch Netzwerkfehler (z.B. abgebrochen). Begrenzt
        // wiederholen, damit ein kaputter Eintrag nicht ewig blockiert.
        return ++op.attempts < maxServerErrorAttempts;
      }
      // 401: Session wird gerade erneuert bzw. der Nutzer muss sich neu
      // anmelden - die Aenderung soll dabei nicht verloren gehen.
      if (code == 401 || code == 408 || code == 425 || code == 429) return true;
      if (code >= 500) return ++op.attempts < maxServerErrorAttempts;
      return false; // 4xx: der Server lehnt endgueltig ab (z.B. Liste geloescht)
    }

    if (error is SocketException || error is TimeoutException) return true;
    return false; // z.B. nicht aufloesbare vorlaeufige ID
  }

  /// Verwirft alles (Logout / anderer Nutzer).
  ///
  /// Der Zaehler fuer vorlaeufige IDs laeuft absichtlich weiter: so kann eine
  /// noch laufende Uebertragung der alten Sitzung nie eine ID-Zuordnung
  /// hinterlassen, die zu einer neuen vorlaeufigen ID passt.
  void reset() {
    _ops.clear();
    _idMap.clear();
    _loaded = true;
    _changed();
  }

  void dispose() {
    _failures.close();
    pending.dispose();
  }
}
