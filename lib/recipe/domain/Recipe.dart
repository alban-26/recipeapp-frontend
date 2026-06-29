import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/recipe/domain/CookingInstruction.dart';
import 'package:recipeapp_frontend/recipe/domain/RecipeIngredient.dart';
import 'package:uuid/uuid.dart';

class Recipe extends Equatable {
  final int id;
  final String name;
  final List<RecipeIngredient> recipeIngredients;
  final List<CookingInstruction> cookingInstructions;
  final int portions;
  final Duration duration;
  final Uint8List? image;

  const Recipe({
    required this.id,
    required this.name,
    required this.cookingInstructions,
    required this.recipeIngredients,
    required this.portions,
    required this.duration,
    this.image,
  });

  static Duration parseISODuration(String durationString) {
    if (durationString.startsWith("PT")) {
      durationString = durationString.substring(2); // Remove "PT"

      int hours = 0, minutes = 0, seconds = 0;

      RegExp regex = RegExp(r'(\d+)(H|M|S)');
      for (var match in regex.allMatches(durationString)) {
        int value = int.parse(match.group(1)!);
        String unit = match.group(2)!;

        if (unit == "H") {
          hours = value;
        } else if (unit == "M") {
          minutes = value;
        } else if (unit == "S") {
          seconds = value;
        }
      }

      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }

    throw FormatException("Invalid ISO-8601 duration format");
  }

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'],
        name: json['name'],
        cookingInstructions: (json['cookingInstructions'] as List<dynamic>)
            .map((item) => CookingInstruction.fromJson(item))
            .toList(),
        recipeIngredients: (json['recipeIngredients'] as List<dynamic>)
            .map((item) => RecipeIngredient.fromJson(item))
            .toList(),
        portions: json['portions'],
        duration: parseISODuration(json['duration']),
        image: null, // The image can be loaded later asynchronously
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'recipeIngredients': recipeIngredients.map((i) => i.toJson()).toList(),
      'cookingInstructions':
          cookingInstructions.map((i) => i.toJson()).toList(),
      'portions': portions,
      'duration':
          'PT${duration.inHours}H${duration.inMinutes.remainder(60)}M${duration.inSeconds.remainder(60)}S',
    };
  }

  // Load the image asynchronously from the storage repository
  Future<Recipe> withImage(
      StorageRepository storageRepository, String path) async {
    return Recipe(
      id: id,
      name: name,
      cookingInstructions: cookingInstructions,
      recipeIngredients: recipeIngredients,
      portions: portions,
      duration: duration,
      image: await storageRepository.loadImage(path),
    );
  }

  Recipe copyWith({
    int? id,
    String? name,
    List<RecipeIngredient>? recipeIngredients,
    List<CookingInstruction>? cookingInstructions,
    int? portions,
    Duration? duration,
    Uint8List? image,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      recipeIngredients: recipeIngredients ?? this.recipeIngredients,
      cookingInstructions: cookingInstructions ?? this.cookingInstructions,
      portions: portions ?? this.portions,
      duration: duration ?? this.duration,
      image: image ?? this.image,
    );
  }

  Recipe copyWithoutImage() {
    return Recipe(
      id: id,
      name: name,
      recipeIngredients: recipeIngredients,
      cookingInstructions: cookingInstructions,
      portions: portions,
      duration: duration,
      image: null,
    );
  }

  factory Recipe.fromLLMJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      portions: json['portions'] ?? 1,

      duration: json['duration'] is String
          ? Recipe.parseISODuration(json['duration'])
          : Duration(minutes: (json['duration'] as num?)?.toInt() ?? 0),

      recipeIngredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((item) => RecipeIngredient(
        id: const Uuid().v4(),
        name: item['name'] ?? '',
        category: 'OTHER',
        quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
        unit: item['unit'] ?? '',
      ))
          .toList(),

      cookingInstructions: (json['instructions'] as List<dynamic>? ?? [])
          .map((item) => CookingInstruction(
        instruction: item.toString(),
        recipeIngredients: const [],
      ))
          .toList(),

      image: null,
    );
  }

  @override
  List<Object> get props =>
      [id, name, recipeIngredients, cookingInstructions, portions, duration];
}
