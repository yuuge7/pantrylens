class PantryInsights {
  const PantryInsights({
    required this.wastedValue,
    required this.expiredLoss,
    required this.unclassifiedWaste,
    required this.months,
    required this.mostUsed,
    required this.mostWasted,
  });
  final num wastedValue;
  final num expiredLoss;
  final num unclassifiedWaste;
  final List<Map<String, Object?>> months;
  final List<Map<String, Object?>> mostUsed;
  final List<Map<String, Object?>> mostWasted;
}
