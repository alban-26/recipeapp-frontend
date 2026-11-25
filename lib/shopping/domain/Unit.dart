enum Unit {
  // Gewicht
  gram("g", compact: true),
  kilogram("kg", compact: true),
  milligram("mg", compact: true),
  microgram("µg", compact: true),
  pound("lb"),
  ounce("oz"),

  // Volumen
  milliliter("ml", compact: true),
  liter("l", compact: true),
  centiliter("cl", compact: true),
  deciliter("dl", compact: true),
  fluidOunce("fl oz"),
  pint("pt"),
  quart("qt"),
  gallon("gal"),

  // Küchenmaße
  teaspoon("TL"),
  tablespoon("EL"),
  cup("Tasse"),
  shot("Shot"),

  // Sonstiges – Stückzahl / Parts
  piece("Stück"),
  slice("Scheibe"),
  leaf("Blatt"),
  clove("Zehe"),
  pinch("Prise"),
  dash("Schuss"),
  drop("Tropfen"),

  // Verpackungen / Gebinde
  package("Packung"),
  can("Dose"),
  jar("Glas"),
  bunch("Bund"),
  sprig("Zweig");

  final String label;

  /// Kurzzeichen, die ohne Leerzeichen direkt an der Zahl stehen ("50g"),
  /// im Gegensatz zu ausgeschriebenen Einheiten ("3 Stück").
  final bool compact;

  const Unit(this.label, {this.compact = false});

  /// String → Enum
  static Unit fromString(String value) {
    return Unit.values.firstWhere(
          (u) => u.label == value,
      orElse: () => Unit.gram, // fallback
    );
  }

  /// Wie [fromString], aber ohne stillen Rueckfall auf Gramm.
  ///
  /// Versteht das Label ("Stück", "g"), den Namen im Code ("piece") und den
  /// Namen auf dem Server ("PIECE", "FLUID_OUNCE").
  static Unit? tryParse(String? value) {
    if (value == null) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;

    for (final u in Unit.values) {
      if (u.label == raw) return u;
    }
    final lower = raw.toLowerCase();
    for (final u in Unit.values) {
      if (u.label.toLowerCase() == lower) return u;
    }
    final normalized = lower.replaceAll('_', '');
    for (final u in Unit.values) {
      if (u.name.toLowerCase() == normalized) return u;
    }
    return null;
  }

  @override
  String toString() => label;
}
