class ConsumableType {
  int? id;
  String name;
  int defaultLifespanDays;
  bool isFixedLifespan;
  bool managesStock; // New field
  List<int>? notificationOffsetsInMinutes; // New field for notification offsets

  ConsumableType({
    this.id,
    required this.name,
    required this.defaultLifespanDays,
    required this.isFixedLifespan,
    this.managesStock = true, // Default to true
    this.notificationOffsetsInMinutes, // Initialize new field
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_lifespan_days': defaultLifespanDays,
      'is_fixed_lifespan': isFixedLifespan ? 1 : 0,
      'manages_stock': managesStock ? 1 : 0,
      'notification_offsets_in_minutes': notificationOffsetsInMinutes?.join(','), // Store as comma-separated string
    };
  }

  factory ConsumableType.fromMap(Map<String, dynamic> map) {
    return ConsumableType(
      id: map['id'],
      name: map['name'],
      defaultLifespanDays: map['default_lifespan_days'],
      isFixedLifespan: map['is_fixed_lifespan'] == 1,
      managesStock: map['manages_stock'] == 1, // Default to true if null for old data
      notificationOffsetsInMinutes: map['notification_offsets_in_minutes'] != null && (map['notification_offsets_in_minutes'] as String).isNotEmpty
          ? (map['notification_offsets_in_minutes'] as String)
              .split(',')
              .where((e) => e.isNotEmpty) // Filter out empty strings
              .map((e) => int.tryParse(e)) // Use tryParse to handle invalid integers
              .whereType<int>() // Filter out nulls from tryParse
              .toList()
          : null,
    );
  }

  @override
  String toString() {
    return 'ConsumableType{id: $id, name: $name, defaultLifespanDays: $defaultLifespanDays, isFixedLifespan: $isFixedLifespan, managesStock: $managesStock}';
  }
}
