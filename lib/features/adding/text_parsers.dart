/// Only suggests dates. The user always reviews the result before saving.
List<DateTime> parseExpiryDates(String text) {
  final result = <DateTime>[];
  void add(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (y < 2000 || y > 2100) return;
    final date = DateTime(y, m, d);
    if (date.year == y &&
        date.month == m &&
        date.day == d &&
        !result.contains(date))
      result.add(date);
  }

  for (final match in RegExp(
    r'\b(\d{4})[./-](\d{1,2})[./-](\d{1,2})\b',
  ).allMatches(text)) {
    add(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }
  for (final match in RegExp(
    r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{4}|\d{2})\b',
  ).allMatches(text)) {
    add(int.parse(match[3]!), int.parse(match[2]!), int.parse(match[1]!));
    // Ambiguous packages can use either order; show both for review.
    if (match[1] != match[2])
      add(int.parse(match[3]!), int.parse(match[1]!), int.parse(match[2]!));
  }
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  for (final match in RegExp(
    r'\b(\d{1,2})\s+([a-z]{3})[a-z]*\s+(\d{4}|\d{2})\b',
    caseSensitive: false,
  ).allMatches(text)) {
    final m = months.indexOf(match[2]!.toLowerCase());
    if (m >= 0) add(int.parse(match[3]!), m + 1, int.parse(match[1]!));
  }
  return result;
}

class ReceiptLine {
  final String name;
  final num quantity;
  final num unitPrice;
  const ReceiptLine(this.name, this.quantity, this.unitPrice);
}

List<ReceiptLine> parseReceipt(String text) {
  final lines = <ReceiptLine>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (RegExp(
      r'\b(total|subtotal|tax|vat|tva|change|cash|card|payment|receipt|discount|balance|thank)\b',
      caseSensitive: false,
    ).hasMatch(line))
      continue;
    final match = RegExp(
      r'^(.+?)[\s|]+(?:[€$£]|EUR|RON|USD)?\s*(\d+[.,]\d{2})\s*(?:[€$£]|EUR|RON|USD)?\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) continue;
    var name = match[1]!.trim();
    if (!RegExp(r'[a-zA-ZÀ-ž]').hasMatch(name)) continue;
    num qty = 1;
    final prefix = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*[x×]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(name);
    if (prefix != null) {
      qty = num.parse(prefix[1]!.replaceAll(',', '.'));
      name = prefix[2]!;
    }
    if (qty <= 0) continue;
    final total = num.parse(match[2]!.replaceAll(',', '.'));
    lines.add(ReceiptLine(name, qty, total / qty));
  }
  return lines;
}
