class ReorderShoppingItemsRequest {
  final int fromIndex;
  final int toIndex;

  const ReorderShoppingItemsRequest({
    required this.fromIndex,
    required this.toIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromIndex': fromIndex,
      'toIndex': toIndex,
    };
  }
}
