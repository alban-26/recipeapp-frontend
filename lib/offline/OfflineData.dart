import 'LocalStore.dart';
import 'SyncQueue.dart';

/// Wacht darueber, WEM die lokal gespeicherten Daten gehoeren.
///
/// Gespeicherte Listen, Rezepte und wartende Aenderungen duerfen nie bei einem
/// anderen Konto landen. Deshalb wird beim Abmelden alles geloescht - und
/// ebenso, wenn sich jemand anderes anmeldet als der, dem die Daten gehoeren.
class OfflineData {
  static const _ownerKey = 'owner';

  final LocalStore store;
  final SyncQueue queue;

  final List<void Function()> _resetCallbacks = [];

  String? _verifiedOwner;

  OfflineData({required this.store, required this.queue});

  /// true, sobald feststeht, dass die lokalen Daten zum angemeldeten Konto
  /// gehoeren. Vorher darf nichts davon zum Server geschickt werden.
  bool get isReady => _verifiedOwner != null;

  /// Registriert etwas, das beim Loeschen seinen Speicher-Stand verwerfen muss
  /// (die Repositories halten ihre Daten auch im Arbeitsspeicher).
  void onReset(void Function() callback) => _resetCallbacks.add(callback);

  /// Stellt sicher, dass die lokalen Daten zu [userId] gehoeren. Gehoeren sie
  /// jemand anderem (oder niemandem), werden sie verworfen.
  Future<void> ensureOwner(String userId) async {
    if (_verifiedOwner == userId) return;
    final raw = await store.readJson(_ownerKey);
    if (raw is! Map || raw['id'] != userId) {
      await wipe();
      await store.writeJson(_ownerKey, {'id': userId});
    }
    _verifiedOwner = userId;
  }

  /// Loescht alle lokal gespeicherten Daten samt wartender Aenderungen.
  Future<void> wipe() async {
    _verifiedOwner = null;
    queue.reset();
    for (final callback in _resetCallbacks) {
      callback();
    }
    await store.clear();
  }
}
