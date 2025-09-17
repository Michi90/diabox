class StockItem {
  int? id;
  int consumableTypeId;
  int quantity;
  DateTime addedDate;

  StockItem({
    this.id,
    required this.consumableTypeId,
    required this.quantity,
    required this.addedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consumable_type_id': consumableTypeId,
      'quantity': quantity,
      'added_date': addedDate.toIso8601String(),
    };
  }

  factory StockItem.fromMap(Map<String, dynamic> map) {
    return StockItem(
      id: map['id'],
      consumableTypeId: map['consumable_type_id'],
      quantity: map['quantity'],
      addedDate: DateTime.parse(map['added_date']),
    );
  }

  @override
  String toString() {
    return 'StockItem{id: $id, consumableTypeId: $consumableTypeId, quantity: $quantity, addedDate: $addedDate}';
  }
}
