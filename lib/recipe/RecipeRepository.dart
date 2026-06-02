import 'dart:convert';

import 'package:recipeapp_frontend/StorageRepository.dart';

import '../api/BaseApiClient.dart';
import 'domain/Recipe.dart';
import 'domain/RecipeIngredient.dart';

class RecipeApiClient extends BaseApiClient {
  final StorageRepository storageRepository;

  RecipeApiClient(
      {required super.dio,
      required super.secureStorage,
      required super.baseUrl,
      required this.storageRepository});

  Future<List<Recipe>> getRecipes() async {
    final response = await dio.get('$baseUrl/recipes');
    if (response.statusCode == 204 || response.data == null || response.data == "") {
      return [];
    }
    final recipes = (response.data as List)
        .map((e) => Recipe.fromJson(e)) // Create basic recipes without images
        .toList();

    return Future.wait(recipes.map((recipe) async => await recipe.withImage(
        storageRepository, '$baseUrl/recipes/${recipe.id}/image')));
  }

  Future<Recipe> getRecipe(String id) async {
    final response = await dio.get('$baseUrl/recipes/$id');
    return Recipe.fromJson(response.data);
  }

  Future<int?> deleteRecipe(String id) async {
    final response = await dio.delete('$baseUrl/recipes/$id');
    // Ensure response data is a Map and contains 'id'
    if (response.statusCode != null) {
      return response.statusCode;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<Recipe> updateRecipe(
      Recipe recipe,
      ) async {
    final response = await dio.put(
      '$baseUrl/recipes',
      data: recipe.toJson(),
    );

    return Recipe.fromJson(response.data);
  }

  Future<int> createRecipe(Recipe recipe) async {
    final response = await dio.post(
      '$baseUrl/recipes',
      data: recipe.toJson(),
    );

    // Ensure response data is a Map and contains 'id'
    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<Map<String, List<String>>> loadIngredients() async {
    final response = await dio.get('$baseUrl/recipes/ingredients');

    List<dynamic> data = [];
    if (response.data != null && response.data != '' && response.data != '[]') {
      data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
    }

    final Map<String, List<String>> result = {};
    for (final item in data) {
      final category = item['category'] as String;
      final name = item['name'] as String;
      result.putIfAbsent(category, () => []).add(name);
    }

    return result;
  }

}

class RecipeRepository {
  final RecipeApiClient apiClient;

  RecipeRepository({required this.apiClient});

  Future<List<Recipe>> fetchRecipes() => apiClient.getRecipes();

  Future<Recipe> fetchRecipe(String recipeId) => apiClient.getRecipe(recipeId);

  Future<Recipe> updateRecipe(Recipe recipe) => apiClient.updateRecipe(recipe);

  Future<int> addRecipe(Recipe recipe) => apiClient.createRecipe(recipe);

  Future<int?> removeRecipe(int recipeId) =>
      apiClient.deleteRecipe(recipeId.toString());

  Future<Map<String, List<String>>> loadIngredients() => apiClient.loadIngredients();
}
