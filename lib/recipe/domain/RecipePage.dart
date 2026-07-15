import 'Recipe.dart';

class RecipePage {
  final List<Recipe> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;
  final bool last;

  RecipePage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.last,
  });

  factory RecipePage.empty({int page = 0, int size = 20}) => RecipePage(
    content: [],
    page: page,
    size: size,
    totalPages: 0,
    totalElements: 0,
    last: true,
  );
}