import 'dart:async';

import 'package:flutter/widgets.dart';

import 'ConnectionStatus.dart';
import 'SyncQueue.dart';

/// Sorgt dafuer, dass wartende Aenderungen auch dann beim Server ankommen,
/// wenn der Nutzer gerade nichts tut: beim Start, wenn die App wieder in den
/// Vordergrund kommt, und alle 30 Sekunden, solange etwas wartet oder die
/// Verbindung fehlt.
class SyncScheduler with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 30);

  final SyncQueue queue;
  final ConnectionStatus status;

  /// Nur mit gueltiger Anmeldung wird ueberhaupt etwas geschickt.
  final Future<bool> Function() hasSession;

  /// Billiger Request, an dem sich zeigt, ob der Server wieder erreichbar ist.
  final Future<void> Function() probe;

  Timer? _timer;
  bool _busy = false;

  SyncScheduler({
    required this.queue,
    required this.status,
    required this.hasSession,
    required this.probe,
  });

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer ??= Timer.periodic(_interval, (_) => _run());
    _run();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _run();
  }

  /// Sofort versuchen (z.B. wenn der Nutzer auf den Offline-Hinweis tippt).
  Future<void> syncNow() => _run(force: true);

  Future<void> _run({bool force = false}) async {
    if (_busy) return;
    if (!force && !status.isOffline && queue.pendingCount == 0) return;

    _busy = true;
    try {
      if (!await hasSession()) return;

      if (queue.pendingCount > 0) {
        // Der Versuch selbst zeigt, ob die Verbindung wieder da ist.
        await queue.flush();
      } else {
        await probe();
      }
    } catch (e) {
      print('[SyncScheduler] $e');
    } finally {
      _busy = false;
    }
  }
}
