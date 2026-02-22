import '../StorageRepository.dart';
import '../api/BaseApiClient.dart';
import 'ReorderShoppingItemsRequest.dart';
import 'domain/ShoppingItem.dart';
import 'domain/ShoppingList.dart';

class ShoppingListApiClient extends BaseApiClient {
  final StorageRepository storageRepository;

  ShoppingListApiClient({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
    required this.storageRepository,
  });

  Future<List<ShoppingList>> getShoppingLists() async {
    final response = await dio.get('$baseUrl/shoppingLists');
    if (response.statusCode == 204 ||
        response.data == null ||
        response.data == "") {
      return [];
    }
    final shoppingLists =
        (response.data as List).map((e) => ShoppingList.fromJson(e)).toList();

    return shoppingLists;
  }

  Future<ShoppingList> getShoppingList(String id) async {
    final response = await dio.get('$baseUrl/shoppingLists/$id');
    return ShoppingList.fromJson(response.data);
  }

  Future<int?> deleteShoppingList(String id) async {
    final response = await dio.delete('$baseUrl/shoppingLists/$id');
    return response.statusCode;
  }

  Future<int> createShoppingList(ShoppingList shoppingList) async {
    final response = await dio.post(
      '$baseUrl/shoppingLists',
      data: shoppingList.toJson(),
    );

    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<void> updateShoppingList(String id, ShoppingList shoppingList) async {
    await dio.put(
      '$baseUrl/shoppingLists/$id',
      data: shoppingList.toJson(),
    );
  }

  Future<List<ShoppingItem>> getShoppingItems(String listId) async {
    final response =
        await dio.get('$baseUrl/shoppingLists/$listId/shoppingItems');
    return (response.data as List)
        .map((e) => ShoppingItem.fromJson(e))
        .toList();
  }

  Future<ShoppingItem> getShoppingItemById(String listId, String itemId) async {
    final response =
        await dio.get('$baseUrl/shoppingLists/$listId/shoppingItems/$itemId');
    return ShoppingItem.fromJson(response.data);
  }

  Future<int> addShoppingItem(String listId, ShoppingItem item) async {
    final response = await dio.post(
      '$baseUrl/shoppingLists/$listId/shoppingItems',
      data: item.toJson(),
    );

    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<void> updateShoppingItem(
      String listId, String itemId, ShoppingItem item) async {
    await dio.patch(
      '$baseUrl/shoppingLists/$listId/shoppingItems/$itemId',
      data: item.toJson(),
    );
  }

  Future<void> removeShoppingItem(String listId, String itemId) async {
    await dio.delete('$baseUrl/shoppingLists/$listId/shoppingItems/$itemId');
  }

  Future<void> reorderShoppingItem(
      String listId,
      ReorderShoppingItemsRequest reorderShoppingItemsRequest,
      ) async {
    await dio.post(
      '$baseUrl/shoppingLists/$listId/shoppingItems/reorder',
      data: reorderShoppingItemsRequest.toJson(),
    );
  }

}

class ShoppingListRepository {
  final ShoppingListApiClient apiClient;

  ShoppingListRepository({required this.apiClient});

  Future<List<ShoppingList>> fetchShoppingLists() =>
      apiClient.getShoppingLists();

  Future<ShoppingList> fetchShoppingList(String shoppingListId) =>
      apiClient.getShoppingList(shoppingListId);

  Future<int> addShoppingList(ShoppingList shoppingList) =>
      apiClient.createShoppingList(shoppingList);

  Future<void> reorderShoppingItem(int shoppingListId,
          ReorderShoppingItemsRequest reorderShoppingItemsRequest) =>
      apiClient.reorderShoppingItem(
          shoppingListId.toString(), reorderShoppingItemsRequest);

  Future<int?> removeShoppingList(int shoppingListId) =>
      apiClient.deleteShoppingList(shoppingListId.toString());

  Future<void> updateShoppingList(
          int shoppingListId, ShoppingList shoppingList) =>
      apiClient.updateShoppingList(shoppingListId.toString(), shoppingList);

  Future<List<ShoppingItem>> fetchShoppingItems(int shoppingListId) =>
      apiClient.getShoppingItems(shoppingListId.toString());

  Future<ShoppingItem> fetchShoppingItemById(int shoppingListId, int itemId) =>
      apiClient.getShoppingItemById(
          shoppingListId.toString(), itemId.toString());

  Future<int> addShoppingItem(int shoppingListId, ShoppingItem item) =>
      apiClient.addShoppingItem(shoppingListId.toString(), item);

  Future<void> updateShoppingItem(
          int shoppingListId, int itemId, ShoppingItem item) =>
      apiClient.updateShoppingItem(
          shoppingListId.toString(), itemId.toString(), item);

  Future<void> removeShoppingItem(int shoppingListId, int itemId) => apiClient
      .removeShoppingItem(shoppingListId.toString(), itemId.toString());
}
