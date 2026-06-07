import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class RecipeIngredient extends Equatable {
  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.empty() {
    return RecipeIngredient(
      id: const Uuid().v4(),
      name: '',
      category: 'OTHER',
      quantity: 0,
      unit: 'g',
    );
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? '',
      category: json['category'] ?? 'OTHER',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'g',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit.isEmpty ? 'g' : unit,
    };
  }

  RecipeIngredient copyWith({
    String? id,
    String? name,
    String? productCategory,
    double? quantity,
    String? unit,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: productCategory ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  @override
  List<Object> get props => [id, name, category, quantity, unit];
}