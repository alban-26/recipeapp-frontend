class RecipeState {
  final int portions;

  RecipeState({
    required this.portions,
  });

  RecipeState copyWith({int? portions}) {
    return RecipeState(portions: portions ?? this.portions);
  }
}