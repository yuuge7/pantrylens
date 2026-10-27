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
  // A month-only best-before date means the end of that calendar month.
  for (final match in RegExp(
    r'(?<![\d./-])(\d{1,2})[./-](\d{4})(?![\d./-])',
  ).allMatches(text)) {
    final m = int.parse(match[1]!);
    final y = int.parse(match[2]!);
    if (m >= 1 && m <= 12) add(y, m, DateTime(y, m + 1, 0).day);
  }
  for (final match in RegExp(
    r'\b([a-z]{3})[a-z]*\s+(\d{4})\b',
    caseSensitive: false,
  ).allMatches(text)) {
    if (RegExp(r'\d\s*$').hasMatch(text.substring(0, match.start))) continue;
    final m = months.indexOf(match[1]!.toLowerCase()) + 1;
    final y = int.parse(match[2]!);
    if (m > 0) add(y, m, DateTime(y, m + 1, 0).day);
  }
  return result;
}

class ReceiptLine {
  final String name;
  final num quantity;
  final num unitPrice;
  final String unit;
  const ReceiptLine(
    this.name,
    this.quantity,
    this.unitPrice, {
    this.unit = 'pieces',
  });
}

// Receipt prices use both decimal conventions, often with thousands separators.
num? _receiptNumber(String raw) {
  var value = raw.replaceAll(RegExp(r'[\s\u00a0]'), '');
  final decimal = value.lastIndexOf(RegExp(r'[.,]'));
  if (decimal >= 0) {
    value =
        '${value.substring(0, decimal).replaceAll(RegExp(r'[.,]'), '')}.${value.substring(decimal + 1)}';
  }
  return num.tryParse(value);
}

List<ReceiptLine> parseReceipt(String text) {
  final result = <ReceiptLine>[];
  String? pendingName;
  final summary = RegExp(
    r'^\s*(?:grand\s+total|sub\s*total|total|tax|vat|tva|mwst|ust|summe|gesamt|suma|rest|change|cash|card|carte|payment|paid|receipt|bon\s+fiscal|discount|reducere|balance|thank|merci|multum|mulțum|tel\b|cui\b|cif\b|date\b|data\b|address\b|www\.)',
    caseSensitive: false,
  );
  final priceAtEnd = RegExp(
    r'(?:[€$£]|EUR|RON|LEI|USD|GBP)?\s*(\d+(?:[.,\s\u00a0]\d{3})*[.,]\d{2})\s*(?:[€$£]|EUR|RON|LEI|USD|GBP)?\s*(?:[A-DP*]|[A-D]\s*\d{1,2}%?)?\s*$',
    caseSensitive: false,
  );
  final quantityLine = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|pcs?|pieces|buc|bottle)?\s*[@x×*]\s*(?:[€$£]|EUR|RON|LEI|USD|GBP)?\s*(\d+[.,]\d{2})(?:\s*(?:/\s*(?:kg|g|l|ml|pcs?|buc)))?',
    caseSensitive: false,
  );
  String unitFor(String? unit) => switch (unit?.toLowerCase()) {
    'kg' || 'g' || 'ml' || 'l' || 'bottle' => unit!.toLowerCase(),
    _ => 'pieces',
  };
  bool hasName(String name) => RegExp(r'\p{L}', unicode: true).hasMatch(name);
  for (final raw in text.split('\n').take(2000)) {
    final line = raw.trim().replaceAll(RegExp(r'[\t|]+'), ' ');
    if (line.isEmpty) continue;
    if (summary.hasMatch(line)) {
      pendingName = null;
      continue;
    }
    final qtyLine = quantityLine.firstMatch(line);
    final price = priceAtEnd.firstMatch(line);
    if (qtyLine != null) {
      final qty = _receiptNumber(qtyLine[1]!);
      final each = _receiptNumber(qtyLine[3]!);
      if (qty == null || qty <= 0 || each == null) continue;
      final unit = unitFor(qtyLine[2]);
      // A second price is the line total; a lone price is the unit price.
      final total =
          price != null && price.start >= qtyLine.end
              ? _receiptNumber(price[1]!)
              : null;
      if (pendingName != null) {
        result.add(
          ReceiptLine(
            pendingName,
            qty,
            total == null ? each : total / qty,
            unit: unit,
          ),
        );
        pendingName = null;
      } else if (result.isNotEmpty) {
        // Many tills put the multiplication detail beneath an already priced item.
        final previous = result.removeLast();
        result.add(
          ReceiptLine(
            previous.name,
            qty,
            total == null
                ? previous.quantity * previous.unitPrice / qty
                : total / qty,
            unit: unit,
          ),
        );
      }
      continue;
    }
    if (price == null) {
      if (hasName(line) && !RegExp(r'^[-=\d\s/:.]+$').hasMatch(line))
        pendingName = line;
      continue;
    }
    var name = line.substring(0, price.start).trim();
    final total = _receiptNumber(price[1]!);
    if (total == null || total < 0 || name.endsWith('-')) continue;
    num qty = 1;
    var unit = 'pieces';
    final prefix = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|pcs?|pieces|buc|bottle)?\s*[x×*]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(name);
    final suffix = RegExp(
      r'\s+(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|pcs?|pieces|buc|bottle)?\s*[@x×*]\s*(?:[€$£])?\s*\d+[.,]\d{2}(?:\s*/\s*(?:kg|g|l|ml))?\s*$',
      caseSensitive: false,
    ).firstMatch(name);
    if (prefix != null) {
      qty = _receiptNumber(prefix[1]!) ?? 1;
      unit = unitFor(prefix[2]);
      name = prefix[3]!.trim();
    } else if (suffix != null) {
      qty = _receiptNumber(suffix[1]!) ?? 1;
      unit = unitFor(suffix[2]);
      name = name.substring(0, suffix.start).trim();
    }
    if (name.isEmpty && pendingName != null) name = pendingName;
    pendingName = null;
    if (qty <= 0 || !hasName(name)) continue;
    result.add(ReceiptLine(name, qty, total / qty, unit: unit));
  }
  return result;
}
