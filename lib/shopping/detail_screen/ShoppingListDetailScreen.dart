import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/quantity_format.dart';
import '../../widgets/CommonAppBar.dart';
import '../../widgets/CommonFloatingActionButton.dart';
import '../../widgets/WakelockToggle.dart';
import '../ShoppingListMutations.dart';
import '../ShoppingListRepository.dart';
import '../domain/Product.dart';
import '../domain/ProductOrderStrategy.dart';
import '../domain/ShoppingItem.dart';
import '../domain/ShoppingList.dart';
import '../widgets/RenameShoppingListDialog.dart';
import '../widgets/ShoppingItemDialog.dart';
import 'ShoppingListDetailBloc.dart';
import 'ShoppingListDetailEvent.dart';
import 'ShoppingListDetailState.dart';

enum _ListMenuAction { rename, sortByCommon }

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
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            // Der Titel haengt am State, damit ein neuer Name sofort erscheint.
            child: BlocBuilder<ShoppingListDetailBloc, ShoppingListsDetailState>(
              buildWhen: (previous, current) =>
                  _titleOf(previous) != _titleOf(current),
              builder: (context, state) {
                return CommonAppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: _titleOf(state) ?? shoppingList.title,
                  actions: [
                    const WakelockToggle(onAppBar: true,),
                    PopupMenuButton<_ListMenuAction>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) => _onMenuAction(context, action),
                      itemBuilder: (context) => const [
                        PopupMenuItem<_ListMenuAction>(
                          value: _ListMenuAction.rename,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              // Flexible: bei grosser Systemschrift umbrechen
                              // statt aus dem Menue zu laufen.
                              Flexible(child: Text('Liste umbenennen')),
                            ],
                          ),
                        ),
                        PopupMenuItem<_ListMenuAction>(
                          value: _ListMenuAction.sortByCommon,
                          child: Row(
                            children: [
                              Icon(Icons.swap_vert, size: 20),
                              SizedBox(width: 12),
                              Flexible(
                                  child: Text('Nach Beliebtheit sortieren')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: _floatingActionButton(),
          body: _shoppingListDetailPage(),
        ),
      ),
    );
  }

  static String? _titleOf(ShoppingListsDetailState state) =>
      state is LoadedShoppingListDetailState ? state.shoppingList.title : null;

  Future<void> _onMenuAction(
      BuildContext context, _ListMenuAction action) async {
    final bloc = context.read<ShoppingListDetailBloc>();
    final state = bloc.state;
    if (state is! LoadedShoppingListDetailState) return;

    switch (action) {
      case _ListMenuAction.rename:
        final title = await showRenameShoppingListDialog(
          context,
          currentTitle: state.shoppingList.title,
        );
        if (title != null) bloc.add(RenameShoppingListEvent(title));
        break;
      case _ListMenuAction.sortByCommon:
        // Wie bisher zwei Schritte: Raenge nach Laden-Reihenfolge neu
        // vergeben und die Strategie an der Liste merken.
        bloc.add(ReorderByCommonEvent());
        bloc.add(UpdateShoppingListEvent(state.shoppingList
            .copyWith(orderStrategy: ProductOrderStrategy.COMMON_ORDER)));
        break;
    }
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
    final bloc = context.read<ShoppingListDetailBloc>();
    final state = bloc.state;
    if (state is! LoadedShoppingListDetailState) return;

    final input = await showShoppingItemDialog(
      context,
      allIngredients: state.allIngredients,
    );
    if (input == null) return;

    // Stand von JETZT: waehrend der Dialog offen war, kann sich die Liste
    // geaendert haben.
    final current = bloc.state;
    if (current is! LoadedShoppingListDetailState) return;

    bloc.add(
      AddShoppingListItemEvent(
        ShoppingItem(
          id: 0,
          product: Product(name: input.name, category: input.category),
          quantity: input.quantity,
          unit: input.unit.label,
          checked: false,
          rank: nextRank(current.shoppingList.shoppingItems),
        ),
        current.shoppingList.id,
      ),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    ShoppingItem item,
  ) async {
    final bloc = context.read<ShoppingListDetailBloc>();
    final state = bloc.state;
    if (state is! LoadedShoppingListDetailState) return;

    final input = await showShoppingItemDialog(
      context,
      allIngredients: state.allIngredients,
      existing: item,
    );
    if (input == null) return;

    // Vom aktuellen Eintrag ausgehen (er koennte inzwischen abgehakt oder
    // verschoben worden sein) und nur die bearbeiteten Felder ersetzen.
    final current = bloc.state;
    final latest = current is LoadedShoppingListDetailState
        ? current.shoppingList.shoppingItems
            .firstWhere((i) => i.id == item.id, orElse: () => item)
        : item;

    bloc.add(
      EditShoppingListItemEvent(
        latest.copyWith(
          product: Product(name: input.name, category: input.category),
          quantity: input.quantity,
          unit: input.unit.label,
        ),
      ),
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

          // ── Anzeige-Sortierung: unchecked zuerst, dann checked.
          // Innerhalb jeder Gruppe bleibt die bestehende Reihenfolge erhalten.
          final displayItems = inDisplayOrder(items);

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<ShoppingListDetailBloc>()
                  .add(RefreshShoppingListDetailEvent());
            },
            child: ReorderableListView.builder(
              itemCount: displayItems.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;

                // Reordern nur innerhalb der unchecked-Gruppe zulassen.
                final uncheckedCount =
                    displayItems.where((i) => !i.checked).length;
                if (oldIndex >= uncheckedCount || newIndex >= uncheckedCount) {
                  return; // checked Items nicht verschiebbar
                }

                context.read<ShoppingListDetailBloc>().add(
                  ReorderShoppingListItemsEvent(
                    fromIndex: oldIndex,
                    toIndex: newIndex,
                  ),
                );
              },
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _buildItemTile(context, item, state);
              },
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildItemTile(
      BuildContext context,
      ShoppingItem item,
      LoadedShoppingListDetailState state,
      ) {
    void toggle(bool? value) {
      context.read<ShoppingListDetailBloc>().add(
        ToggleShoppingListItemEvent(
          item.copyWith(checked: value ?? !item.checked),
        ),
      );
    }

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
          DeleteShoppingListItemEvent(item, state.shoppingList.id),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        color: item.checked
            ? Colors.grey.withOpacity(0.12)
            : Colors.transparent,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: item.checked ? 0.5 : 1.0,
          // Eigenes (durchsichtiges) Material, damit der Tipp-Effekt UEBER dem
          // grauen Hintergrund abgehakter Zeilen gezeichnet wird.
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              // Antippen hakt ab - wie vorher bei der CheckboxListTile.
              onTap: () => toggle(null),
              // "3 Stück Äpfel", "50g Mehl"
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${_formatItemAmount(item)} ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: item.product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  decoration: item.checked
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.checked
                      ? Colors.grey.shade700
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Bearbeiten',
                    onPressed: () => _showEditItemDialog(context, item),
                  ),
                  Checkbox(
                    value: item.checked,
                    onChanged: toggle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatItemAmount(ShoppingItem item) {
    final quantity = item.quantity.toDouble();

    final amount = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString().replaceAll('.', ',');

    final unit = item.unit.trim();
    final normalizedUnit = unit.toLowerCase();

    if (normalizedUnit == 'stück' ||
        normalizedUnit == 'stk.' ||
        normalizedUnit == 'stk' ||
        normalizedUnit.isEmpty) {
      return '${amount}x';
    }

    return '$amount $unit';
  }

}
