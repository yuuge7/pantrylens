import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_provider.dart';
import '../shopping_item.dart';
import '../widgets/message_state.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_stepper.dart';

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
  final _entry = TextEditingController();
  final _entryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _entry.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _entry.dispose();
    _entryFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _entry.text.trim();
    if (name.isEmpty) return;
    final pantry = context.read<PantryProvider>();
    try {
      final added = await pantry.addShoppingItem(name);
      if (!mounted) return;
      if (added) {
        _entry.clear();
        _entryFocus.requestFocus();
      } else {
        showMessage(context, '$name is already on your list');
      }
    } catch (_) {
      if (mounted) showMessage(context, '$name was not added. Try again.');
    }
  }

  void _update(ShoppingItem item) {
    context.read<PantryProvider>().updateShoppingItem(item).catchError((
      Object _,
    ) {
      if (mounted) showMessage(context, 'List not updated. Try again.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final toBuy = pantry.shoppingItems.where((item) => !item.isChecked);
    final checked = pantry.shoppingItems.where((item) => item.isChecked);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _entry,
                  focusNode: _entryFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  onTapOutside: (_) => _entryFocus.unfocus(),
                  decoration: const InputDecoration(
                    hintText: 'Add an item',
                    prefixIcon: Icon(Icons.add_shopping_cart_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add to list',
                onPressed: _entry.text.trim().isEmpty ? null : _add,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              pantry.shoppingItems.isEmpty
                  ? const MessageState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Your list is clear',
                    message:
                        'Items you mark as used up land here. Add anything '
                        'else with the field above.',
                  )
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final item in toBuy) _tile(item, pantry),
                      if (toBuy.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                          child: Text(
                            'Nothing left to buy.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (checked.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 0, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'In the basket · ${checked.length}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  pantry.clearCheckedShoppingItems().catchError(
                                    (Object _) {},
                                  );
                                },
                                child: const Text('Clear basket'),
                              ),
                            ],
                          ),
                        ),
                        for (final item in checked) _tile(item, pantry),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _tile(ShoppingItem item, PantryProvider pantry) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inPantry = pantry.pantryItemFor(item);
    final inStock = inPantry?.quantity ?? 0;

    return Padding(
      key: ValueKey('shopping-tile-${item.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('shopping-${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => removeShoppingItemWithUndo(context, item),
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
                'Remove',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.delete_outline_rounded,
                color: colors.onErrorContainer,
              ),
            ],
          ),
        ),
        child: Card(
          child: InkWell(
            onTap: () => openShoppingItemSheet(context, item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 8, 10),
              child: Row(
                children: [
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: item.isChecked,
                    semanticLabel: item.name,
                    onChanged:
                        (value) =>
                            _update(item.copyWith(isChecked: value ?? false)),
                  ),
                  Opacity(
                    opacity: item.isChecked ? 0.5 : 1,
                    child: ProductImage(
                      imageUrl: item.imageUrl ?? inPantry?.imageUrl,
                      size: 48,
                      viewerTitle: item.name,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            color:
                                item.isChecked ? colors.onSurfaceVariant : null,
                            decoration:
                                item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inStock == 0
                              ? 'None in pantry'
                              : '$inStock in pantry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.isChecked)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '×${item.quantity}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  else
                    QuantityStepper(
                      compact: true,
                      quantity: item.quantity,
                      itemName: item.name,
                      onChanged:
                          (value) => _update(item.copyWith(quantity: value)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
