import 'dart:convert';
import 'package:flutter/services.dart';

class IngredientsService {
  /// Nur Lebensmittel
  static const List<String> _foodFiles = [
    'DAIRY',
    'MEAT',
    'FISH',
    'BAKERY',
    'FRUITS',
    'VEGETABLES',
    'BEVERAGES',
    'FROZEN',
    'DRY_GOODS',
    'SWEETS',
    'ORGANIC',
    'VEGAN',
    'SPICES',
  ];

  /// Alle Kategorien (Shopping)
  static const List<String> _shoppingFiles = [
    'DAIRY',
    'MEAT',
    'FISH',
    'BAKERY',
    'FRUITS',
    'VEGETABLES',
    'BEVERAGES',
    'FROZEN',
    'DRY_GOODS',
    'SWEETS',
    'ORGANIC',
    'VEGAN',
    'SPICES',
    'ELECTRONICS',
    'CLOTHING',
    'BOOKS',
    'HOME_AND_KITCHEN',
    'BEAUTY',
    'SPORTS',
    'TOYS',
    'AUTOMOTIVE',
    'OTHER',
  ];

  /// ============================
  /// Lebensmittel laden
  /// ============================
  static Future<Map<String, List<String>>> loadIngredients() async {
    return _loadCategories(_foodFiles);
  }

  /// ============================
  /// Alle Shopping-Items laden
  /// ============================
  static Future<Map<String, List<String>>> loadShoppingItems() async {
    return _loadCategories(_shoppingFiles);
  }

  /// ============================
  /// Zentrale Lade-Logik
  /// ============================
  static Future<Map<String, List<String>>> _loadCategories(
      List<String> categories) async {
    final Map<String, List<String>> result = {};

    try {
      for (final category in categories) {
        final String jsonString =
        await rootBundle.loadString('assets/$category.json');

        final Map<String, dynamic> jsonData =
        json.decode(jsonString) as Map<String, dynamic>;

        jsonData.forEach((key, value) {
          result[key] = List<String>.from(value);
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Kategorien: $e');
    }

    return result;
  }
}
