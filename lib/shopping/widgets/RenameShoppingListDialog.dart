import 'package:flutter/material.dart';

/// Fragt einen neuen Namen fuer eine Einkaufsliste ab.
///
/// Liefert den neuen Namen, oder null bei Abbruch bzw. wenn sich nichts
/// geaendert hat.
Future<String?> showRenameShoppingListDialog(
  BuildContext context, {
  required String currentTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameShoppingListDialog(currentTitle: currentTitle),
  );
}

class _RenameShoppingListDialog extends StatefulWidget {
  final String currentTitle;

  const _RenameShoppingListDialog({required this.currentTitle});

  @override
  State<_RenameShoppingListDialog> createState() =>
      _RenameShoppingListDialogState();
}

class _RenameShoppingListDialogState extends State<_RenameShoppingListDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    // Alles markieren: meist will man den Namen komplett ersetzen.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentTitle.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title == widget.currentTitle ? null : title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Einkaufsliste umbenennen"),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: "Name",
          hintText: "Name der Einkaufsliste eingeben",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text("Speichern"),
        ),
      ],
    );
  }
}
