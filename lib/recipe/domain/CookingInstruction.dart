import 'package:equatable/equatable.dart';

import 'RecipeIngredient.dart';

class CookingInstruction extends Equatable {
  final String instruction;
  final List<RecipeIngredient> recipeIngredients;

  const CookingInstruction({
    required this.instruction,
    required this.recipeIngredients,
  });

  factory CookingInstruction.fromJson(Map<String, dynamic> json) =>
      CookingInstruction(
        instruction: json['instruction'],
        recipeIngredients: (json['recipeIngredients'] as List<dynamic>)
            .map((item) => RecipeIngredient.fromJson(item))
            .toList(),
      );

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      'recipeIngredients': recipeIngredients.map((i) => i.toJson()).toList(),
    };
  }

  @override
  List<Object> get props => [instruction, recipeIngredients];
}
