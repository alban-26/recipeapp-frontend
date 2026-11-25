import 'domain/Product.dart';
import 'domain/ProductOrderStrategy.dart';
import 'domain/ShoppingItem.dart';
import 'domain/ShoppingList.dart';

/// Reine Funktionen, die eine Einkaufsliste lokal genauso veraendern, wie es
/// der Server tun wuerde. Damit sieht die Liste offline sofort richtig aus,
/// und nach dem Synchronisieren aendert sich nichts mehr.

/// Stabiles Sortieren. List.sort() garantiert bei gleichen Schluesseln keine
/// Reihenfolge - bei mehr als 32 Eintraegen wuerfelt es sie tatsaechlich
/// durcheinander.
List<T> _stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = <MapEntry<int, T>>[
    for (var i = 0; i < items.length; i++) MapEntry(i, items[i]),
  ];
  indexed.sort((a, b) {
    final result = compare(a.value, b.value);
    return result != 0 ? result : a.key.compareTo(b.key);
  });
  return [for (final entry in indexed) entry.value];
}

/// Reihenfolge nach Rang - die Basis fuer das Umsortieren per Drag & Drop
/// (der Server rechnet mit genau diesen Positionen).
List<ShoppingItem> byRank(List<ShoppingItem> items) =>
    _stableSorted<ShoppingItem>(items, (a, b) => a.rank.compareTo(b.rank));

/// Reihenfolge, in der der Server die Eintraege ausliefert.
List<ShoppingItem> inServerOrder(
  List<ShoppingItem> items,
  ProductOrderStrategy strategy,
) {
  if (strategy == ProductOrderStrategy.COMMON_ORDER) {
    return _stableSorted<ShoppingItem>(items, (a, b) {
      final byCategory = a.product.category.storeRank
          .compareTo(b.product.category.storeRank);
      return byCategory != 0 ? byCategory : a.rank.compareTo(b.rank);
    });
  }
  return byRank(items);
}

/// Reihenfolge auf dem Bildschirm: offene Eintraege zuerst, abgehakte darunter;
/// innerhalb beider Gruppen bleibt die Reihenfolge erhalten.
List<ShoppingItem> inDisplayOrder(List<ShoppingItem> items) => [
      ...items.where((i) => !i.checked),
      ...items.where((i) => i.checked),
    ];

ShoppingList _withItems(ShoppingList list, List<ShoppingItem> items) =>
    list.copyWith(shoppingItems: inServerOrder(items, list.orderStrategy));

/// Naechster freier Rang (neue Eintraege landen am Ende).
int nextRank(List<ShoppingItem> items) {
  var max = -1;
  for (final item in items) {
    if (item.rank > max) max = item.rank;
  }
  return max + 1;
}

ShoppingList withItemAdded(ShoppingList list, ShoppingItem item) =>
    _withItems(list, [...list.shoppingItems, item]);

/// Ersetzt den Eintrag mit derselben ID. Unbekannte IDs aendern nichts.
ShoppingList withItemUpdated(ShoppingList list, ShoppingItem item) =>
    _withItems(list, [
      for (final existing in list.shoppingItems)
        existing.id == item.id ? item : existing,
    ]);

ShoppingList withItemRemoved(ShoppingList list, int itemId) =>
    list.copyWith(
      shoppingItems:
          list.shoppingItems.where((i) => i.id != itemId).toList(),
    );

/// Verschiebt einen Eintrag. [fromIndex] und [toIndex] beziehen sich auf die
/// nach Rang sortierte Liste - genau wie beim Server-Endpunkt /reorder.
/// Wie dort gilt danach wieder die manuelle Reihenfolge (STANDARD).
ShoppingList withItemMoved(ShoppingList list, int fromIndex, int toIndex) {
  final ordered = byRank(list.shoppingItems);
  if (fromIndex < 0 ||
      toIndex < 0 ||
      fromIndex >= ordered.length ||
      toIndex >= ordered.length ||
      fromIndex == toIndex) {
    return list;
  }
  final moved = ordered.removeAt(fromIndex);
  ordered.insert(toIndex, moved);
  return list.copyWith(
    orderStrategy: ProductOrderStrategy.STANDARD,
    shoppingItems: [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(rank: i),
    ],
  );
}

/// "Nach Beliebtheit sortieren": Raenge in Laden-Reihenfolge neu vergeben.
ShoppingList withCommonOrder(ShoppingList list) {
  final sorted = inServerOrder(
    list.shoppingItems,
    ProductOrderStrategy.COMMON_ORDER,
  );
  return _withItems(list, [
    for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(rank: i),
  ]);
}

/// Titel und Sortierstrategie uebernehmen; die Eintraege bleiben, werden aber
/// passend zur Strategie angeordnet.
ShoppingList withMeta(
  ShoppingList list, {
  required String title,
  required ProductOrderStrategy orderStrategy,
}) {
  final updated = list.copyWith(title: title, orderStrategy: orderStrategy);
  return _withItems(updated, updated.shoppingItems);
}

/// Uebersetzt Positionen aus der Bildschirm-Reihenfolge in Positionen der
/// Rang-Reihenfolge. Null, wenn nichts zu verschieben ist.
///
/// Noetig, weil abgehakte Eintraege auf dem Bildschirm nach unten rutschen,
/// im Rang aber irgendwo dazwischen stehen koennen.
List<int>? displayMoveToRankMove(
  List<ShoppingItem> items,
  int fromDisplayIndex,
  int toDisplayIndex,
) {
  final display = inDisplayOrder(items);
  if (fromDisplayIndex < 0 ||
      toDisplayIndex < 0 ||
      fromDisplayIndex >= display.length ||
      toDisplayIndex >= display.length ||
      fromDisplayIndex == toDisplayIndex) {
    return null;
  }
  final ranked = byRank(items);
  final from = ranked.indexWhere((i) => i.id == display[fromDisplayIndex].id);
  final to = ranked.indexWhere((i) => i.id == display[toDisplayIndex].id);
  if (from < 0 || to < 0 || from == to) return null;
  return [from, to];
}
