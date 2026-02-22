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

class Product extends Equatable {
  final String name;
  final ProductCategory category;

  const Product({
    required this.name,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'],
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
