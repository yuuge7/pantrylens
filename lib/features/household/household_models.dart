import 'dart:convert';

class Home {
  final String id;
  final String name;
  final List<String> locations;
  const Home({
    required this.id,
    required this.name,
    this.locations = const [
      'Pantry',
      'Fridge',
      'Freezer',
      'Wine cellar',
      'Garage',
    ],
  });
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'locations': jsonEncode(locations),
  };
  factory Home.fromMap(Map<String, Object?> m) => Home(
    id: m['id'] as String,
    name: m['name'] as String,
    locations: (jsonDecode(m['locations'] as String) as List).cast<String>(),
  );
}

class HouseholdRecord {
  final int? id;
  final String kind;
  final String homeId;
  final Map<String, dynamic> data;
  const HouseholdRecord({
    this.id,
    required this.kind,
    required this.homeId,
    required this.data,
  });
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'kind': kind,
    'homeId': homeId,
    'data': jsonEncode(data),
  };
  factory HouseholdRecord.fromMap(Map<String, Object?> m) => HouseholdRecord(
    id: m['id'] as int?,
    kind: m['kind'] as String,
    homeId: m['homeId'] as String,
    data: jsonDecode(m['data'] as String) as Map<String, dynamic>,
  );
}

class Activity {
  final int? id;
  final String homeId;
  final String actor;
  final String action;
  final String name;
  final num quantity;
  final String unit;
  final num value;
  final DateTime at;

  /// Null on pre-v5 history, whose cause cannot be reconstructed reliably.
  final String? wasteReason;
  static const wasteReasons = ['expired', 'spoiled', 'other'];
  const Activity({
    this.id,
    required this.homeId,
    required this.actor,
    required this.action,
    required this.name,
    required this.quantity,
    required this.unit,
    this.value = 0,
    required this.at,
    this.wasteReason,
  });
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'homeId': homeId,
    'actor': actor,
    'action': action,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'value': value,
    'at': at.toIso8601String(),
    'wasteReason': wasteReason,
  };
  factory Activity.fromMap(Map<String, Object?> m) => Activity(
    id: m['id'] as int?,
    homeId: m['homeId'] as String,
    actor: m['actor'] as String,
    action: m['action'] as String,
    name: m['name'] as String,
    quantity: m['quantity'] as num,
    unit: m['unit'] as String,
    value: m['value'] as num,
    at: DateTime.parse(m['at'] as String),
    wasteReason: m['wasteReason'] as String?,
  );
}
