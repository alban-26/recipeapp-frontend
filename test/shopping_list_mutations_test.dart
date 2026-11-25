import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListMutations.dart';
import 'package:recipeapp_frontend/shopping/domain/Product.dart';
import 'package:recipeapp_frontend/shopping/domain/ProductOrderStrategy.dart';
import 'package:recipeapp_frontend/shopping/domain/ShoppingItem.dart';
import 'package:recipeapp_frontend/shopping/domain/ShoppingList.dart';

ShoppingItem item(
  int id,
  String name, {
  int rank = 0,
  bool checked = false,
  ProductCategory category = ProductCategory.OTHER,
}) =>
    ShoppingItem(
      id: id,
      product: Product(name: name, category: category),
      quantity: 1,
      unit: 'Stück',
      checked: checked,
      rank: rank,
    );

ShoppingList listOf(
  List<ShoppingItem> items, {
  ProductOrderStrategy strategy = ProductOrderStrategy.STANDARD,
}) =>
    ShoppingList(
      id: 1,
      title: 'Wocheneinkauf',
      shoppingItems: items,
      createdAt: DateTime(2026, 1, 1),
      orderStrategy: strategy,
    );

List<String> names(Iterable<ShoppingItem> items) =>
    items.map((i) => i.product.name).toList();

void main() {
  test('Anzeige: offene zuerst, abgehakte darunter, Reihenfolge bleibt', () {
    final items = [
      item(1, 'A', rank: 0, checked: true),
      item(2, 'B', rank: 1),
      item(3, 'C', rank: 2, checked: true),
      item(4, 'D', rank: 3),
    ];
    expect(names(inDisplayOrder(items)), ['B', 'D', 'A', 'C']);
  });

  test('Anzeige bleibt auch bei vielen Einträgen stabil (>32)', () {
    // List.sort() ist ab 33 Elementen nicht mehr stabil - genau daran ist die
    // alte Sortierung gescheitert.
    final items = [
      for (var i = 0; i < 80; i++) item(i, 'P$i', rank: i, checked: i.isOdd),
    ];
    final shown = inDisplayOrder(items);
    expect(shown.take(40).map((i) => i.id), [for (var i = 0; i < 80; i += 2) i]);
    expect(shown.skip(40).map((i) => i.id), [for (var i = 1; i < 80; i += 2) i]);
  });

  group('Verschieben', () {
    // Rang-Reihenfolge: A(abgehakt), B, C, D  ->  Bildschirm: B, C, D, A
    final items = [
      item(1, 'A', rank: 0, checked: true),
      item(2, 'B', rank: 1),
      item(3, 'C', rank: 2),
      item(4, 'D', rank: 3),
    ];

    test('nach oben, an einem abgehakten Eintrag vorbei gerechnet', () {
      // D (Bildschirm-Position 2) vor B (Position 0) ziehen.
      final move = displayMoveToRankMove(items, 2, 0)!;
      final moved = withItemMoved(listOf(items), move[0], move[1]);
      expect(names(inDisplayOrder(moved.shoppingItems)), ['D', 'B', 'C', 'A']);
    });

    test('nach unten', () {
      // B (Position 0) hinter D (Position 2) ziehen.
      final move = displayMoveToRankMove(items, 0, 2)!;
      final moved = withItemMoved(listOf(items), move[0], move[1]);
      expect(names(inDisplayOrder(moved.shoppingItems)), ['C', 'D', 'B', 'A']);
    });

    test('vergibt lückenlose Ränge und schaltet auf manuelle Reihenfolge', () {
      final moved = withItemMoved(
        listOf(items, strategy: ProductOrderStrategy.COMMON_ORDER),
        3,
        1,
      );
      expect(moved.shoppingItems.map((i) => i.rank), [0, 1, 2, 3]);
      expect(names(moved.shoppingItems), ['A', 'D', 'B', 'C']);
      expect(moved.orderStrategy, ProductOrderStrategy.STANDARD);
    });

    test('ungültige oder gleiche Positionen ändern nichts', () {
      expect(displayMoveToRankMove(items, 1, 1), isNull);
      expect(displayMoveToRankMove(items, -1, 2), isNull);
      expect(displayMoveToRankMove(items, 0, 9), isNull);
      final list = listOf(items);
      expect(withItemMoved(list, 0, 9), same(list));
    });
  });

  test('"Nach Beliebtheit": Gemüse vor Milch vor Sonstigem, wie im Laden', () {
    final list = listOf([
      item(1, 'Schrauben', rank: 0),
      item(2, 'Milch', rank: 1, category: ProductCategory.DAIRY),
      item(3, 'Tomaten', rank: 2, category: ProductCategory.VEGETABLES),
      item(4, 'Käse', rank: 3, category: ProductCategory.DAIRY),
    ]);
    final sorted = withCommonOrder(list);
    expect(names(sorted.shoppingItems),
        ['Tomaten', 'Milch', 'Käse', 'Schrauben']);
    expect(sorted.shoppingItems.map((i) => i.rank), [0, 1, 2, 3]);
  });

  test('bei Kategorie-Sortierung landet ein neuer Eintrag in seiner Kategorie',
      () {
    final list = listOf(
      [
        item(3, 'Tomaten', rank: 0, category: ProductCategory.VEGETABLES),
        item(2, 'Milch', rank: 1, category: ProductCategory.DAIRY),
      ],
      strategy: ProductOrderStrategy.COMMON_ORDER,
    );
    final added = withItemAdded(
      list,
      item(9, 'Gurke', rank: 2, category: ProductCategory.VEGETABLES),
    );
    expect(names(added.shoppingItems), ['Tomaten', 'Gurke', 'Milch']);
  });

  test('Bearbeiten ersetzt genau den einen Eintrag', () {
    final list = listOf([item(1, 'Apfel', rank: 0), item(2, 'Birne', rank: 1)]);
    final updated = withItemUpdated(
      list,
      list.shoppingItems[1].copyWith(
        product: const Product(name: 'Birnen', category: ProductCategory.FRUITS),
        quantity: 4,
      ),
    );
    expect(names(updated.shoppingItems), ['Apfel', 'Birnen']);
    expect(updated.shoppingItems[1].quantity, 4);
    expect(updated.shoppingItems[0], list.shoppingItems[0]);
  });

  test('nextRank', () {
    expect(nextRank(const []), 0);
    expect(nextRank([item(1, 'A', rank: 4), item(2, 'B', rank: 2)]), 5);
  });
}
