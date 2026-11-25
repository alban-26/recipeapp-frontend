import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../shopping/domain/Unit.dart';
import '../domain/CookingInstruction.dart';
import '../domain/Recipe.dart';
import '../domain/RecipeIngredient.dart';

/// Ein aus einer Webseite gelesenes Rezept, bevor der Nutzer es prueft.
class RecipeWebDraft {
  final Recipe recipe;

  /// Adresse des Rezeptbilds, falls die Seite eins nennt.
  final Uri? imageUrl;

  const RecipeWebDraft({required this.recipe, this.imageUrl});
}

/// Liest Rezepte aus Webseiten.
///
/// Grundlage sind die strukturierten Rezeptdaten nach schema.org, die viele
/// Rezeptseiten fuer Suchmaschinen in die Seite einbetten
/// (`<script type="application/ld+json">` mit `"@type": "Recipe"`).
/// Ohne diese Daten gibt es kein Ergebnis - geraten wird nichts.
class RecipeWebParser {
  RecipeWebParser._();

  static const _uuid = Uuid();
  static const _defaultPortions = 4;
  static const _maxTags = 6;

  /// Das erste Rezept der Seite oder null.
  static RecipeWebDraft? parse(String html, Uri pageUrl) {
    for (final data in _jsonLdBlocks(html)) {
      final node = _findRecipe(data, 0);
      if (node != null) {
        // Bilder stehen oft nur als Verweis da ("@id": ".../#primaryimage").
        final byId = <String, Map<String, dynamic>>{};
        _indexIds(data, byId, 0);
        return _toDraft(node, pageUrl, byId, _metaImage(html));
      }
    }
    return null;
  }

  static void _indexIds(dynamic node, Map<String, Map<String, dynamic>> index, int depth) {
    if (depth > 12) return;
    if (node is Map) {
      final map = node.map((key, value) => MapEntry(key.toString(), value));
      final id = map['@id'];
      if (id is String && (map.containsKey('url') || map.containsKey('contentUrl'))) {
        index.putIfAbsent(id, () => map);
      }
      for (final value in map.values) {
        _indexIds(value, index, depth + 1);
      }
    } else if (node is List) {
      for (final item in node) {
        _indexIds(item, index, depth + 1);
      }
    }
  }

