import 'package:equatable/equatable.dart';
import 'Meal.dart';
import 'Mealtime.dart';

class DailyMealPlan extends Equatable {
  final int id;
  final DateTime date;
  final Map<Mealtime, List<Meal>> meals;

  const DailyMealPlan({
    required this.id,
    required this.date,
    required this.meals,
  });

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as Map<String, dynamic>? ?? {};

    return DailyMealPlan(
      id: json['id'],
      date: DateTime.parse(json['date']),
      meals: rawMeals.map(
            (key, value) => MapEntry(
          Mealtime.values.byName(key),
          (value as List<dynamic>).map((e) => Meal.fromJson(e)).toList(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().split('T').first,
    'meals': meals.map(
          (k, v) => MapEntry(
        k.name,
        v.map((meal) => meal.toJson()).toList(),
      ),
    ),
  };

  DailyMealPlan copyWith({
    int? id,
    DateTime? date,
    Map<Mealtime, List<Meal>>? meals,
  }) =>
      DailyMealPlan(
        id: id ?? this.id,
        date: date ?? this.date,
        meals: meals ?? this.meals,
      );

  @override
  List<Object> get props => [id, date, meals];
}
