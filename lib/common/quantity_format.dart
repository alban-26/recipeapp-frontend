import '../shopping/domain/Unit.dart';

/// Einheitliche Anzeige von Mengen in der ganzen App:
///
///   3 Stück Äpfel
///   50g Mehl
///   0,5l Milch
///   2 EL Öl
///
/// Kurzzeichen (g, kg, ml, l, ...) stehen direkt an der Zahl, ausgeschriebene
/// Einheiten (Stück, Prise, EL, ...) mit Leerzeichen dahinter.

/// "3", "0,5", "1,33" - ohne ueberfluessige Nachkommastellen, mit Komma.
String formatQuantity(double quantity) {
  if (quantity.isNaN || quantity.isInfinite) return '';

  String trimmed(int decimals) {
    var text = quantity.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    return text;
  }

  var text = trimmed(2);
  // Sehr kleine Mengen (0,005) nicht zu "0" runden.
  if ((text == '0' || text == '-0') && quantity != 0) text = trimmed(3);
  if (text == '-0') text = '0';
  return text.replaceAll('.', ',');
}

/// Menge samt Einheit: "3 Stück", "50g". Leer, wenn es nichts zu sagen gibt.
///
/// [unit] darf das Label ("Stück"), der Name im Code ("piece") oder der Name
/// auf dem Server ("PIECE") sein; Unbekanntes wird unveraendert angezeigt.
String formatAmount(double quantity, String unit) {
  final known = Unit.tryParse(unit);
  final label = known?.label ?? unit.trim();
  final compact = known?.compact ?? false;

  if (quantity <= 0) {
    // Ohne Menge ergibt "g" keinen Sinn, "Prise" dagegen schon ("Prise Salz").
    return compact ? '' : label;
  }

  final number = formatQuantity(quantity);
  if (label.isEmpty) return number;
  return compact ? '$number$label' : '$number $label';
}

/// Komplette Zeile: "3 Stück Äpfel", "50g Mehl".
String formatIngredient(double quantity, String unit, String name) {
  return [formatAmount(quantity, unit), name.trim()]
      .where((part) => part.isNotEmpty)
      .join(' ');
}
