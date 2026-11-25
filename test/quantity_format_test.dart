import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/common/quantity_format.dart';
import 'package:recipeapp_frontend/shopping/domain/Unit.dart';

void main() {
  group('formatIngredient', () {
    test('die beiden Beispiele aus der Anforderung', () {
      expect(formatIngredient(3, 'Stück', 'Äpfel'), '3 Stück Äpfel');
      expect(formatIngredient(50, 'g', 'Mehl'), '50g Mehl');
    });

    test('Kurzzeichen kleben an der Zahl, Wörter stehen mit Abstand', () {
      expect(formatIngredient(1.5, 'kg', 'Kartoffeln'), '1,5kg Kartoffeln');
      expect(formatIngredient(250, 'ml', 'Milch'), '250ml Milch');
      expect(formatIngredient(0.5, 'l', 'Brühe'), '0,5l Brühe');
      expect(formatIngredient(2, 'EL', 'Öl'), '2 EL Öl');
      expect(formatIngredient(1, 'Prise', 'Salz'), '1 Prise Salz');
      expect(formatIngredient(2, 'fl oz', 'Rum'), '2 fl oz Rum');
    });

    test('versteht auch die Namen aus Code und Server', () {
      // So stand es bisher bei frisch hinzugefügten Einträgen in der Liste.
      expect(formatIngredient(3, 'piece', 'Äpfel'), '3 Stück Äpfel');
      expect(formatIngredient(50, 'gram', 'Mehl'), '50g Mehl');
      expect(formatIngredient(3, 'PIECE', 'Äpfel'), '3 Stück Äpfel');
      expect(formatIngredient(1, 'FLUID_OUNCE', 'Rum'), '1 fl oz Rum');
    });

    test('unbekannte Einheit wird unverändert angezeigt', () {
      expect(formatIngredient(2, 'Handvoll', 'Nüsse'), '2 Handvoll Nüsse');
    });

    test('ohne Menge: kein verwaistes "g", aber "Prise Salz" bleibt', () {
      expect(formatIngredient(0, 'g', 'Salz'), 'Salz');
      expect(formatIngredient(0, 'Prise', 'Salz'), 'Prise Salz');
      expect(formatIngredient(0, '', 'Salz'), 'Salz');
    });

    test('ohne Einheit', () {
      expect(formatIngredient(3, '', 'Eier'), '3 Eier');
    });
  });

  group('formatQuantity', () {
    test('ganze Zahlen ohne Nachkommastelle', () {
      expect(formatQuantity(3), '3');
      expect(formatQuantity(3.0), '3');
      expect(formatQuantity(10), '10');
      expect(formatQuantity(100), '100');
      expect(formatQuantity(1200), '1200');
    });

    test('Dezimalkomma, höchstens zwei Stellen, keine Nullen am Ende', () {
      expect(formatQuantity(0.5), '0,5');
      expect(formatQuantity(1.25), '1,25');
      expect(formatQuantity(2.50), '2,5');
      // Entsteht beim Umrechnen der Portionen (z.B. 4 -> 3 Portionen).
      expect(formatQuantity(1 / 3), '0,33');
      expect(formatQuantity(200 / 3), '66,67');
      expect(formatQuantity(2.999), '3');
    });

    test('sehr kleine Mengen werden nicht zu 0', () {
      expect(formatQuantity(0.004), '0,004');
      expect(formatQuantity(0), '0');
    });
  });

  group('Unit.tryParse', () {
    test('Label, Code-Name und Server-Name', () {
      expect(Unit.tryParse('Stück'), Unit.piece);
      expect(Unit.tryParse('piece'), Unit.piece);
      expect(Unit.tryParse('PIECE'), Unit.piece);
      expect(Unit.tryParse('fl oz'), Unit.fluidOunce);
      expect(Unit.tryParse('fluidOunce'), Unit.fluidOunce);
      expect(Unit.tryParse('FLUID_OUNCE'), Unit.fluidOunce);
      expect(Unit.tryParse('g'), Unit.gram);
      expect(Unit.tryParse('el'), Unit.tablespoon);
    });

    test('Unbekanntes ist null statt stillschweigend Gramm', () {
      expect(Unit.tryParse('Handvoll'), isNull);
      expect(Unit.tryParse(''), isNull);
      expect(Unit.tryParse(null), isNull);
    });

    test('jede Einheit findet über ihr Label und ihren Namen zu sich zurück',
        () {
      for (final unit in Unit.values) {
        expect(Unit.tryParse(unit.label), unit, reason: unit.label);
        expect(Unit.tryParse(unit.name), unit, reason: unit.name);
      }
    });
  });
}
