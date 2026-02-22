import 'package:equatable/equatable.dart';
import 'DailyMealPlan.dart';

class MealPlan extends Equatable {
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyMealPlan> dailyMealPlans;

  const MealPlan({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.dailyMealPlans,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
    id: json['id'],
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    dailyMealPlans: (json['dailyMealPlans'] as List<dynamic>)
        .map((e) => DailyMealPlan.fromJson(e))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String().split('T').first,
    'endDate': endDate.toIso8601String().split('T').first,
    'dailyMealPlans': dailyMealPlans.map((e) => e.toJson()).toList(),
  };

  MealPlan copyWith({
    int? id,
    DateTime? startDate,
    DateTime? endDate,
    List<DailyMealPlan>? dailyMealPlans,
  }) =>
      MealPlan(
        id: id ?? this.id,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        dailyMealPlans: dailyMealPlans ?? this.dailyMealPlans,
      );

  @override
  List<Object> get props => [id, startDate, endDate, dailyMealPlans];
}
