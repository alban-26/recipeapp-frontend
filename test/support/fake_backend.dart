import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Stellt den shopping-list-Service im Speicher nach - mit demselben Verhalten
/// wie der echte (aus ShoppingListResource / ShoppingListService /
/// ShoppingListConverterImpl abgelesen), inklusive seiner Eigenheiten:
///  * leere Listen-Abfrage -> 204
///  * Eintrag loeschen, den es nicht gibt -> 500
///  * /reorder rechnet mit Positionen in der nach Rang sortierten Liste
///  * Einheit muss Kurzzeichen oder Enum-Name sein, sonst 400
///
/// Mit [offline] = true scheitert jeder Request wie ohne Netz.
class FakeBackend implements HttpClientAdapter {
  bool offline = false;

  /// Wenn gesetzt: die naechsten Requests, deren "METHODE /pfad" darauf passt,
  /// werden mit diesem Status beantwortet.
  final Map<Pattern, int> forcedStatus = {};

  /// Protokoll aller Requests, die den "Server" erreicht haben.
  final List<String> log = [];

  final Map<int, Map<String, dynamic>> lists = {};
  int _nextListId = 100;
  int _nextItemId = 1000;

  /// Wird vor jeder Antwort abgewartet - damit lassen sich Antworten
  /// gezielt verzoegern.
  Future<void> Function(String request)? beforeRespond;

  // Unit.java: Enum-Name -> Kurzzeichen
  static const _units = <String, String>{
    'GRAM': 'g', 'KILOGRAM': 'kg', 'MILLIGRAM': 'mg', 'MICROGRAM': 'µg',
    'POUND': 'lb', 'OUNCE': 'oz', 'MILLILITER': 'ml', 'LITER': 'l',
    'CENTILITER': 'cl', 'DECILITER': 'dl', 'FLUID_OUNCE': 'fl oz',
    'PINT': 'pt', 'QUART': 'qt', 'GALLON': 'gal', 'TEASPOON': 'TL',
    'TABLESPOON': 'EL', 'CUP': 'Tasse', 'SHOT': 'Shot', 'PIECE': 'Stück',
    'SLICE': 'Scheibe', 'LEAF': 'Blatt', 'CLOVE': 'Zehe', 'PINCH': 'Prise',
    'DASH': 'Schuss', 'DROP': 'Tropfen', 'PACKAGE': 'Packung', 'CAN': 'Dose',
    'JAR': 'Glas', 'BUNCH': 'Bund', 'SPRIG': 'Zweig',
  };

  // ProductCategory.java
  static const _categoryRank = <String, int>{
    'VEGETABLES': 10, 'FRUITS': 20, 'BAKERY': 30, 'MEAT': 40, 'FISH': 50,
    'DAIRY': 60, 'DRY_GOODS': 70, 'SPICES': 80, 'SWEETS': 90,
    'BEVERAGES': 100, 'FROZEN': 110, 'ORGANIC': 120, 'VEGAN': 130,
    'HOME_AND_KITCHEN': 200, 'BEAUTY': 210, 'CLOTHING': 220, 'SPORTS': 230,
    'TOYS': 240, 'BOOKS': 250, 'ELECTRONICS': 260, 'AUTOMOTIVE': 270,
    'OTHER': 999,
  };

