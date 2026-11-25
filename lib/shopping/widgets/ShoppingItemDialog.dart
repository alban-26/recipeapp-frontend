import 'package:flutter/material.dart';

import '../../common/quantity_format.dart';
import '../domain/Product.dart';
import '../domain/ShoppingItem.dart';
import '../domain/Unit.dart';

/// Was der Nutzer im Dialog eingegeben hat.
class ShoppingItemInput {
  final String name;
  final ProductCategory category;
  final double quantity;
  final Unit unit;

  const ShoppingItemInput({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
  });
}

/// Dialog zum Hinzufuegen ([existing] == null) oder Bearbeiten eines Eintrags.
/// Liefert die Eingabe oder null bei Abbruch.
Future<ShoppingItemInput?> showShoppingItemDialog(
  BuildContext context, {
  required Map<String, List<String>> allIngredients,
  ShoppingItem? existing,
}) {
  return showDialog<ShoppingItemInput>(
    context: context,
    builder: (_) => _ShoppingItemDialog(
      allIngredients: allIngredients,
      existing: existing,
    ),
  );
}

/// Liest "0,5" genauso wie "0.5".
double? parseQuantity(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value.isInfinite || value < 0) return null;
  return value;
}

class _ShoppingItemDialog extends StatefulWidget {
  final Map<String, List<String>> allIngredients;
  final ShoppingItem? existing;

  const _ShoppingItemDialog({required this.allIngredients, this.existing});

  @override
  State<_ShoppingItemDialog> createState() => _ShoppingItemDialogState();
}

class _ShoppingItemDialogState extends State<_ShoppingItemDialog> {
  late final TextEditingController _quantityController;
  late final List<String> _suggestions;
  late Unit _unit;

  /// Gehoert dem Autocomplete-Feld, wird dort nur ausgeliehen.
  TextEditingController? _nameController;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _quantityController = TextEditingController(
      text: existing == null ? "1" : formatQuantity(existing.quantity),
    );
    _unit = Unit.tryParse(existing?.unit) ?? Unit.piece;
    _suggestions =
        widget.allIngredients.values.expand((list) => list).toList();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Kategorie aus der Zutatenliste; bei unbekanntem Namen bleibt beim
  /// Bearbeiten die bisherige erhalten, solange der Name derselbe ist.
  ProductCategory _categoryFor(String name) {
    for (final entry in widget.allIngredients.entries) {
      if (entry.value.contains(name)) {
        return ProductCategory.values.firstWhere(
          (c) => c.name.toLowerCase() == entry.key.toLowerCase(),
          orElse: () => ProductCategory.OTHER,
        );
      }
    }
    final existing = widget.existing;
    if (existing != null && existing.product.name == name) {
      return existing.product.category;
    }
    return ProductCategory.OTHER;
  }

  void _submit() {
    final name = (_nameController?.text ?? '').trim();
    if (name.isEmpty) {
      // Wie bisher: ohne Namen passiert nichts, der Dialog schliesst.
      Navigator.of(context).pop();
      return;
    }

    final quantity = parseQuantity(_quantityController.text) ??
        widget.existing?.quantity ??
        1;

    Navigator.of(context).pop(
      ShoppingItemInput(
        name: name,
        category: _categoryFor(name),
        quantity: quantity,
        unit: _unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? "Produkt bearbeiten" : "Produkt hinzufügen"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(
                text: widget.existing?.product.name ?? '',
              ),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _suggestions.where((option) => option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              fieldViewBuilder: (context, controller, focusNode, _) {
                _nameController = controller;
                return TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Menge",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Unit>(
              value: _unit,
              items: Unit.values
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.label),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) _unit = val;
              },
              decoration: const InputDecoration(
                labelText: "Einheit",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEdit ? "Speichern" : "Hinzufügen"),
        ),
      ],
    );
  }
}
