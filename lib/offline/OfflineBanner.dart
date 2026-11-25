import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ConnectionStatus.dart';
import 'SyncQueue.dart';
import 'SyncScheduler.dart';

/// Schmaler Hinweis, wenn die App ohne Verbindung arbeitet oder Aenderungen
/// noch nicht beim Server angekommen sind. Antippen = jetzt erneut versuchen.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  /// Online wartet eine Aenderung normalerweise nur Millisekunden - dafuer
  /// soll nichts aufblitzen. Erst wenn sie laenger liegt, wird sie gemeldet.
  static const _pendingGrace = Duration(seconds: 3);

  late final ConnectionStatus _status;
  late final SyncQueue _queue;

  Timer? _graceTimer;
  bool _pendingTooLong = false;

  @override
  void initState() {
    super.initState();
    _status = context.read<ConnectionStatus>();
    _queue = context.read<SyncQueue>();
    _status.offline.addListener(_onChanged);
    _queue.pending.addListener(_onChanged);
    _trackPending();
  }

  @override
  void dispose() {
    _status.offline.removeListener(_onChanged);
    _queue.pending.removeListener(_onChanged);
    _graceTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _trackPending();
    if (mounted) setState(() {});
  }

  void _trackPending() {
    if (_queue.pendingCount == 0) {
      _graceTimer?.cancel();
      _graceTimer = null;
      _pendingTooLong = false;
    } else if (!_pendingTooLong && _graceTimer == null) {
      _graceTimer = Timer(_pendingGrace, () {
        _graceTimer = null;
        if (!mounted || _queue.pendingCount == 0) return;
        setState(() => _pendingTooLong = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = _status.isOffline;
    final pending = _queue.pendingCount;

    final String? text;
    if (offline) {
      text = pending == 0
          ? 'Offline – gespeicherte Daten werden angezeigt'
          : pending == 1
              ? 'Offline – 1 Änderung wird nachgereicht'
              : 'Offline – $pending Änderungen werden nachgereicht';
    } else if (pending > 0 && _pendingTooLong) {
      text = pending == 1
          ? '1 Änderung noch nicht übertragen'
          : '$pending Änderungen noch nicht übertragen';
    } else {
      text = null;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: Colors.grey.shade800,
              child: InkWell(
                onTap: () => context.read<SyncScheduler>().syncNow(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        offline ? Icons.cloud_off : Icons.sync_problem,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
