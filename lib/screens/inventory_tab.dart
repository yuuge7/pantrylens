import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import '../widgets/freshness_label.dart';
import '../widgets/message_state.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

enum InventoryFilter { all, useSoon, expired }

class InventoryTab extends StatefulWidget {
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
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PantryItem> _visibleItems(
    List<PantryItem> items,
    int useSoonDays,
    InventorySort sort,
  ) {
    final query = _search.text.trim().toLowerCase();
    final visible =
        items.where((item) {
          final matchesQuery =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.barcode.contains(query);
          if (!matchesQuery) return false;
          final freshness = freshnessOf(item, useSoonDays);
          return switch (widget.filter) {
            InventoryFilter.all => true,
            InventoryFilter.useSoon => freshness != Freshness.fresh,
            InventoryFilter.expired => freshness == Freshness.expired,
          };
        }).toList();

    int byName(PantryItem a, PantryItem b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    visible.sort(switch (sort) {
      InventorySort.name => byName,
      InventorySort.expiry => (a, b) {
        final order = a.expirationDate.compareTo(b.expirationDate);
        return order != 0 ? order : byName(a, b);
      },
      InventorySort.quantity => (a, b) {
        final order = b.quantity.compareTo(a.quantity);
        return order != 0 ? order : byName(a, b);
      },
      InventorySort.recent => (a, b) => (b.id ?? 0).compareTo(a.id ?? 0),
    });
    return visible;
  }

  void _showAll() {
    _search.clear();
    widget.onFilterChanged(InventoryFilter.all);
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final settings = context.watch<SettingsProvider>();
    final useSoonDays = settings.useSoonDays;

    if (pantry.isLoading && pantry.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = pantry.errorMessage;
    if (errorMessage != null && pantry.items.isEmpty) {
      return MessageState(
        icon: Icons.error_outline_rounded,
        title: 'Pantry unavailable',
        message: errorMessage,
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: pantry.loadItems,
      );
    }

    if (pantry.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: pantry.loadItems,
        child: MessageState(
          icon: Icons.inventory_2_outlined,
          title: 'Nothing in stock',
          message: 'Items you scan show up here with their quantities.',
          actionLabel: 'Scan an item',
          actionIcon: Icons.qr_code_scanner_rounded,
          onAction: widget.onScan,
          secondaryLabel: 'Type a barcode instead',
          onSecondary: () => addBarcodeManually(context),
        ),
      );
    }

    final visible = _visibleItems(
      pantry.items,
      useSoonDays,
      settings.inventorySort,
    );
    final useSoonCount =
        pantry.items
            .where((item) => freshnessOf(item, useSoonDays) != Freshness.fresh)
            .length;
    final expiredCount =
        pantry.items
            .where(
              (item) => freshnessOf(item, useSoonDays) == Freshness.expired,
            )
            .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search by name or barcode',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  _search.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (filter, label) in [
                (InventoryFilter.all, 'All ${pantry.items.length}'),
                (InventoryFilter.useSoon, 'Use soon $useSoonCount'),
                (InventoryFilter.expired, 'Expired $expiredCount'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: widget.filter == filter,
                    onSelected: (_) => widget.onFilterChanged(filter),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: pantry.loadItems,
            child:
                visible.isEmpty
                    ? MessageState(
                      icon: Icons.search_off_rounded,
                      title:
                          _search.text.trim().isEmpty
                              ? 'Nothing here right now'
                              : 'No matching items',
                      message:
                          _search.text.trim().isEmpty
                              ? 'No items fall under this filter.'
                              : 'Try another name or barcode.',
                      actionLabel: 'Show all items',
                      actionIcon: Icons.inventory_2_outlined,
                      onAction: _showAll,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                      itemCount: visible.length,
                      itemBuilder:
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InventoryTile(
                              key: ValueKey(visible[index].id),
                              item: visible[index],
                              useSoonDays: useSoonDays,
                            ),
                          ),
                    ),
          ),
        ),
      ],
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    super.key,
    required this.item,
    required this.useSoonDays,
  });

  final PantryItem item;
  final int useSoonDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => removeItemWithUndo(context, item, usedUp: false),
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
          onTap: () => openItemSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                ProductImage(imageUrl: item.imageUrl, size: 60),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                QuantityStepper(
                  quantity: item.quantity,
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
