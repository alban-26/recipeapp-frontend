import 'package:equatable/equatable.dart';

enum ProductCategory {
  DAIRY,
  MEAT,
  FISH,
  BAKERY,
  FRUITS,
  VEGETABLES,
  BEVERAGES,
  FROZEN,
  DRY_GOODS,
  SWEETS,
  ORGANIC,
  VEGAN,
  SPICES,
  ELECTRONICS,
  CLOTHING,
  BOOKS,
  HOME_AND_KITCHEN,
  BEAUTY,
  SPORTS,
  TOYS,
  AUTOMOTIVE,
  OTHER,
}

/// Reihenfolge der Kategorien im Laden - Spiegel von ProductCategory.getRank()
/// im shopping-list-Service. Wird gebraucht, damit "Nach Beliebtheit
/// sortieren" auch ohne Verbindung dasselbe Ergebnis liefert wie der Server.
extension ProductCategoryStoreOrder on ProductCategory {
  int get storeRank {
    switch (this) {
      case ProductCategory.VEGETABLES:
        return 10;
      case ProductCategory.FRUITS:
        return 20;
      case ProductCategory.BAKERY:
        return 30;
      case ProductCategory.MEAT:
        return 40;
      case ProductCategory.FISH:
        return 50;
      case ProductCategory.DAIRY:
        return 60;
      case ProductCategory.DRY_GOODS:
        return 70;
      case ProductCategory.SPICES:
        return 80;
      case ProductCategory.SWEETS:
        return 90;
      case ProductCategory.BEVERAGES:
        return 100;
      case ProductCategory.FROZEN:
        return 110;
      case ProductCategory.ORGANIC:
        return 120;
      case ProductCategory.VEGAN:
        return 130;
      case ProductCategory.HOME_AND_KITCHEN:
        return 200;
      case ProductCategory.BEAUTY:
        return 210;
      case ProductCategory.CLOTHING:
        return 220;
      case ProductCategory.SPORTS:
        return 230;
      case ProductCategory.TOYS:
        return 240;
      case ProductCategory.BOOKS:
        return 250;
      case ProductCategory.ELECTRONICS:
        return 260;
      case ProductCategory.AUTOMOTIVE:
        return 270;
      case ProductCategory.OTHER:
        return 999;
    }
  }
}

class Product extends Equatable {
  final String name;
  final ProductCategory category;

  const Product({
    required this.name,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] ?? '',
      category: ProductCategory.values.firstWhere(
            (e) => e.toString().split('.').last == json['category'],
        orElse: () => ProductCategory.OTHER,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category.toString().split('.').last,
    };
  }

  Product copyWith({
    String? name,
    ProductCategory? category,
  }) {
    return Product(
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }

  @override
  List<Object> get props => [name, category];
}
