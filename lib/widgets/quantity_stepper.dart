import 'package:flutter/material.dart';
import '../pantry_item.dart';

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

  final num quantity;
  final ValueChanged<num> onChanged;
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
    const density = VisualDensity.standard;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
            child: Semantics(
              label: 'Quantity ${formatAmount(quantity)}',
              excludeSemantics: true,
              child: AnimatedSwitcher(
                duration:
                    MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                child: Text(
                  formatAmount(quantity),
                  key: ValueKey(formatAmount(quantity)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
