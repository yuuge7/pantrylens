class PantryInsights {
  const PantryInsights({
    required this.wastedValue,
    required this.months,
    required this.mostUsed,
  });
  final num wastedValue;
  final List<Map<String, Object?>> months;
  final List<Map<String, Object?>> mostUsed;
}
