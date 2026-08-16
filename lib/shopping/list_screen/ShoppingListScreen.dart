import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../widgets/AnimatedEmptyState.dart';
import '../../widgets/CommonAppBar.dart';
import '../../widgets/CommonFloatingActionButton.dart';
import '../ShoppingListRepository.dart';
import '../domain/ShoppingList.dart';
import '../navigation/ShoppingListNavigatorCubit.dart';

import 'ShoppingListBloc.dart';
import 'ShoppingListEvent.dart';
import 'ShoppingListState.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _shoppingLists(context);
  }

  Widget _shoppingLists(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingListBloc(
        dataRepo: context.read<ShoppingListRepository>(),
        recipeNavigatorCubit: context.read<ShoppingNavigatorCubit>(),
      )..add(LoadShoppingListEvent()),
      child: BlocListener<ShoppingListBloc, ShoppingListState>(
        listener: (context, state) {},
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: CommonAppBar(title: 'Einkaufsliste'),
          floatingActionButton: _floatingActionButton(),
          body: _shoppingListsPage(),
        ),
      ),
    );
  }

  Widget _floatingActionButton() {
    return BlocBuilder<ShoppingListBloc, ShoppingListState>(
      builder: (context, state) {
        return CommonFloatingActionButton(
          showNavigator: () {
            _showCreateShoppingListDialog(context);
          },
          iconData: Icons.add,
          iconSize: 46,
          iconColor: null,
          backgroundColor: null,
        );
      },
    );
  }

  Future<void> _showCreateShoppingListDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Einkaufsliste erstellen"),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Name",
              hintText: "Name der Einkaufsliste eingeben",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newList = ShoppingList(
                    id: 0,
                    title: name,
                    shoppingItems: [],
                    createdAt: DateTime.now(),
                  );

                  context.read<ShoppingListBloc>().add(
                    ShoppingListAdded(newList),
                  );

                  Navigator.of(ctx).pop();

                }
              },
              child: const Text("Erstellen"),
            ),
          ],
        );
      },
    );
  }

  Widget _shoppingListsPage() {
    return BlocBuilder<ShoppingListBloc, ShoppingListState>(
      builder: (context, state) {
        if (state is LoadingShoppingListState) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is LoadedShoppingListState) {

          if (state.shoppingLists.isEmpty) {
            return AnimatedEmptyState(
              icon: Icons.shopping_cart_outlined,
              message: "Noch keine Einkaufslisten",
              buttonText: "Erste Einkaufsliste erstellen",
              onPressed: () => _showCreateShoppingListDialog(context),
            );

          }

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<ShoppingListBloc>().add(PullToRefreshEvent()),
            child: ListView.builder(
              itemCount: state.shoppingLists.length,
              itemBuilder: (context, index) {
                final list = state.shoppingLists[index];
                return _shoppingListTile(context, list);
              },
            ),
          );
        } else if (state is FailedToLoadShoppingListState) {
          return Center(child: Text('Error: ${state.error}'));
        } else {
          return const Center(child: Text('Keine Einkaufslisten gefunden'));
        }
      },
    );
  }


  Widget _shoppingListTile(BuildContext context, ShoppingList list) {
    final itemCount = list.shoppingItems.length;
    final checkedCount =
        list.shoppingItems.where((item) => item.checked).length;

    final dateFormat = DateFormat('dd.MM.yyyy');

    return Dismissible(
      key: Key(list.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
      onDismissed: (_) =>
          context.read<ShoppingListBloc>().add(ShoppingListDeleted(list)),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Liste Löschen'),
            content: Text('"${list.title}" löschen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                const Text('Löschen', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => BlocProvider.of<ShoppingNavigatorCubit>(context)
              .showShoppingListDetail(list),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Einkaufsliste',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            list.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateFormat.format(list.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: itemCount > 0 ? checkedCount / itemCount : 0,
                  backgroundColor: Colors.grey[200],
                  color: Theme.of(context).primaryColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$checkedCount/$itemCount Produkte',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (list.shoppingItems.isNotEmpty)
                      Text(
                        '${((checkedCount / itemCount) * 100).toStringAsFixed(0)}% erledigt',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
