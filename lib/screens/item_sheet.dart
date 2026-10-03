import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import '../widgets/freshness_label.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/sheet_parts.dart';

enum ItemSheetAction { delete }

/// Edits one pantry item. Pops with [ItemSheetAction.delete] when the user
/// chooses to delete it, so the caller can offer Undo.
class ItemSheet extends StatefulWidget {
  const ItemSheet({super.key, required this.itemId, required this.initialItem});

  final int? itemId;
  final PantryItem initialItem;

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  late final TextEditingController _name = TextEditingController(
    text: _item.name,
  );
  late int _quantity = _item.quantity;
  late DateTime _expirationDate = _item.expirationDate;
  late final PantryItem _item = _latestItem();
  bool _isSaving = false;
  bool _isAddingToList = false;
  String? _error;

  PantryItem _latestItem() {
    for (final item in context.read<PantryProvider>().items) {
      if (item.id == widget.itemId) return item;
    }
    return widget.initialItem;
  }

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
      _name.text.trim() != _item.name ||
      _quantity != _item.quantity ||
      !DateUtils.isSameDay(_expirationDate, _item.expirationDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Best before',
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<PantryProvider>().updateItem(
        _item.copyWith(
          name: name,
          quantity: _quantity,
          expirationDate: _expirationDate,
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

  Future<void> _addToShoppingList() async {
    setState(() {
      _isAddingToList = true;
      _error = null;
    });
    try {
      await context.read<PantryProvider>().addShoppingItem(
        _name.text.trim().isEmpty ? _item.name : _name.text.trim(),
        barcode: _item.barcode,
        imageUrl: _item.imageUrl,
      );
    } catch (_) {
      if (mounted) _error = 'Shopping list not updated. Try again.';
    }
    if (mounted) setState(() => _isAddingToList = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final useSoonDays = context.select<SettingsProvider, int>(
      (settings) => settings.useSoonDays,
    );
    final onShoppingList = context.select<PantryProvider, bool>(
      (pantry) => pantry.shoppingItems.any(
        (entry) => !entry.isChecked && entry.barcode == _item.barcode,
      ),
    );
    final draft = _item.copyWith(expirationDate: _expirationDate);
    final canSave = _hasChanges && _name.text.trim().isNotEmpty && !_isSaving;
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
              name: _item.name,
              imageUrl: _item.imageUrl,
              barcode: _item.barcode,
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
                errorText:
                    _name.text.trim().isEmpty ? 'Enter a product name' : null,
              ),
            ),
            const SizedBox(height: 12),
            FieldRow(
              label: 'Quantity',
              child: QuantityStepper(
                quantity: _quantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
            ),
            const Divider(height: 1),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: FieldRow(
                label: 'Best before',
                detail: FreshnessLabel(
                  item: draft,
                  useSoonDays: useSoonDays,
                  relative: true,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(_expirationDate),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit_calendar_outlined, color: colors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canSave ? _save : null,
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
                        onShoppingList || _isAddingToList
                            ? null
                            : _addToShoppingList,
                    icon: Icon(
                      onShoppingList
                          ? Icons.playlist_add_check_rounded
                          : Icons.add_shopping_cart_rounded,
                    ),
                    label: Text(
                      onShoppingList ? 'On shopping list' : 'Add to list',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    onPressed:
                        () => Navigator.of(context).pop(ItemSheetAction.delete),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete item'),
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
