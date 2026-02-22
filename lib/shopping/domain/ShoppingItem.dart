import 'package:equatable/equatable.dart';
import 'Product.dart';

class ShoppingItem extends Equatable {
  final int id;
  final Product product;
  final double quantity;
  final String unit;
  final bool checked;
  final int rank;

  const ShoppingItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unit,
    required this.checked,
    required this.rank
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      unit: json['unit'],
      checked: json['checked'] ?? false,
      rank: json['rank']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'unit': unit,
      'checked': checked,
      'rank': rank
    };
  }

  ShoppingItem copyWith({
    int? id,
    Product? product,
    double? quantity,
    String? unit,
    bool? checked,
    int? rank,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      rank: rank ?? this.rank
    );
  }


  @override
  List<Object> get props => [id, product, quantity, unit, checked, rank];
}
