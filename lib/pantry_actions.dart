import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'pantry_item.dart';
import 'pantry_provider.dart';
import 'screens/item_sheet.dart';
import 'settings_provider.dart';

/// UI flows shared by several tabs. Each one captures what it needs from
/// [context] before its first await.

void showMessage(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  showSnack(ScaffoldMessenger.of(context), message, action: action);
}

/// Replaces any visible snack bar. Bars with an action still time out;
/// Flutter otherwise keeps them on screen until dismissed.
void showSnack(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        persist: false,
        duration: Duration(seconds: action == null ? 4 : 6),
      ),
    );
}

String describeScanOutcome(ScanOutcome outcome) {
  final item = outcome.item;
  final text =
      outcome.isNew
          ? 'Added ${item.name}'
          : '${item.name}: ${item.quantity} in pantry';
  return outcome.checkedOffShoppingList
      ? '$text · checked off your shopping list'
      : text;
}

void showScanOutcome(BuildContext context, ScanOutcome outcome) {
  showMessage(
    context,
    describeScanOutcome(outcome),
    action: SnackBarAction(
      label: 'Edit',
      onPressed: () => openItemSheet(context, outcome.item),
    ),
  );
}

Future<void> openItemSheet(BuildContext context, PantryItem item) async {
  final action = await showModalBottomSheet<ItemSheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ItemSheet(itemId: item.id, initialItem: item),
  );
  if (action == ItemSheetAction.delete && context.mounted) {
    final latest = context.read<PantryProvider>().items.where(
      (existing) => existing.id == item.id,
    );
    await removeItemWithUndo(
      context,
      latest.isEmpty ? item : latest.first,
      usedUp: false,
    );
  }
}

Future<void> changeQuantity(
  BuildContext context,
  PantryItem item,
  int quantity,
) async {
  final pantry = context.read<PantryProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await pantry.updateItem(item.copyWith(quantity: quantity));
  } catch (_) {
    showSnack(messenger, 'Quantity not saved. Try again.');
  }
}

/// Removes [item] with an Undo action. Used-up items can also be added to
/// the shopping list, depending on settings.
Future<void> removeItemWithUndo(
  BuildContext context,
  PantryItem item, {
  required bool usedUp,
}) async {
  final pantry = context.read<PantryProvider>();
  final addToList =
      usedUp && context.read<SettingsProvider>().addUsedUpToShoppingList;
  final messenger = ScaffoldMessenger.of(context);

  try {
    final removed = await pantry.removeItem(item, addToShoppingList: addToList);
    final text =
        usedUp
            ? removed.shoppingItemId != null
                ? '${item.name} used up · added to shopping list'
                : '${item.name} used up'
            : 'Deleted ${item.name}';
    showSnack(
      messenger,
      text,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          pantry.restoreItem(removed).catchError((Object _) {
            showSnack(messenger, '${item.name} was not restored.');
          });
        },
      ),
    );
  } catch (_) {
    showSnack(messenger, '${item.name} was not removed. Try again.');
  }
}

/// Asks for a barcode and adds it, for damaged labels or missing cameras.
Future<void> addBarcodeManually(BuildContext context) async {
  final barcode = await showBarcodeDialog(context);
  if (barcode == null || !context.mounted) return;

  final pantry = context.read<PantryProvider>();
  final settings = context.read<SettingsProvider>();
  try {
    final outcome = await pantry.onBarcodeScanned(
      barcode,
      shelfLifeDays: settings.shelfLifeDays,
      lookUpProduct: settings.lookUpProducts,
    );
    if (outcome == null || !context.mounted) return;
    if (settings.vibrateOnScan) HapticFeedback.mediumImpact();
    showScanOutcome(context, outcome);
  } catch (_) {
    if (!context.mounted) return;
    showMessage(context, 'Barcode $barcode was not saved. Try again.');
  }
}

Future<String?> showBarcodeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _BarcodeDialog(),
  );
}

class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();

  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter barcode'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        // The dialog shares the filled-field color, so outline this field.
        decoration: const InputDecoration(
          filled: false,
          border: OutlineInputBorder(),
          hintText: 'Digits under the barcode',
          prefixIcon: Icon(Icons.pin_outlined),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder:
              (context, value, _) => FilledButton(
                onPressed: value.text.trim().isEmpty ? null : _submit,
                child: const Text('Add item'),
              ),
        ),
      ],
    );
  }
}
