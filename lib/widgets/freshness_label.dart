import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../pantry_item.dart';

enum Freshness { fresh, useSoon, expired }

Freshness freshnessOf(PantryItem item, int useSoonDays) {
  final days = item.daysUntilExpiry();
  if (days < 0) return Freshness.expired;
  if (days <= useSoonDays) return Freshness.useSoon;
  return Freshness.fresh;
}

/// With [relative], far-off dates read "Expires in 45 days" instead of a date.
String describeExpiry(
  PantryItem item,
  BuildContext context, {
  bool relative = false,
}) {
  final days = item.daysUntilExpiry();
  if (days < -1) return 'Expired ${-days} days ago';
  if (days == -1) return 'Expired yesterday';
  if (days == 0) return 'Expires today';
  if (days == 1) return 'Expires tomorrow';
  if (relative || days <= 14) return 'Expires in $days days';
  final date = MaterialLocalizations.of(
    context,
  ).formatShortMonthDay(item.expirationDate);
  return 'Best before $date';
}

/// A leaf that turns amber, then red, as the best-before date approaches.
class FreshnessLabel extends StatelessWidget {
  const FreshnessLabel({
    super.key,
    required this.item,
    required this.useSoonDays,
    this.relative = false,
  });

  final PantryItem item;
  final int useSoonDays;
  final bool relative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.freshness;
    final freshness = freshnessOf(item, useSoonDays);
    final (color, textColor, icon) = switch (freshness) {
      Freshness.fresh => (
        palette.fresh,
        theme.colorScheme.onSurfaceVariant,
        Icons.eco_outlined,
      ),
      Freshness.useSoon => (palette.useSoon, palette.useSoon, Icons.eco),
      Freshness.expired => (
        palette.expired,
        palette.expired,
        Icons.error_outline_rounded,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            describeExpiry(item, context, relative: relative),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight:
                  freshness == Freshness.fresh
                      ? FontWeight.normal
                      : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
