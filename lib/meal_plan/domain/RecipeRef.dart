import 'package:equatable/equatable.dart';

class RecipeRef extends Equatable {
  final int id;
  final String name;

  const RecipeRef({
    required this.id,
    required this.name,
  });

  factory RecipeRef.fromJson(Map<String, dynamic> json) => RecipeRef(
    id: json['id'],
    name: json['name'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  @override
  List<Object> get props => [id, name];
}
