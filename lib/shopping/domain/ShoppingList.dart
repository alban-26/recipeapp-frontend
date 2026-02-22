import 'package:equatable/equatable.dart';

import 'ProductOrderStrategy.dart';
import 'ShoppingItem.dart';

class ShoppingList extends Equatable {
  final int id;
  final String title;
  final List<ShoppingItem> shoppingItems;
  final DateTime createdAt;
  final ProductOrderStrategy orderStrategy;

  const ShoppingList({
    required this.id,
    required this.title,
    required this.shoppingItems,
    required this.createdAt,
    this.orderStrategy = ProductOrderStrategy.STANDARD,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'],
      title: json['title'],
      shoppingItems: (json['shoppingItems'] as List)
          .map((e) => ShoppingItem.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      orderStrategy: ProductOrderStrategyExtension.fromApi(
        json['orderStrategy'] ?? 'STANDARD',
      ),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'shoppingItems': shoppingItems.map((i) => i.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'orderStrategy': orderStrategy.apiValue,
    };
  }

  ShoppingList copyWith({
    int? id,
    String? title,
    List<ShoppingItem>? shoppingItems,
    DateTime? createdAt,
    ProductOrderStrategy? orderStrategy,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      createdAt: createdAt ?? this.createdAt,
      orderStrategy: orderStrategy ?? this.orderStrategy,
    );
  }

  @override
  List<Object> get props => [id, title, shoppingItems, createdAt, orderStrategy];
}
