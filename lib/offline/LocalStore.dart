import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Lokale Ablage fuer den Offline-Modus: JSON-Dokumente (Listen, Rezepte,
/// Warteschlange) und Binaerdaten (Rezeptbilder).
///
/// Bewusst simpel gehalten - eine Datei pro Schluessel. Die Datenmengen einer
/// Rezepte-App sind klein, eine Datenbank waere hier nur eine weitere
/// Abhaengigkeit.
abstract class LocalStore {
  /// Liefert das gespeicherte JSON (Map/List/...) oder null.
  Future<Object?> readJson(String key);

  Future<void> writeJson(String key, Object? value);

  Future<Uint8List?> readBytes(String key);

  Future<void> writeBytes(String key, List<int> bytes);

  Future<bool> hasBytes(String key);

  /// Entfernt JSON und Binaerdaten zu diesem Schluessel.
  Future<void> remove(String key);

  /// Loescht alles (Logout bzw. anderer Nutzer).
  Future<void> clear();

  /// Oeffnet die Ablage im App-Verzeichnis. Scheitert das (z.B. kein
  /// Dateisystem-Plugin), laeuft die App mit einer fluechtigen Ablage weiter -
  /// dann eben ohne Offline-Daten nach einem Neustart, aber ohne Absturz.
  static Future<LocalStore> open() async {
    try {
      final base = await getApplicationSupportDirectory();
      final root = Directory('${base.path}${Platform.pathSeparator}offline_v1');
      await root.create(recursive: true);
      return FileLocalStore(root);
    } catch (e) {
      print('[LocalStore] Kein Dateisystem verfuegbar, Daten nur im Speicher: $e');
      return MemoryLocalStore();
    }
  }
}

/// Dateibasierte Ablage.
class FileLocalStore implements LocalStore {
  final Directory root;

  /// Schreibzugriffe laufen strikt nacheinander, damit zwei schnelle
  /// Aenderungen sich nicht gegenseitig ueberschreiben.
  Future<void> _tail = Future<void>.value();

  FileLocalStore(this.root);

  File _file(String key, String ext) {
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${root.path}${Platform.pathSeparator}$safe.$ext');
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Erst in eine temporaere Datei schreiben, dann umbenennen: stuerzt die App
  /// mitten im Schreiben ab, bleibt die alte Datei intakt.
  ///
  /// Wirft nie: ein voller Speicher darf die App nicht zum Absturz bringen,
  /// im schlimmsten Fall fehlt der Eintrag eben beim naechsten Start.
  Future<void> _writeAtomic(File target, List<int> bytes) async {
    try {
      await root.create(recursive: true);
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
    } catch (e) {
      print('[LocalStore] Schreiben fehlgeschlagen (${target.path}): $e');
    }
  }

  @override
  Future<Object?> readJson(String key) async {
    // Hinter laufenden Schreibvorgaengen einreihen, sonst liest man evtl.
    // einen aelteren Stand.
    return _serialized(() async {
      final file = _file(key, 'json');
      try {
        if (!await file.exists()) return null;
        final text = await file.readAsString();
        if (text.isEmpty) return null;
        return jsonDecode(text);
      } catch (e) {
        print('[LocalStore] $key nicht lesbar, wird verworfen: $e');
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        return null;
      }
    });
  }

  @override
  Future<void> writeJson(String key, Object? value) {
    // Sofort serialisieren: der Aufrufer darf sein Objekt danach weiter
    // veraendern, gespeichert wird der Stand von JETZT.
    final bytes = utf8.encode(jsonEncode(value));
    return _serialized(() => _writeAtomic(_file(key, 'json'), bytes));
  }

  @override
  Future<Uint8List?> readBytes(String key) {
    return _serialized(() async {
      final file = _file(key, 'bin');
      try {
        if (!await file.exists()) return null;
        return await file.readAsBytes();
      } catch (e) {
        print('[LocalStore] $key (bin) nicht lesbar: $e');
        return null;
      }
    });
  }

  @override
  Future<void> writeBytes(String key, List<int> bytes) {
    final copy = Uint8List.fromList(bytes);
    return _serialized(() => _writeAtomic(_file(key, 'bin'), copy));
  }

  @override
  Future<bool> hasBytes(String key) {
    return _serialized(() async {
      try {
        return await _file(key, 'bin').exists();
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Future<void> remove(String key) {
    return _serialized(() async {
      for (final ext in const ['json', 'bin']) {
        final file = _file(key, ext);
        try {
          if (await file.exists()) await file.delete();
        } catch (e) {
          print('[LocalStore] $key.$ext nicht loeschbar: $e');
        }
      }
    });
  }

  @override
  Future<void> clear() {
    return _serialized(() async {
      try {
        if (await root.exists()) await root.delete(recursive: true);
        await root.create(recursive: true);
      } catch (e) {
        print('[LocalStore] Ablage nicht leerbar: $e');
      }
    });
  }
}

/// Fluechtige Ablage - fuer Tests und als Notloesung ohne Dateisystem.
class MemoryLocalStore implements LocalStore {
  final Map<String, String> _json = {};
  final Map<String, Uint8List> _bytes = {};

  @override
  Future<Object?> readJson(String key) async {
    final text = _json[key];
    return text == null ? null : jsonDecode(text);
  }

  @override
  Future<void> writeJson(String key, Object? value) async {
    _json[key] = jsonEncode(value);
  }

  @override
  Future<Uint8List?> readBytes(String key) async => _bytes[key];

  @override
  Future<void> writeBytes(String key, List<int> bytes) async {
    _bytes[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<bool> hasBytes(String key) async => _bytes.containsKey(key);

  @override
  Future<void> remove(String key) async {
    _json.remove(key);
    _bytes.remove(key);
  }

  @override
  Future<void> clear() async {
    _json.clear();
    _bytes.clear();
  }
}
