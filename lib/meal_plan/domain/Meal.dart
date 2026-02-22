import 'package:equatable/equatable.dart';
import 'RecipeRef.dart';

class Meal extends Equatable {
  final RecipeRef recipe;
  final int servings;

  const Meal({
    required this.recipe,
    required this.servings,
  });

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    recipe: RecipeRef.fromJson(json['recipe']),
    servings: json['servings'],
  );

  Map<String, dynamic> toJson() => {
    'recipe': recipe.toJson(),
    'servings': servings,
  };

  Meal copyWith({
    RecipeRef? recipe,
    int? servings,
  }) =>
      Meal(
        recipe: recipe ?? this.recipe,
        servings: servings ?? this.servings,
      );

  @override
  List<Object> get props => [recipe, servings];
}