  /// Vorschaubild der Seite (og:image) als Ersatz, wenn das Rezept keins nennt.
  static String? _metaImage(String html) {
    for (final tag in RegExp(r'<meta\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final text = tag.group(0)!;
      final isImage = RegExp(
        r'''(?:property|name)\s*=\s*["']?(?:og:image|og:image:url|twitter:image)["'\s>/]''',
        caseSensitive: false,
      ).hasMatch(text);
      if (!isImage) continue;
      final content = RegExp('content\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')', caseSensitive: false)
          .firstMatch(text);
      final value = content?.group(1) ?? content?.group(2);
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // JSON-LD finden
  // ---------------------------------------------------------------------------

  static final _scriptPattern = RegExp(
    r'''<script\b[^>]*\btype\s*=\s*["']?application/ld\+json["']?[^>]*>([\s\S]*?)</script\s*>''',
    caseSensitive: false,
  );

  static Iterable<dynamic> _jsonLdBlocks(String html) sync* {
    for (final match in _scriptPattern.allMatches(html)) {
      final decoded = _decodeJsonLenient(match.group(1) ?? '');
      if (decoded != null) yield decoded;
    }
  }

  /// Viele Seiten liefern leicht kaputtes JSON (HTML-Kommentare, Zeilenumbrueche
  /// in Texten, Komma am Ende). Erst streng, dann mit Ausbesserungen.
  static dynamic _decodeJsonLenient(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      // weiter unten ausbessern
    }
    var repaired = text
        .replaceAll(RegExp(r'^\s*<!--'), '')
        .replaceAll(RegExp(r'-->\s*$'), '')
        .replaceAll('/*<![CDATA[*/', '')
        .replaceAll('/*]]>*/', '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    repaired = repaired.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);
    try {
      return jsonDecode(repaired);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? _findRecipe(dynamic node, int depth) {
    if (depth > 12) return null;
    if (node is Map) {
      final map = node.map((key, value) => MapEntry(key.toString(), value));
      if (_hasType(map, 'recipe')) return map;
      for (final value in map.values) {
        final found = _findRecipe(value, depth + 1);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findRecipe(item, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// "Recipe", "schema:Recipe", "http://schema.org/Recipe", ["Recipe", "NewsArticle"].
  static bool _hasType(Map<String, dynamic> node, String wanted) {
    final type = node['@type'];
    final types = type is List ? type : [type];
    for (final t in types) {
      if (t is! String) continue;
      final simple = t.split('/').last.split(':').last.trim().toLowerCase();
      if (simple == wanted) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Rezept zusammensetzen
  // ---------------------------------------------------------------------------

  static RecipeWebDraft _toDraft(Map<String, dynamic> node, Uri pageUrl,
      Map<String, Map<String, dynamic>> byId, String? metaImage) {
    final ingredients = _textList(node['recipeIngredient'] ?? node['ingredients'])
        .map(parseIngredientLine)
        .whereType<RecipeIngredient>()
        .toList();

    final steps = _instructions(node['recipeInstructions']);

    final recipe = Recipe(
      id: 0,
      name: _text(node['name']) ?? _text(node['headline']) ?? '',
      recipeIngredients: ingredients,
      cookingInstructions: assignIngredientsToSteps(steps, ingredients),
      portions: _portions(node['recipeYield'] ?? node['yield']) ?? _defaultPortions,
      duration: _totalDuration(node) ?? Duration.zero,
      tags: _tags(node),
    );

    final imageUrl = _imageUrl(node['image'] ?? node['thumbnailUrl'], pageUrl, byId) ??
        (metaImage == null ? null : _imageUrl(metaImage, pageUrl, byId));
    return RecipeWebDraft(recipe: recipe, imageUrl: imageUrl);
  }

  // ---------------------------------------------------------------------------
  // Texte
  // ---------------------------------------------------------------------------

  static String? _text(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final cleaned = cleanText(value);
      return cleaned.isEmpty ? null : cleaned;
    }
    if (value is num) return value.toString();
    if (value is Map) {
      return _text(value['@value']) ?? _text(value['text']) ?? _text(value['name']);
    }
    if (value is List) {
      for (final item in value) {
        final text = _text(item);
        if (text != null) return text;
      }
    }
    return null;
  }

  static List<String> _textList(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      return _splitLines(value);
    }
    if (value is List) {
      return value.map(_text).whereType<String>().toList();
    }
    final single = _text(value);
    return single == null ? const [] : [single];
  }

  static List<String> _splitLines(String value) {
    final withBreaks = value
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*(p|li|div|h\d)\s*>', caseSensitive: false), '\n');
    return withBreaks
        .split(RegExp(r'[\r\n]+'))
        .map(cleanText)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// HTML-Entitaeten aufloesen, Tags entfernen, Leerraum zusammenfassen.
  static String cleanText(String input) {
    var text = input;
    // Manche Seiten kodieren doppelt ("&amp;#39;").
    for (var i = 0; i < 2 && text.contains('&'); i++) {
      text = _decodeEntities(text);
    }
    return text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('­', '') // weiches Trennzeichen
        .replaceAll(RegExp(r'[\s   ]+'), ' ')
        .trim();
  }

  static const _namedEntities = <String, String>{
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
    'nbsp': ' ', 'shy': '', 'thinsp': ' ', 'ensp': ' ', 'emsp': ' ',
    'auml': 'ä', 'ouml': 'ö', 'uuml': 'ü', 'Auml': 'Ä', 'Ouml': 'Ö', 'Uuml': 'Ü',
    'szlig': 'ß', 'eacute': 'é', 'egrave': 'è', 'ecirc': 'ê', 'Eacute': 'É',
    'agrave': 'à', 'aacute': 'á', 'acirc': 'â', 'ccedil': 'ç', 'ntilde': 'ñ',
    'oacute': 'ó', 'ocirc': 'ô', 'iacute': 'í', 'uacute': 'ú', 'oslash': 'ø',
    'aring': 'å', 'aelig': 'æ',
    'frac12': '½', 'frac14': '¼', 'frac34': '¾', 'frac13': '⅓', 'frac23': '⅔',
    'frac18': '⅛', 'deg': '°', 'times': '×', 'middot': '·', 'hellip': '…',
    'ndash': '–', 'mdash': '—', 'lsquo': '‘', 'rsquo': '’', 'sbquo': '‚',
    'ldquo': '“', 'rdquo': '”', 'bdquo': '„', 'laquo': '«', 'raquo': '»',
    'copy': '©', 'reg': '®', 'trade': '™', 'euro': '€',
  };

  static String _decodeEntities(String text) {
    return text.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]*);'),
      (m) {
        final entity = m.group(1)!;
        if (entity.startsWith('#x') || entity.startsWith('#X')) {
          final code = int.tryParse(entity.substring(2), radix: 16);
          return code == null ? m.group(0)! : _charFromCode(code, m.group(0)!);
        }
        if (entity.startsWith('#')) {
          final code = int.tryParse(entity.substring(1));
          return code == null ? m.group(0)! : _charFromCode(code, m.group(0)!);
        }
        return _namedEntities[entity] ?? m.group(0)!;
      },
    );
  }

  static String _charFromCode(int code, String fallback) {
    if (code <= 0 || code > 0x10FFFF) return fallback;
    return String.fromCharCode(code);
  }

  // ---------------------------------------------------------------------------
  // Zubereitung
  // ---------------------------------------------------------------------------

  static List<String> _instructions(dynamic value) {
    final steps = <String>[];
    String? pendingSection;

    void add(String text) {
      var step = text.trim();
      if (step.isEmpty) return;
      if (pendingSection != null) {
        step = '$pendingSection: $step';
        pendingSection = null;
      }
      if (steps.isEmpty || steps.last != step) steps.add(step);
    }

    void visit(dynamic node, int depth) {
      if (node == null || depth > 8) return;
      if (node is String) {
        _splitLines(node).forEach(add);
      } else if (node is List) {
        for (final item in node) {
          visit(item, depth + 1);
        }
      } else if (node is Map) {
        final map = node.map((key, value) => MapEntry(key.toString(), value));
        final children = map['itemListElement'];
        if (_hasType(map, 'howtosection') || _hasType(map, 'itemlist') ||
            (children != null && map['text'] == null)) {
          final name = _text(map['name']);
          final before = steps.length;
          pendingSection = name;
          visit(children, depth + 1);
          // Abschnitt ohne Schritte: Ueberschrift nicht an den naechsten haengen.
          if (steps.length == before) pendingSection = null;
          return;
        }
        final text = _textOfStep(map);
        if (text != null) add(text);
        if (children != null) visit(children, depth + 1);
      }
    }

    visit(value, 0);
    return steps;
  }

  static String? _textOfStep(Map<String, dynamic> step) {
    final raw = step['text'] ?? step['description'] ?? step['name'];
    if (raw is String) {
      final lines = _splitLines(raw);
      return lines.isEmpty ? null : lines.join(' ');
    }
    return _text(raw);
  }

  // ---------------------------------------------------------------------------
  // Zutaten
  // ---------------------------------------------------------------------------

  /// Einheiten, wie sie in Rezepten geschrieben werden -> Einheit der App.
  /// Laengere Schreibweisen zuerst, damit "Esslöffel" nicht als "E" endet.
  static final List<MapEntry<String, Unit>> _unitAliases = () {
    final aliases = <String, Unit>{
      // Gewicht
      'g': Unit.gram, 'gr': Unit.gram, 'gramm': Unit.gram, 'gram': Unit.gram,
      'grams': Unit.gram, 'grammes': Unit.gram,
      'kg': Unit.kilogram, 'kilo': Unit.kilogram, 'kilogramm': Unit.kilogram,
      'kilogram': Unit.kilogram, 'kilograms': Unit.kilogram,
      'mg': Unit.milligram, 'milligramm': Unit.milligram,
      'µg': Unit.microgram, 'mcg': Unit.microgram,
      'lb': Unit.pound, 'lbs': Unit.pound, 'pound': Unit.pound, 'pounds': Unit.pound,
      'oz': Unit.ounce, 'ounce': Unit.ounce, 'ounces': Unit.ounce,
      // Volumen
      'ml': Unit.milliliter, 'milliliter': Unit.milliliter, 'millilitre': Unit.milliliter,
      'l': Unit.liter, 'liter': Unit.liter, 'litre': Unit.liter, 'liters': Unit.liter,
      'litres': Unit.liter, 'ltr': Unit.liter,
      'cl': Unit.centiliter, 'zentiliter': Unit.centiliter,
      'dl': Unit.deciliter, 'deziliter': Unit.deciliter,
      'fl oz': Unit.fluidOunce, 'fl. oz': Unit.fluidOunce, 'fl.oz': Unit.fluidOunce,
      'pint': Unit.pint, 'pints': Unit.pint, 'pt': Unit.pint,
      'quart': Unit.quart, 'quarts': Unit.quart, 'qt': Unit.quart,
      'gallon': Unit.gallon, 'gallons': Unit.gallon, 'gal': Unit.gallon,
      // Kuechenmasse
      'tl': Unit.teaspoon, 'teelöffel': Unit.teaspoon, 'teeloeffel': Unit.teaspoon,
      'tsp': Unit.teaspoon, 'teaspoon': Unit.teaspoon, 'teaspoons': Unit.teaspoon,
      'el': Unit.tablespoon, 'esslöffel': Unit.tablespoon, 'eßlöffel': Unit.tablespoon,
      'essloeffel': Unit.tablespoon, 'tbsp': Unit.tablespoon, 'tbs': Unit.tablespoon,
      'tablespoon': Unit.tablespoon, 'tablespoons': Unit.tablespoon,
      'tasse': Unit.cup, 'tassen': Unit.cup, 'cup': Unit.cup, 'cups': Unit.cup,
      'shot': Unit.shot, 'shots': Unit.shot,
      // Stueck und Teile
      'stück': Unit.piece, 'stk': Unit.piece, 'st': Unit.piece, 'stck': Unit.piece,
      'piece': Unit.piece, 'pieces': Unit.piece, 'pc': Unit.piece, 'pcs': Unit.piece,
      'stange': Unit.piece, 'stangen': Unit.piece, 'kopf': Unit.piece, 'köpfe': Unit.piece,
      'knolle': Unit.piece, 'knollen': Unit.piece,
      'scheibe': Unit.slice, 'scheiben': Unit.slice, 'slice': Unit.slice, 'slices': Unit.slice,
      'blatt': Unit.leaf, 'blätter': Unit.leaf, 'leaf': Unit.leaf, 'leaves': Unit.leaf,
      'zehe': Unit.clove, 'zehen': Unit.clove, 'clove': Unit.clove, 'cloves': Unit.clove,
      'prise': Unit.pinch, 'prisen': Unit.pinch, 'pinch': Unit.pinch, 'pinches': Unit.pinch,
      'msp': Unit.pinch, 'messerspitze': Unit.pinch, 'messerspitzen': Unit.pinch,
      'schuss': Unit.dash, 'spritzer': Unit.dash, 'dash': Unit.dash, 'dashes': Unit.dash,
      'tropfen': Unit.drop, 'drop': Unit.drop, 'drops': Unit.drop,
      // Verpackungen
      'packung': Unit.package, 'packungen': Unit.package, 'pck': Unit.package,
      'pkg': Unit.package, 'pkt': Unit.package, 'päckchen': Unit.package,
      'paket': Unit.package, 'pack': Unit.package, 'package': Unit.package,
      'packages': Unit.package, 'becher': Unit.package, 'beutel': Unit.package,
      'tüte': Unit.package, 'tüten': Unit.package,
      'dose': Unit.can, 'dosen': Unit.can, 'can': Unit.can, 'cans': Unit.can,
      'tin': Unit.can, 'tins': Unit.can,
      'glas': Unit.jar, 'gläser': Unit.jar, 'jar': Unit.jar, 'jars': Unit.jar,
      'bund': Unit.bunch, 'bunch': Unit.bunch, 'bunches': Unit.bunch,
      'zweig': Unit.sprig, 'zweige': Unit.sprig, 'sprig': Unit.sprig, 'sprigs': Unit.sprig,
    };
    final list = aliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    return list;
  }();

  static const _fractions = <String, double>{
    '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75, '⅕': 0.2,
    '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 1 / 6, '⅚': 5 / 6, '⅛': 0.125,
    '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static final String _fractionChars = _fractions.keys.join();

  /// Eine Zahl: "2", "1,5", "1.5", "1/2", "1 1/2", "1½", "½".
  static final String _numberPattern =
      r'(?:\d+\s+\d+\s*[/⁄]\s*\d+|\d+\s*[' + _fractionChars + r']|\d+\s*[/⁄]\s*\d+|\d+(?:[.,]\d+)?|[' + _fractionChars + r'])';

  static final RegExp _quantityPattern = RegExp(
    '^($_numberPattern)(?:\\s*(?:-|–|—|bis|to)\\s*($_numberPattern))?',
    caseSensitive: false,
  );

  static final RegExp _leadingNoise = RegExp(
    r'^(?:[-•*·–]\s*|ca\.?\s+|circa\s+|etwa\s+|ungefähr\s+|approx\.?\s+|about\s+|~\s*)+',
    caseSensitive: false,
  );

  static final RegExp _toTaste = RegExp(
    r'\b(?:nach belieben|nach geschmack|n\.\s?b\.|to taste|as needed|optional)\b\.?',
    caseSensitive: false,
  );

  static double? _parseNumber(String raw) {
    final text = raw.trim();
    final mixed = RegExp(r'^(\d+)\s+(\d+)\s*[/⁄]\s*(\d+)$').firstMatch(text);
    if (mixed != null) {
      final whole = double.parse(mixed.group(1)!);
      final denominator = double.parse(mixed.group(3)!);
      if (denominator == 0) return null;
      return whole + double.parse(mixed.group(2)!) / denominator;
    }
    final glued = RegExp('^(\\d+)\\s*([$_fractionChars])\$').firstMatch(text);
    if (glued != null) {
      return double.parse(glued.group(1)!) + _fractions[glued.group(2)!]!;
    }
    final fraction = RegExp(r'^(\d+)\s*[/⁄]\s*(\d+)$').firstMatch(text);
    if (fraction != null) {
      final denominator = double.parse(fraction.group(2)!);
      if (denominator == 0) return null;
      return double.parse(fraction.group(1)!) / denominator;
    }
    if (_fractions.containsKey(text)) return _fractions[text];
    return double.tryParse(text.replaceAll(',', '.'));
  }

  /// "250 g Mehl" -> 250 / g / Mehl.  "Salz" -> ohne Menge.
  /// Ueberschriften in der Zutatenliste ("Für den Teig:") ergeben null.
  static RecipeIngredient? parseIngredientLine(String line) {
    var rest = cleanText(line).replaceFirst(_leadingNoise, '');
    if (rest.isEmpty || rest.endsWith(':')) return null;

    double? quantity;
    final quantityMatch = _quantityPattern.firstMatch(rest);
    if (quantityMatch != null) {
      final first = _parseNumber(quantityMatch.group(1)!);
      final second = quantityMatch.group(2) == null ? null : _parseNumber(quantityMatch.group(2)!);
      // Bei "2-3 Zwiebeln" lieber genug einkaufen: die obere Grenze.
      quantity = second ?? first;
      rest = rest.substring(quantityMatch.end).trim();
    }

    Unit? unit;
    final lower = rest.toLowerCase();
    for (final alias in _unitAliases) {
      if (!lower.startsWith(alias.key)) continue;
      var end = alias.key.length;
      if (end < rest.length && rest[end] == '.') end++;
      final atBoundary = end >= rest.length || RegExp(r'[\s,;)(]').hasMatch(rest[end]);
      if (!atBoundary) continue;
      unit = alias.value;
      rest = rest.substring(end).trim();
      break;
    }

    var name = _cleanIngredientName(rest);

    // "2 Knoblauchzehen" -> 2 Zehe Knoblauch
    if (unit == null) {
      final clove = RegExp(r'^knoblauchzehe(?:n|\(n\))?$', caseSensitive: false).firstMatch(name);
      if (clove != null) {
        unit = Unit.clove;
        name = 'Knoblauch';
      }
    }

    if (name.isEmpty) return null;

    if (quantity == null && unit != null) quantity = 1; // "Prise Salz"
    final hasAmount = quantity != null && quantity > 0;

    return RecipeIngredient(
      id: _uuid.v4(),
      name: name,
      category: 'OTHER',
      quantity: hasAmount ? quantity : 0,
      // Ohne Menge wird die Einheit nicht angezeigt ("Salz").
      unit: hasAmount ? (unit ?? Unit.piece).label : Unit.gram.label,
    );
  }

  static String _cleanIngredientName(String raw) {
    var name = raw
        .replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '')
        .replaceAll(_toTaste, '')
        // Chefkoch-Schreibweise: "Zwiebel(n)", "Ei(er)"
        .replaceAllMapped(RegExp(r'(\p{L})\((?:n|en|e|s|er|nen)\)', unicode: true), (m) => m.group(1)!)
        // Anmerkungen in Klammern
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');

    // "Zwiebel, fein gehackt" -> "Zwiebel"; ein einzelnes Wort bleibt ("Paprika, rot").
    final comma = name.indexOf(',');
    if (comma >= 0) {
      final after = name.substring(comma + 1).trim();
      final keep = after.isNotEmpty && !after.contains(' ') && after.length <= 15;
      name = keep ? '${name.substring(0, comma).trim()}, $after' : name.substring(0, comma);
    }

    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'^[,;:.\-–\s]+|[,;:\-–\s]+$'), '').trim();
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  // ---------------------------------------------------------------------------
  // Zutaten den Schritten zuordnen
  // ---------------------------------------------------------------------------

  static const _notIdentifying = {
    'frisch', 'frische', 'frischer', 'frisches', 'gross', 'groß', 'grosse', 'große',
    'großer', 'grosser', 'klein', 'kleine', 'kleiner', 'mittelgroß', 'mittelgrosse',
    'mittelgroße', 'rot', 'rote', 'roter', 'gelb', 'gelbe', 'grün', 'grüne', 'weiß',
    'weiss', 'weiße', 'weisse', 'schwarz', 'schwarzer', 'fein', 'gehackt', 'gemahlen',
    'gemahlener', 'getrocknet', 'getrocknete', 'gewürfelt', 'bio', 'tiefgekühlt',
    'type', 'fresh', 'large', 'small', 'medium', 'chopped', 'ground', 'dried', 'whole',
    'und', 'oder', 'and', 'with', 'mit', 'für',
  };

  /// Jede Zutat kommt an den ersten Schritt, der sie erwaehnt. Was nirgends
  /// erwaehnt wird, bleibt frei und laesst sich im Formular zuordnen.
  static List<CookingInstruction> assignIngredientsToSteps(
      List<String> steps, List<RecipeIngredient> ingredients) {
    final assigned = List.generate(steps.length, (_) => <RecipeIngredient>[]);
    final lowerSteps = steps.map((s) => s.toLowerCase()).toList();

    for (final ingredient in ingredients) {
      final tokens = _identifyingTokens(ingredient.name);
      if (tokens.isEmpty) continue;
      for (var i = 0; i < lowerSteps.length; i++) {
        if (tokens.any((t) => _mentions(lowerSteps[i], t))) {
          assigned[i].add(ingredient);
          break;
        }
      }
    }

    return [
      for (var i = 0; i < steps.length; i++)
        CookingInstruction(instruction: steps[i], recipeIngredients: assigned[i]),
    ];
  }

  static Set<String> _identifyingTokens(String name) {
    final tokens = <String>{};
    for (final word in name.toLowerCase().split(RegExp(r'[^\p{L}]+', unicode: true))) {
      if (word.length < 3 || _notIdentifying.contains(word)) continue;
      tokens.add(word);
      final stem = _stem(word);
      if (stem.length >= 4) tokens.add(stem);
    }
    return tokens;
  }

  static String _stem(String word) {
    for (final ending in const ['en', 'er', 'n', 'e', 's']) {
      if (word.endsWith(ending) && word.length - ending.length >= 4) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return word;
  }

  /// Wort beginnt mit dem Token ("zwiebel" in "zwiebeln würfeln"), nicht mitten
  /// im Wort ("ei" in "teig").
  static bool _mentions(String text, String token) {
    return RegExp('(?<!\\p{L})${RegExp.escape(token)}', unicode: true).hasMatch(text);
  }

  // ---------------------------------------------------------------------------
  // Kategorien
  // ---------------------------------------------------------------------------

  /// Kategorie je Zutat anhand der bekannten Zutatenlisten der App
  /// (Kategorie -> Namen). Genauer Treffer zuerst, sonst der laengste bekannte
  /// Name, der im Namen steckt ("Weizenmehl" -> "Mehl"). Sonst OTHER.
  static Recipe categorize(Recipe recipe, Map<String, List<String>> known) {
    if (known.isEmpty) return recipe;

    final byName = <String, String>{};
    for (final entry in known.entries) {
      for (final name in entry.value) {
        byName.putIfAbsent(name.toLowerCase(), () => entry.key);
      }
    }

    String categoryOf(String name) {
      final lower = name.toLowerCase().trim();
      final exact = byName[lower];
      if (exact != null) return exact;
      final words = lower.split(RegExp(r'[^\p{L}]+', unicode: true)).where((w) => w.isNotEmpty).toList();
      final lastWord = words.isEmpty ? '' : words.last;
      String? best;
      for (final candidate in byName.keys) {
        if (candidate.length < 3) continue;
        final hit = words.contains(candidate) ||
            lastWord.endsWith(candidate) ||
            (candidate.contains(' ') && lower.contains(candidate));
        if (hit && (best == null || candidate.length > best.length)) best = candidate;
      }
      return best == null ? 'OTHER' : byName[best]!;
    }

    final updated = <String, RecipeIngredient>{
      for (final ingredient in recipe.recipeIngredients)
        ingredient.id: ingredient.copyWith(productCategory: categoryOf(ingredient.name)),
    };

    return recipe.copyWith(
      recipeIngredients: recipe.recipeIngredients.map((i) => updated[i.id]!).toList(),
      cookingInstructions: recipe.cookingInstructions
          .map((step) => CookingInstruction(
                instruction: step.instruction,
                recipeIngredients: step.recipeIngredients.map((i) => updated[i.id] ?? i).toList(),
              ))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Portionen, Dauer, Tags, Bild
  // ---------------------------------------------------------------------------

  static int? _portions(dynamic value) {
    final candidates = value is List ? value : [value];
    for (final candidate in candidates) {
      if (candidate is num && candidate > 0) return candidate.round();
      if (candidate is String) {
        final match = RegExp(r'\d+').firstMatch(candidate);
        if (match != null) {
          final number = int.parse(match.group(0)!);
          if (number > 0) return number;
        }
      }
    }
    return null;
  }

  static Duration? _totalDuration(Map<String, dynamic> node) {
    final total = parseDuration(node['totalTime']);
    if (total != null && total > Duration.zero) return total;
    var sum = Duration.zero;
    for (final key in const ['prepTime', 'cookTime', 'performTime']) {
      sum += parseDuration(node[key]) ?? Duration.zero;
    }
    return sum > Duration.zero ? sum : null;
  }

  /// "PT1H30M", "P0DT0H45M", "PT90M", zur Not auch "45 Minuten" oder "1 Std.".
  static Duration? parseDuration(dynamic value) {
    if (value is num) return Duration(minutes: value.round());
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;

    final iso = RegExp(
      r'^P(?:(\d+(?:[.,]\d+)?)D)?(?:T(?:(\d+(?:[.,]\d+)?)H)?(?:(\d+(?:[.,]\d+)?)M)?(?:(\d+(?:[.,]\d+)?)S)?)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (iso != null) {
      double part(int group) =>
          double.tryParse((iso.group(group) ?? '0').replaceAll(',', '.')) ?? 0;
      final seconds =
          part(1) * 86400 + part(2) * 3600 + part(3) * 60 + part(4);
      return Duration(seconds: seconds.round());
    }

    var seconds = 0.0;
    var found = false;
    for (final m in RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(stunden|stunde|std|hours|hour|hrs|hr|h|minuten|minute|min|mins|m)\b',
      caseSensitive: false,
    ).allMatches(text)) {
      final number = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      final unit = m.group(2)!.toLowerCase();
      seconds += unit.startsWith('s') || unit.startsWith('h') ? number * 3600 : number * 60;
      found = true;
    }
    return found ? Duration(seconds: seconds.round()) : null;
  }

  static List<String> _tags(Map<String, dynamic> node) {
    final raw = <String>[
      ..._splitTags(node['recipeCategory']),
      ..._splitTags(node['recipeCuisine']),
      ..._splitTags(node['keywords']),
    ];
    final name = (_text(node['name']) ?? '').toLowerCase();
    final tags = <String>[];
    for (final tag in raw) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.length < 2 || normalized.length > 25) continue;
      if (normalized == name || tags.contains(normalized)) continue;
      tags.add(normalized);
      if (tags.length == _maxTags) break;
    }
    return tags;
  }

  static List<String> _splitTags(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.expand(_splitTags).toList();
    final text = _text(value);
    if (text == null) return const [];
    return text.split(RegExp(r'[,;|]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  static Uri? _imageUrl(dynamic value, Uri pageUrl, Map<String, Map<String, dynamic>> byId,
      [int depth = 0]) {
    if (depth > 4) return null;
    if (value == null) return null;
    if (value is String) {
      final trimmed = cleanText(value);
      if (trimmed.isEmpty) return null;
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      final resolved = pageUrl.resolveUri(uri);
      return (resolved.scheme == 'http' || resolved.scheme == 'https') ? resolved : null;
    }
    if (value is List) {
      for (final item in value) {
        final url = _imageUrl(item, pageUrl, byId, depth + 1);
        if (url != null) return url;
      }
      return null;
    }
    if (value is Map) {
      final direct = value['url'] ?? value['contentUrl'];
      if (direct != null) return _imageUrl(direct, pageUrl, byId, depth + 1);
      // Nur ein Verweis: das Bild steht an anderer Stelle der Seitendaten.
      final id = value['@id'];
      final target = id is String ? byId[id] : null;
      if (target != null) {
        return _imageUrl(target['url'] ?? target['contentUrl'], pageUrl, byId, depth + 1);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Link aus geteiltem Text
  // ---------------------------------------------------------------------------

  /// Erster Link in einem geteilten Text ("Schau mal: https://… #lecker").
  static Uri? extractFirstUrl(String text) {
    final match = RegExp(r'''(?:https?://|www\.)[^\s<>"'«»]+''', caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    var candidate = match.group(0)!;
    // Satzzeichen am Ende gehoeren nicht zum Link.
    while (candidate.isNotEmpty && '.,;:!?)]}’”'.contains(candidate[candidate.length - 1])) {
      final last = candidate[candidate.length - 1];
      if (last == ')' && candidate.contains('(')) break;
      candidate = candidate.substring(0, candidate.length - 1);
    }
    if (candidate.toLowerCase().startsWith('www.')) candidate = 'https://$candidate';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }
}
