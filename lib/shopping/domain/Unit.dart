enum Unit {
  // Gewicht
  gram("g"),
  kilogram("kg"),
  milligram("mg"),
  microgram("µg"),
  pound("lb"),
  ounce("oz"),

  // Volumen
  milliliter("ml"),
  liter("l"),
  centiliter("cl"),
  deciliter("dl"),
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

  const Unit(this.label);

  /// String → Enum
  static Unit fromString(String value) {
    return Unit.values.firstWhere(
          (u) => u.label == value,
      orElse: () => Unit.gram, // fallback
    );
  }

  @override
  String toString() => label;
}
