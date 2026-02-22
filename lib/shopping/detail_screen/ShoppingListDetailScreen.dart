import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/CommonAppBar.dart';
import '../../widgets/CommonFloatingActionButton.dart';
import '../ShoppingListRepository.dart';
import '../domain/Product.dart';
import '../domain/ProductOrderStrategy.dart';
import '../domain/ShoppingItem.dart';
import '../domain/ShoppingList.dart';
import '../domain/Unit.dart';
import 'ShoppingListDetailBloc.dart';
import 'ShoppingListDetailEvent.dart';
import 'ShoppingListDetailState.dart';

class ShoppingListDetailScreen extends StatelessWidget {
  final ShoppingList shoppingList;

  const ShoppingListDetailScreen({super.key, required this.shoppingList});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingListDetailBloc(
        initialList: shoppingList,
        dataRepo: context.read<ShoppingListRepository>(),
      ),
      child: BlocListener<ShoppingListDetailBloc, ShoppingListsDetailState>(
        listener: (context, state) {},
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: CommonAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: shoppingList.title,
            actions: [
              Builder(
                builder: (context) {
                  return PopupMenuButton<ProductOrderStrategy>(
                    icon: const Icon(Icons.sort),
                    onSelected: (strategy) {
                      final bloc = context.read<ShoppingListDetailBloc>();
                      final state = bloc.state;
                      if (state is LoadedShoppingListDetailState) {
                        final updatedList = state.shoppingList
                            .copyWith(orderStrategy: strategy);
                        bloc.add(UpdateShoppingListEvent(updatedList));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<ProductOrderStrategy>(
                        enabled: false,
                        child: Text(
                          'Sortierung',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      ...ProductOrderStrategy.values.map((strategy) {
                        return PopupMenuItem<ProductOrderStrategy>(
                          value: strategy,
                          child: Text(strategy.label),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
          floatingActionButton: _floatingActionButton(),
          body: _shoppingListDetailPage(),
        ),
      ),
    );
  }

  Widget _floatingActionButton() {
    return BlocBuilder<ShoppingListDetailBloc, ShoppingListsDetailState>(
      builder: (context, state) {
        return CommonFloatingActionButton(
          showNavigator: () {
            _showAddItemDialog(context);
          },
          iconData: Icons.add,
          iconSize: 46,
          iconColor: null,
          backgroundColor: null,
        );
      },
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: "1");
    Unit unit = Unit.piece;
    ProductCategory category = ProductCategory.OTHER;

    final bloc = context.read<ShoppingListDetailBloc>();

    int nextRank = 0;

    final currentState = bloc.state;
    if (currentState is LoadedShoppingListDetailState &&
        currentState.shoppingList.shoppingItems.isNotEmpty) {
      nextRank = currentState.shoppingList.shoppingItems
              .map((item) => item.rank)
              .reduce((a, b) => a > b ? a : b) +
          1;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        final state = bloc.state;
        Map<String, List<String>> allIngredients = {};
        if (state is LoadedShoppingListDetailState) {
          allIngredients = state.allIngredients;
        }
        final flatIngredients =
            allIngredients.values.expand((list) => list).toList();

        return AlertDialog(
          title: const Text("Produkt hinzufügen"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return flatIngredients.where((option) => option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    nameController.text = selection;
                    final catKey = allIngredients.entries
                        .firstWhere(
                          (entry) => entry.value.contains(selection),
                          orElse: () => const MapEntry('OTHER', []),
                        )
                        .key;

                    category = ProductCategory.values.firstWhere(
                      (c) => c.name.toLowerCase() == catKey.toLowerCase(),
                      orElse: () => ProductCategory.OTHER,
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, _) {
                    return TextField(
                      controller: controller,
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
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Menge",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Unit>(
                  value: unit,
                  items: Unit.values
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) unit = val;
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final qty = double.tryParse(quantityController.text) ?? 1;

                if (name.isNotEmpty) {
                  bloc.add(
                    AddShoppingListItemEvent(
                      ShoppingItem(
                        id: 0,
                        product: Product(name: name, category: category),
                        quantity: qty,
                        unit: unit.name,
                        checked: false,
                        rank: nextRank,
                      ),
                      state is LoadedShoppingListDetailState
                          ? state.shoppingList.id
                          : 0,
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    );
  }

  Widget _shoppingListDetailPage() {
    return BlocBuilder<ShoppingListDetailBloc, ShoppingListsDetailState>(
      builder: (context, state) {
        if (state is LoadedShoppingListDetailState) {
          final items = state.shoppingList.shoppingItems;

          if (items.isEmpty) {
            return const Center(child: Text("Keine Produkte"));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<ShoppingListDetailBloc>()
                  .add(RefreshShoppingListDetailEvent());
            },
            child: ReorderableListView.builder(
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                context.read<ShoppingListDetailBloc>().add(
                      ReorderShoppingListItemsEvent(
                        fromIndex: oldIndex,
                        toIndex: newIndex,
                      ),
                    );
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: Colors.red,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                  onDismissed: (_) {
                    context.read<ShoppingListDetailBloc>().add(
                          DeleteShoppingListItemEvent(
                              item, state.shoppingList.id),
                        );
                  },
                  child: CheckboxListTile(
                    value: item.checked,
                    title: Text(item.product.name),
                    subtitle: Text('${item.quantity} ${item.unit}'),
                    onChanged: (value) {
                      context.read<ShoppingListDetailBloc>().add(
                            ToggleShoppingListItemEvent(
                              item.copyWith(checked: value ?? false),
                            ),
                          );
                    },
                  ),
                );
              },
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