  /// Unit.fromAbbreviation: Kurzzeichen oder Enum-Name, ohne Gross/Klein.
  static String? _unitName(Object? raw) {
    if (raw is! String) return null;
    for (final entry in _units.entries) {
      if (entry.value.toLowerCase() == raw.toLowerCase() ||
          entry.key.toLowerCase() == raw.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  // --- Hilfen fuer Tests ----------------------------------------------------

  int seedList(String title, {List<Map<String, dynamic>> items = const []}) {
    final id = _nextListId++;
    lists[id] = {
      'id': id,
      'title': title,
      'orderStrategy': 'STANDARD',
      'createdAt': '2026-01-01',
      'items': <Map<String, dynamic>>[],
    };
    for (final item in items) {
      seedItem(id, item['name'] as String,
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
          unit: item['unit'] as String? ?? 'PIECE',
          category: item['category'] as String? ?? 'OTHER',
          checked: item['checked'] as bool? ?? false);
    }
    return id;
  }

  int seedItem(
    int listId,
    String name, {
    double quantity = 1,
    String unit = 'PIECE',
    String category = 'OTHER',
    bool checked = false,
  }) {
    final items = _items(listId);
    final id = _nextItemId++;
    items.add({
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'checked': checked,
      'rank': items.length,
    });
    return id;
  }

  List<Map<String, dynamic>> _items(int listId) =>
      lists[listId]!['items'] as List<Map<String, dynamic>>;

  /// Namen der Eintraege in der Reihenfolge, wie der Server sie ausliefert.
  List<String> itemNames(int listId) =>
      (_listDto(listId)['shoppingItems'] as List)
          .map((i) => (i as Map)['product']['name'] as String)
          .toList();

  Map<String, dynamic> itemByName(int listId, String name) =>
      _items(listId).firstWhere((i) => i['name'] == name);

  // --- DTOs -----------------------------------------------------------------

  List<Map<String, dynamic>> _sortedBy(
    List<Map<String, dynamic>> items,
    int Function(Map<String, dynamic> a, Map<String, dynamic> b) compare,
  ) {
    // Java-Streams sortieren stabil.
    final indexed = [
      for (var i = 0; i < items.length; i++) MapEntry(i, items[i]),
    ]..sort((a, b) {
        final c = compare(a.value, b.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  int _byRank(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (a['rank'] as int).compareTo(b['rank'] as int);

  int _byCategory(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _categoryRank[a['category']]!.compareTo(_categoryRank[b['category']]!);

  Map<String, dynamic> _itemDto(Map<String, dynamic> item) => {
        'id': item['id'],
        'product': {'name': item['name'], 'category': item['category']},
        'quantity': item['quantity'],
        'unit': _units[item['unit']],
        'checked': item['checked'],
        'rank': item['rank'],
      };

  Map<String, dynamic> _listDto(int id) {
    final list = lists[id]!;
    final items = _items(id);
    final sorted = list['orderStrategy'] == 'COMMON_ORDER'
        ? _sortedBy(items, (a, b) {
            final c = _byCategory(a, b);
            return c != 0 ? c : _byRank(a, b);
          })
        : _sortedBy(items, _byRank);
    return {
      'id': id,
      'title': list['title'],
      'orderStrategy': list['orderStrategy'],
      'shoppingItems': sorted.map(_itemDto).toList(),
      'createdAt': list['createdAt'],
    };
  }

  // --- HTTP -----------------------------------------------------------------

  ResponseBody _json(int status, [Object? body]) {
    if (body == null) {
      return ResponseBody.fromString('', status);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  ResponseBody _error(int status, String message) =>
      _json(status, {'message': message});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final request = '${options.method} $path';

    await Future<void>.delayed(Duration.zero);
    if (offline) {
      throw const SocketException('Network is unreachable');
    }
    await beforeRespond?.call(request);
    if (offline) {
      throw const SocketException('Connection reset');
    }
    log.add(request);

    for (final entry in forcedStatus.entries) {
      if (entry.key.allMatches(request).isNotEmpty) {
        return _error(entry.value, 'forced');
      }
    }

    final data = options.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : null;
    final segments = options.uri.pathSegments;

    if (segments.isEmpty || segments.first != 'shoppingLists') {
      return _error(404, 'Resource not found');
    }

    // /shoppingLists
    if (segments.length == 1) {
      if (options.method == 'GET') {
        if (lists.isEmpty) return _json(204);
        return _json(200, lists.keys.map(_listDto).toList());
      }
      if (options.method == 'POST') {
        final id = _nextListId++;
        lists[id] = {
          'id': id,
          'title': body!['title'],
          'orderStrategy': body['orderStrategy'],
          'createdAt': (body['createdAt'] as String).substring(0, 10),
          'items': <Map<String, dynamic>>[],
        };
        return _json(201, id);
      }
    }

    final listId = int.tryParse(segments[1]);
    final list = lists[listId];

    // /shoppingLists/{id}
    if (segments.length == 2) {
      if (options.method == 'GET') {
        if (list == null) return _error(404, 'Resource not found');
        return _json(200, _listDto(listId!));
      }
      if (options.method == 'DELETE') {
        if (list == null) return _error(404, 'Resource not found');
        lists.remove(listId);
        return _json(204);
      }
      if (options.method == 'PUT') {
        if (list == null) return _error(404, 'Resource not found');
        list['title'] = body!['title'];
        list['orderStrategy'] = body['orderStrategy'];
        list['createdAt'] = (body['createdAt'] as String).substring(0, 10);
        // update(): vorhandene Eintraege aus dem Body ueberschreiben
        for (final raw in body['shoppingItems'] as List) {
          final dto = Map<String, dynamic>.from(raw as Map);
          final unit = _unitName(dto['unit']);
          if (unit == null) return _error(400, 'Invalid input data');
          for (final item in _items(listId!)) {
            if (item['id'] == dto['id']) {
              item['quantity'] = dto['quantity'];
              item['unit'] = unit;
              item['checked'] = dto['checked'];
              item['rank'] = dto['rank'];
            }
          }
        }
        return _json(200, _listDto(listId!));
      }
    }

    // /shoppingLists/{id}/shoppingItems...
    if (segments.length >= 3 && segments[2] == 'shoppingItems') {
      if (segments.length == 3 && options.method == 'POST') {
        if (list == null) return _error(500, 'An unexpected error occurred');
        final unit = _unitName(body!['unit']);
        if (unit == null) return _error(400, 'Invalid input data');
        final id = _nextItemId++;
        final product = Map<String, dynamic>.from(body['product'] as Map);
        _items(listId!).add({
          'id': id,
          'name': product['name'],
          'category': product['category'] ?? 'OTHER',
          'quantity': (body['quantity'] as num).toDouble(),
          'unit': unit,
          'checked': body['checked'] ?? false,
          'rank': body['rank'],
        });
        return _json(201, id);
      }

      if (segments.length == 4 && segments[3] == 'reorder') {
        if (list == null) return _error(500, 'An unexpected error occurred');
        final ordered = _sortedBy(_items(listId!), _byRank);
        final from = body!['fromIndex'] as int;
        final to = body['toIndex'] as int;
        if (from < 0 || to < 0 || from >= ordered.length || to >= ordered.length) {
          return _error(500, 'An unexpected error occurred');
        }
        final moved = ordered.removeAt(from);
        ordered.insert(to, moved);
        for (var i = 0; i < ordered.length; i++) {
          ordered[i]['rank'] = i;
        }
        list['orderStrategy'] = 'STANDARD';
        return _json(200, {});
      }

      if (segments.length == 4 && segments[3] == 'reorderByCommon') {
        if (list == null) return _error(404, 'Resource not found');
        final ordered = _sortedBy(_items(listId!), _byCategory);
        for (var i = 0; i < ordered.length; i++) {
          ordered[i]['rank'] = i;
        }
        return _json(200, {});
      }

      if (segments.length == 4) {
        final itemId = int.tryParse(segments[3]);
        final items = list == null
            ? <Map<String, dynamic>>[]
            : _items(listId!);
        final matches = items.where((i) => i['id'] == itemId).toList();

        if (options.method == 'PATCH') {
          final unit = _unitName(body!['unit']);
          if (unit == null) return _error(400, 'Invalid input data');
          // Wie beim echten Server: trifft das UPDATE nichts, ist es trotzdem 200.
          for (final item in matches) {
            item['quantity'] = (body['quantity'] as num).toDouble();
            item['unit'] = unit;
            item['checked'] = body['checked'];
            item['rank'] = body['rank'];
            final product = body['product'];
            if (product is Map && (product['name'] as String?)?.trim().isNotEmpty == true) {
              item['name'] = product['name'];
              item['category'] = product['category'] ?? 'OTHER';
            }
          }
          return _json(200, body);
        }
        if (options.method == 'DELETE') {
          if (matches.isEmpty) return _error(500, 'An unexpected error occurred');
          items.removeWhere((i) => i['id'] == itemId);
          return _json(204);
        }
      }
    }

    return _error(404, 'Resource not found');
  }

  @override
  void close({bool force = false}) {}
}
