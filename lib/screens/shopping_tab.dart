import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_provider.dart';
import '../shopping_item.dart';
import '../widgets/message_state.dart';

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

  void _remove(ShoppingItem item) {
    final pantry = context.read<PantryProvider>();
    pantry.removeShoppingItem(item).catchError((Object _) {});
    showMessage(
      context,
      'Removed ${item.name}',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          pantry.restoreShoppingItem(item).catchError((Object _) {});
        },
      ),
    );
  }

  void _setChecked(ShoppingItem item, bool isChecked) {
    context
        .read<PantryProvider>()
        .setShoppingItemChecked(item, isChecked)
        .catchError((Object _) {
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
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final item in toBuy) _tile(item),
                      if (toBuy.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
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
                        for (final item in checked) _tile(item),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _tile(ShoppingItem item) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('shopping-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(item),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: item.isChecked,
        onChanged: (value) => _setChecked(item, value ?? false),
        title: Text(
          item.name,
          style:
              item.isChecked
                  ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                  : null,
        ),
      ),
    );
  }
}
