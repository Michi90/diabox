class ActiveConsumable {
  int? id;
  int consumableTypeId;
  DateTime startDate;
  DateTime expectedEndDate;
  DateTime? deactivationDate; // New field
  int isActive; // 1 for active, 0 for used/inactive

  ActiveConsumable({
    this.id,
    required this.consumableTypeId,
    required this.startDate,
    required this.expectedEndDate,
    this.deactivationDate,
    this.isActive = 1, // Default to active
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consumable_type_id': consumableTypeId,
      'start_date': startDate.toIso8601String(),
      'expected_end_date': expectedEndDate.toIso8601String(),
      'deactivation_date': deactivationDate?.toIso8601String(), // Store as ISO 8601 String
      'is_active': isActive,
    };
  }

  factory ActiveConsumable.fromMap(Map<String, dynamic> map) {
    return ActiveConsumable(
      id: map['id'],
      consumableTypeId: map['consumable_type_id'],
      startDate: DateTime.parse(map['start_date']),
      expectedEndDate: DateTime.parse(map['expected_end_date']),
      deactivationDate: map['deactivation_date'] != null
          ? DateTime.parse(map['deactivation_date'])
          : null,
      isActive: map['is_active'] ?? 1, // Default to 1 if null
    );
  }

  @override
  String toString() {
    return 'ActiveConsumable{id: $id, consumableTypeId: $consumableTypeId, startDate: $startDate, expectedEndDate: $expectedEndDate, deactivationDate: $deactivationDate, isActive: $isActive}';
  }
}
