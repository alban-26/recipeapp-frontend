import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nimmt Links entgegen, die aus einer anderen App (Browser, Instagram, ...)
/// mit "Teilen" an diese App geschickt werden.
///
/// Gegenstueck ist MainActivity.kt: Sie haelt einen beim Start geteilten Text
/// bereit ("takeSharedText") und meldet spaeter geteilte Texte sofort
/// ("sharedText").
///
/// [pending] haelt den geteilten Text, bis der Rezept-Bereich ihn abholt -
/// auch ueber eine Anmeldung hinweg, falls die App dafuer erst starten musste.
class SharedRecipeLinks {
  static const channel = MethodChannel('loveyourmeal/share');

  final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  final MethodChannel _channel;

  SharedRecipeLinks({MethodChannel? methodChannel}) : _channel = methodChannel ?? channel;

  /// Einmal beim App-Start aufrufen.
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') _offer(call.arguments);
      return null;
    });
    try {
      _offer(await _channel.invokeMethod<String>('takeSharedText'));
    } on MissingPluginException {
      // Plattform ohne Teilen-Ziel (z. B. iOS, Tests).
    } on PlatformException {
      // Ohne geteilten Text weiter wie gewohnt.
    }
  }

  void _offer(Object? text) {
    if (text is String && text.trim().isNotEmpty) pending.value = text.trim();
  }

  /// Holt den wartenden Text ab; danach ist nichts mehr da.
  String? take() {
    final text = pending.value;
    pending.value = null;
    return text;
  }
}
