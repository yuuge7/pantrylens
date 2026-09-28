import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../pantry_actions.dart';
import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import '../widgets/freshness_label.dart';
import '../widgets/message_state.dart';
import '../widgets/product_image.dart';
import 'inventory_tab.dart';

/// Overview: what needs using up, what was added lately, what to buy.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onOpenInventory,
    required this.onOpenShopping,
    required this.onScan,
  });

  final ValueChanged<InventoryFilter> onOpenInventory;
  final VoidCallback onOpenShopping;
  final VoidCallback onScan;

  static const int _previewLength = 4;

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final useSoonDays = context.select<SettingsProvider, int>(
      (settings) => settings.useSoonDays,
    );

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
          icon: Icons.kitchen_outlined,
          title: 'Your pantry is empty',
          message: 'Scan a product barcode to start your inventory.',
          actionLabel: 'Scan your first item',
          actionIcon: Icons.qr_code_scanner_rounded,
          onAction: onScan,
          secondaryLabel: 'Type a barcode instead',
          onSecondary: () => addBarcodeManually(context),
        ),
      );
    }

    final items = pantry.items;
    final expiring =
        items
            .where((item) => freshnessOf(item, useSoonDays) != Freshness.fresh)
            .toList()
          ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    final expiredCount =
        expiring
            .where(
              (item) => freshnessOf(item, useSoonDays) == Freshness.expired,
            )
            .length;
    final useSoonCount = expiring.length - expiredCount;
    final recent = [...items]..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    final toBuy =
        pantry.shoppingItems.where((entry) => !entry.isChecked).toList();

    return RefreshIndicator(
      onRefresh: pantry.loadItems,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          _Overview(
            productCount: items.length,
            unitCount: pantry.totalUnits,
            useSoonCount: useSoonCount,
            expiredCount: expiredCount,
            onOpenInventory: onOpenInventory,
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Use soon',
            actionLabel:
                expiring.length > _previewLength
                    ? 'See all ${expiring.length}'
                    : null,
            onAction: () => onOpenInventory(InventoryFilter.useSoon),
          ),
          if (expiring.isEmpty)
            _QuietNote(
              icon: Icons.eco_outlined,
              text: 'Nothing expires in the next $useSoonDays days.',
            )
          else
            _ItemGroup(
              items: expiring.take(_previewLength).toList(),
              useSoonDays: useSoonDays,
            ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Recently added',
            actionLabel: 'See all',
            onAction: () {
              context.read<SettingsProvider>().inventorySort =
                  InventorySort.recent;
              onOpenInventory(InventoryFilter.all);
            },
          ),
          _ItemGroup(
            items: recent.take(_previewLength).toList(),
            useSoonDays: useSoonDays,
          ),
          if (toBuy.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionHeader(title: 'To buy'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                leading: const Icon(Icons.shopping_basket_outlined),
                title: Text(
                  toBuy.length == 1
                      ? '1 item on your list'
                      : '${toBuy.length} items on your list',
                ),
                subtitle: Text(
                  toBuy.map((entry) => entry.name).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onOpenShopping,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.productCount,
    required this.unitCount,
    required this.useSoonCount,
    required this.expiredCount,
    required this.onOpenInventory,
  });

  final int productCount;
  final int unitCount;
  final int useSoonCount;
  final int expiredCount;
  final ValueChanged<InventoryFilter> onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.freshness;

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stat(
              value: productCount,
              label: productCount == 1 ? 'product' : 'products',
              detail: unitCount == 1 ? '1 unit' : '$unitCount units',
              onTap: () => onOpenInventory(InventoryFilter.all),
            ),
            const VerticalDivider(width: 1, indent: 16, endIndent: 16),
            _Stat(
              value: useSoonCount,
              label: 'use soon',
              color: useSoonCount > 0 ? palette.useSoon : null,
              onTap: () => onOpenInventory(InventoryFilter.useSoon),
            ),
            const VerticalDivider(width: 1, indent: 16, endIndent: 16),
            _Stat(
              value: expiredCount,
              label: 'expired',
              color: expiredCount > 0 ? palette.expired : null,
              onTap: () => onOpenInventory(InventoryFilter.expired),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.onTap,
    this.detail,
    this.color,
  });

  final int value;
  final String label;
  final String? detail;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = this.detail;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color ?? theme.colorScheme.onSurfaceVariant,
                  fontWeight: color == null ? null : FontWeight.w600,
                ),
              ),
              if (detail != null)
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.freshness.fresh),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemGroup extends StatelessWidget {
  const _ItemGroup({required this.items, required this.useSoonDays});

  final List<PantryItem> items;
  final int useSoonDays;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            _CompactItemRow(item: items[i], useSoonDays: useSoonDays),
          ],
        ],
      ),
    );
  }
}

class _CompactItemRow extends StatelessWidget {
  const _CompactItemRow({required this.item, required this.useSoonDays});

  final PantryItem item;
  final int useSoonDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => openItemSheet(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ProductImage(imageUrl: item.imageUrl, size: 44),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FreshnessLabel(item: item, useSoonDays: useSoonDays),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '×${item.quantity}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
