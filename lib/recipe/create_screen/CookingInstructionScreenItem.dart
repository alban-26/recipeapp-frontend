import '../domain/CookingInstruction.dart';

class CookingInstructionScreenItem extends CookingInstruction {
  final String id;

  const CookingInstructionScreenItem(
      {required this.id,
      required super.instruction,
      required super.recipeIngredients});
}
