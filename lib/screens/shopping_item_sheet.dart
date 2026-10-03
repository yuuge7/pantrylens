import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../shopping_item.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/sheet_parts.dart';
import 'item_sheet.dart';

/// Edits one shopping list entry. Pops with [ItemSheetAction.delete] when the
/// user chooses to remove it, so the caller can offer Undo.
class ShoppingItemSheet extends StatefulWidget {
  const ShoppingItemSheet({super.key, required this.item});

  final ShoppingItem item;

  @override
  State<ShoppingItemSheet> createState() => _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends State<ShoppingItemSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item.name,
  );
  late int _quantity = widget.item.quantity;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _name.text.trim() != widget.item.name ||
      _quantity != widget.item.quantity;

  /// Saves the edited name and quantity, along with [isChecked] when given.
  Future<void> _save({bool? isChecked}) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<PantryProvider>().updateShoppingItem(
        widget.item.copyWith(
          name: name,
          quantity: _quantity,
          isChecked: isChecked,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Changes not saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = widget.item;
    final inPantry = context.select<PantryProvider, PantryItem?>(
      (pantry) => pantry.pantryItemFor(item),
    );
    final inStock = inPantry?.quantity ?? 0;
    final hasName = _name.text.trim().isNotEmpty;
    final error = _error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProductHeader(
              name: item.name,
              imageUrl: item.imageUrl ?? inPantry?.imageUrl,
              barcode: item.barcode,
            ),
            const SizedBox(height: 20),
            Text('Name', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Product name',
                errorText: hasName ? null : 'Enter a product name',
              ),
            ),
            const SizedBox(height: 12),
            FieldRow(
              label: 'Quantity to buy',
              detail: Text(
                inStock == 0 ? 'None in pantry' : '$inStock in pantry',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              child: QuantityStepper(
                quantity: _quantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _hasChanges && hasName && !_isSaving ? _save : null,
              child: Text(_isSaving ? 'Saving…' : 'Save changes'),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        hasName && !_isSaving
                            ? () => _save(isChecked: !item.isChecked)
                            : null,
                    icon: Icon(
                      item.isChecked
                          ? Icons.undo_rounded
                          : Icons.shopping_basket_outlined,
                    ),
                    label: Text(item.isChecked ? 'Back to list' : 'In basket'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    onPressed:
                        () => Navigator.of(context).pop(ItemSheetAction.delete),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
