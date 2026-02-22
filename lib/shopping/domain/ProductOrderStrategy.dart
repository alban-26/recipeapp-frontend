enum ProductOrderStrategy {
  STANDARD,
  COMMON_ORDER,
}

extension ProductOrderStrategyExtension on ProductOrderStrategy {
  /// UI-Text
  String get label {
    switch (this) {
      case ProductOrderStrategy.STANDARD:
        return "Standard";
      case ProductOrderStrategy.COMMON_ORDER:
        return "Beliebt";
    }
  }

  String get apiValue => this.name;

  static ProductOrderStrategy fromApi(String value) {
    return ProductOrderStrategy.values.firstWhere(
          (e) => e.name == value,
      orElse: () => ProductOrderStrategy.STANDARD,
    );
  }
}
