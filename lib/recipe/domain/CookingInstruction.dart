import 'package:equatable/equatable.dart';

import 'RecipeIngredient.dart';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'RecipeIngredient.dart';

class CookingInstruction extends Equatable {
  final String id;
  final String instruction;
  final List<RecipeIngredient> recipeIngredients;

  const CookingInstruction({
    required this.id,
    required this.instruction,
    required this.recipeIngredients,
  });

  factory CookingInstruction.empty() {
    return CookingInstruction(
      id: const Uuid().v4(),
      instruction: '',
      recipeIngredients: const [],
    );
  }

  factory CookingInstruction.fromJson(Map<String, dynamic> json) {
    return CookingInstruction(
      id: json['id'] ?? const Uuid().v4(),
      instruction: json['instruction'] ?? '',
      recipeIngredients: (json['recipeIngredients'] as List<dynamic>? ?? [])
          .map((item) => RecipeIngredient.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'instruction': instruction,
      'recipeIngredients':
      recipeIngredients.map((i) => i.toJson()).toList(),
    };
  }

  CookingInstruction copyWith({
    String? id,
    String? instruction,
    List<RecipeIngredient>? recipeIngredients,
  }) {
    return CookingInstruction(
      id: id ?? this.id,
      instruction: instruction ?? this.instruction,
      recipeIngredients: recipeIngredients ?? this.recipeIngredients,
    );
  }

  @override
  List<Object> get props => [
    id,
    instruction,
    recipeIngredients,
  ];
}