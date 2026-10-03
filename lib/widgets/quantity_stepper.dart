import 'package:flutter/material.dart';

/// A compact minus / count / plus control.
///
/// When [onUseUp] is set, the minus button becomes a "used up" button at a
/// quantity of one instead of disabling.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.onUseUp,
    this.itemName,
    this.compact = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final VoidCallback? onUseUp;

  /// Used in button tooltips so screen readers know which item is affected.
  final String? itemName;

  /// Shrinks the buttons, for rows that hold other controls as well.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canUseUp = quantity <= 1 && onUseUp != null;
    final suffix = itemName == null ? '' : ' of $itemName';
    final density = compact ? VisualDensity.compact : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: density,
            tooltip: canUseUp ? 'Mark$suffix as used up' : 'Remove one$suffix',
            onPressed:
                canUseUp
                    ? onUseUp
                    : quantity > 1
                    ? () => onChanged(quantity - 1)
                    : null,
            icon: Icon(
              canUseUp ? Icons.delete_outline_rounded : Icons.remove_rounded,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 22),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            visualDensity: density,
            tooltip: 'Add one$suffix',
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
