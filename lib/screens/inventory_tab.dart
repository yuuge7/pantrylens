import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import '../widgets/freshness_label.dart';
import '../features/inventory/paged_inventory.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

enum InventoryFilter { all, useSoon, expired }

class InventoryTab extends StatelessWidget {
  const InventoryTab({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onScan,
  });
  final InventoryFilter filter;
  final ValueChanged<InventoryFilter> onFilterChanged;
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => PagedInventory(
    filter: filter,
    onFilterChanged: onFilterChanged,
    onScan: onScan,
  );
}

class InventoryTile extends StatelessWidget {
  const InventoryTile({
    super.key,
    required this.item,
    required this.useSoonDays,
    this.onOpen,
  });

  final PantryItem item;
  final int useSoonDays;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await removeItemWithUndo(context, item, usedUp: false);
        return false;
      },
      background: Container(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: colors.onErrorContainer),
          ],
        ),
      ),
      child: Card(
        child: InkWell(
          onTap: onOpen ?? () => openItemSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                ProductImage(
                  imageUrl: item.imageUrl,
                  size: 60,
                  viewerTitle: item.name,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FreshnessLabel(item: item, useSoonDays: useSoonDays),
                      Text(
                        '${item.location} · ${item.amountLabel}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (context
                          .read<PantryProvider>()
                          .allergyWarnings(item)
                          .isNotEmpty)
                        Text(
                          'Allergy warning',
                          style: TextStyle(color: colors.error),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                QuantityStepper(
                  quantity: item.quantity,
                  compact: true,
                  itemName: item.name,
                  onChanged: (value) => changeQuantity(context, item, value),
                  onUseUp:
                      () => removeItemWithUndo(context, item, usedUp: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App bar menu that orders the inventory list.
class InventorySortButton extends StatelessWidget {
  const InventorySortButton({super.key});

  static const _labels = {
    InventorySort.name: 'Name',
    InventorySort.expiry: 'Best-before date',
    InventorySort.quantity: 'Quantity',
    InventorySort.recent: 'Recently added',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return PopupMenuButton<InventorySort>(
      tooltip: 'Sort by',
      icon: const Icon(Icons.sort_rounded),
      initialValue: settings.inventorySort,
      onSelected: (sort) => settings.inventorySort = sort,
      itemBuilder:
          (context) => [
            for (final sort in InventorySort.values)
              CheckedPopupMenuItem(
                value: sort,
                checked: sort == settings.inventorySort,
                child: Text(_labels[sort]!),
              ),
          ],
    );
  }
}

enum _InventoryMenuAction { export, import }

/// App bar menu for saving the inventory to a file and reading it back.
class InventoryMenuButton extends StatelessWidget {
  const InventoryMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasItems = context.select<PantryProvider, bool>(
      (pantry) => pantry.items.isNotEmpty,
    );
    return PopupMenuButton<_InventoryMenuAction>(
      tooltip: 'More options',
      onSelected:
          (action) => switch (action) {
            _InventoryMenuAction.export => exportInventory(context),
            _InventoryMenuAction.import => importInventory(context),
          },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: _InventoryMenuAction.export,
              enabled: hasItems,
              child: const Text('Export inventory'),
            ),
            const PopupMenuItem(
              value: _InventoryMenuAction.import,
              child: Text('Import inventory'),
            ),
          ],
    );
  }
}
