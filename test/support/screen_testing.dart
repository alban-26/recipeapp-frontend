import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gemeinsame Vorbereitung für Tests, die ganze Bildschirme aufbauen.
void setUpScreenTests() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Die Titelzeile nutzt eine Google-Schrift; im Test gibt es kein Netz.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Das Wakelock-Plugin (Auge in der Titelzeile) gibt es im Test nicht.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });
}

/// Wie [testWidgets], ignoriert aber genau einen Fehler: dass google_fonts die
/// Schrift der Titelzeile nicht laden kann. Je nach Version des Pakets wird
/// das nur gemeldet oder als Fehler geworfen - mit dem Test hat es nichts zu
/// tun. Alles andere lässt den Test wie gewohnt scheitern.
void testScreen(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    final outer = Zone.current;
    await runZonedGuarded(() => body(tester), (error, stack) {
      if (error.toString().contains('allowRuntimeFetching')) return;
      outer.handleUncaughtError(error, stack);
    });
  });
}
