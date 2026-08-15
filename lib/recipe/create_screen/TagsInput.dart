import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'CreateRecipeBloc.dart';
import 'CreateRecipeEvent.dart';
import 'CreateRecipeState.dart';

class TagsInput extends StatefulWidget {
  const TagsInput();

  @override
  State<TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<TagsInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _submit(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    context.read<CreateRecipeBloc>().add(RecipeTagAdded(value));
    _controller.clear();
    _focusNode.requestFocus(); // weiter tippen ohne erneut zu tappen
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return BlocBuilder<CreateRecipeBloc, CreateRecipeState>(
      buildWhen: (a, b) => a.recipe.tags != b.recipe.tags,
      builder: (context, state) {
        final tags = state.recipe.tags;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eingabefeld
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
              onChanged: (value) {
                // Komma trennt -> Tag sofort übernehmen
                if (value.endsWith(',')) {
                  _submit(value.substring(0, value.length - 1));
                }
              },
              decoration: InputDecoration(
                hintText: 'Tag hinzufügen (z. B. vegetarisch)',
                prefixIcon: Icon(Icons.tag, color: primary),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.add_circle, color: primary),
                  onPressed: () => _submit(_controller.text),
                ),
              ),
            ),

            // Ausgewählte Tags als entfernbare Chips
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: tags.isEmpty
                  ? const SizedBox(width: double.infinity, height: 4)
                  : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return InputChip(
                      label: Text(tag),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                      backgroundColor: primary.withOpacity(0.1),
                      side: BorderSide(color: primary.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      deleteIcon:
                      Icon(Icons.close, size: 16, color: primary),
                      onDeleted: () => context
                          .read<CreateRecipeBloc>()
                          .add(RecipeTagRemoved(tag)),
                      materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}