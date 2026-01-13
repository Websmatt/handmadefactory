enum EntityKind { items, products }

extension EntityKindExt on EntityKind {
  String get label => this == EntityKind.items ? 'Items' : 'Products';
  String get endpoint => this == EntityKind.items ? '/items' : '/products';
}
