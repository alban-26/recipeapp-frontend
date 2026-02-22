import 'package:equatable/equatable.dart';

class RecipeIngredient extends Equatable {
  final String name;
  final String category;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'],
        category: json['category'],
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'],
      );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit == '' ? 'g' : unit,
    };
  }


  RecipeIngredient copyWith({String? name, String? productCategory, double? quantity, String? unit}) {
    return RecipeIngredient(
        name: name ?? this.name,
        category: productCategory ?? this.category,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit);
  }

  @override
  List<Object> get props => [name, category, quantity, unit];
}
