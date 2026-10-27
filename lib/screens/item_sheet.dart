import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../features/adding/document_scan_screen.dart';
import '../pantry_item.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import '../widgets/sheet_parts.dart';
import '../features/insights/waste_dialog.dart';

enum ItemSheetAction { delete }

class ItemSheet extends StatefulWidget {
  const ItemSheet({
    super.key,
    required this.itemId,
    required this.initialItem,
    this.isNew = false,
  });
  final int? itemId;
  final PantryItem initialItem;
  final bool isNew;
  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  final _form = GlobalKey<FormState>();
  late final _item = widget.initialItem;
  late final _name = TextEditingController(text: _item.name);
  late final _barcode = TextEditingController(text: _item.barcode);
  late final _amount = TextEditingController(
    text: formatAmount(_item.quantity),
  );
  late final _tags = TextEditingController(text: _item.tags.join(', '));
  late final _minimum = TextEditingController(
    text: formatAmount(_item.minimumStock),
  );
  late final _price = TextEditingController(text: formatAmount(_item.price));
  late final _store = TextEditingController(text: _item.store);
  late final _after = TextEditingController(
    text: _item.daysAfterOpening?.toString() ?? '3',
  );
  late final _ingredients = TextEditingController(text: _item.ingredients);
  late final _allergens = TextEditingController(
    text: _item.allergens.join(', '),
  );
  late String _home = _item.homeId;
  late String _location = _item.location;
  late String _category = _item.category;
  late String _unit = _item.unit;
  late String? _photo = _item.imageUrl;
  late DateTime _expiry = _item.expirationDate;
  late DateTime? _opened = _item.openedDate;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _amount,
      _tags,
      _minimum,
      _price,
      _store,
      _after,
      _ingredients,
      _allergens,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num? _number(String? text) => num.tryParse((text ?? '').replaceAll(',', '.'));
  String? _positive(String? v) {
    final n = _number(v);
    return n == null || !n.isFinite || n <= 0
        ? 'Enter an amount above 0'
        : null;
  }

  String? _nonnegative(String? v) {
    final n = _number(v);
    return n == null || !n.isFinite || n < 0 ? 'Enter 0 or more' : null;
  }

  List<String> _list(String text) =>
      text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
  Future<void> _pickDate({bool opened = false}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: opened ? _opened ?? DateTime.now() : _expiry,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: opened ? 'Opened on' : 'Best before',
    );
    if (d != null && mounted)
      setState(() {
        if (opened) {
          _opened = d;
        } else {
          _expiry = d;
        }
      });
  }

  Future<void> _photoPicker() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final target = File(
        '${dir.path}/product-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(image.path).copy(target.path);
      if (mounted) setState(() => _photo = target.path);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Photo not saved. Choose another photo and try again.',
        );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final pantry = context.read<PantryProvider>();
    try {
      final draft = _item.copyWith(
        name: _name.text.trim(),
        barcode:
            _barcode.text.trim().isEmpty
                ? 'manual-${DateTime.now().microsecondsSinceEpoch}'
                : _barcode.text.trim(),
        imageUrl: _photo,
        quantity: _number(_amount.text),
        unit: _unit,
        homeId: _home,
        location: _location,
        category: _category,
        tags: _list(_tags.text),
        expirationDate: _expiry,
        openedDate: _opened,
        clearOpened: _opened == null,
        daysAfterOpening: _opened == null ? null : int.parse(_after.text),
        minimumStock: _number(_minimum.text),
        price: _number(_price.text),
        store: _store.text.trim(),
        ingredients: _ingredients.text.trim(),
        allergens: _list(_allergens.text),
      );
      if (widget.isNew) {
        await pantry.addBatch(draft);
      } else {
        await pantry.updateItem(draft);
      }
      if (mounted && context.read<SettingsProvider>().vibrateOnScan)
        await HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = 'Batch not saved. Check the fields and try again.';
        });
    }
  }

  Future<void> _useAmount() async {
    final controller = TextEditingController(
      text: formatAmount(_item.quantity),
    );
    final form = GlobalKey<FormState>();
    final amount = await showDialog<num>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Use stock'),
            content: Form(
              key: form,
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${_item.unit})',
                  helperText: 'Uses the oldest batch in this home first',
                ),
                validator: _positive,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(c, _number(controller.text));
                },
                child: const Text('Record usage'),
              ),
            ],
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<PantryProvider>().useProduct(
        _item.barcode,
        amount,
        homeId: _item.homeId,
        unit: _item.unit,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error =
              'Not enough stock, or usage could not be saved. Check the amount and try again.';
        });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool number = false,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      maxLines: maxLines,
      keyboardType:
          number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      validator: validator,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    ),
  );
  Widget _select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items:
          {
            value,
            ...values,
          }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) {
        if (v != null) setState(() => changed(v));
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final home = pantry.homes.where((h) => h.id == _home).firstOrNull;
    final warnings = pantry.allergyWarnings(
      _item.copyWith(
        homeId: _home,
        ingredients: _ingredients.text,
        allergens: _list(_allergens.text),
      ),
    );
    final dateText = MaterialLocalizations.of(context).formatMediumDate;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isNew)
                Text(
                  'Add a batch',
                  style: Theme.of(context).textTheme.headlineSmall,
                )
              else
                ProductHeader(
                  name: _item.name,
                  imageUrl: _photo,
                  barcode: _item.barcode,
                ),
              const SizedBox(height: 20),
              if (warnings.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Allergy warning: ${warnings.join('; ')}. Check the package label.',
                    ),
                  ),
                ),
              _field(
                _name,
                'Product name',
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Enter a product name'
                            : null,
              ),
              _field(
                _barcode,
                'Barcode',
                hint: 'Optional for manually added items',
              ),
              _field(_amount, 'Amount', number: true, validator: _positive),
              _select('Unit', _unit, PantryItem.units, (v) => _unit = v),
              DropdownButtonFormField<String>(
                initialValue: _home,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Home'),
                items:
                    pantry.homes
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      _home = v;
                      _location =
                          pantry.homes
                              .firstWhere((h) => h.id == v)
                              .locations
                              .first;
                    });
                },
              ),
              const SizedBox(height: 14),
              _select(
                'Storage location',
                _location,
                home?.locations ?? PantryItem.locations,
                (v) => _location = v,
              ),
              _select(
                'Category / store aisle',
                _category,
                PantryItem.categories,
                (v) => _category = v,
              ),
              _field(_tags, 'Tags', hint: 'Breakfast, guest house, organic'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Best before'),
                subtitle: Text(dateText(_expiry)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await Navigator.push<DateTime>(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => const DocumentScanScreen(expiryOnly: true),
                    ),
                  );
                  if (date != null && mounted) setState(() => _expiry = date);
                },
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Read date from package'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Package opened'),
                subtitle: Text(
                  _opened == null ? 'Unopened' : 'Opened ${dateText(_opened!)}',
                ),
                value: _opened != null,
                onChanged:
                    (v) => setState(() => _opened = v ? DateTime.now() : null),
              ),
              if (_opened != null) ...[
                TextButton(
                  onPressed: () => _pickDate(opened: true),
                  child: const Text('Change opened date'),
                ),
                _field(
                  _after,
                  'Use within days after opening',
                  number: true,
                  validator:
                      (v) =>
                          int.tryParse(v ?? '') == null || int.parse(v!) <= 0
                              ? 'Enter a whole number above 0'
                              : null,
                ),
                Text(
                  'Use by ${dateText(_item.copyWith(expirationDate: _expiry, openedDate: _opened, daysAfterOpening: int.tryParse(_after.text) ?? 3).effectiveExpiry)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 14),
              ],
              _field(
                _minimum,
                'Minimum stock ($_unit)',
                number: true,
                validator: _nonnegative,
              ),
              _field(
                _price,
                'Price per $_unit (${context.watch<SettingsProvider>().currency})',
                number: true,
                validator: _nonnegative,
              ),
              _field(_store, 'Store'),
              OutlinedButton.icon(
                onPressed: _photoPicker,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Correct product photo'),
              ),
              ExpansionTile(
                title: const Text('Ingredients, allergens & nutrition'),
                tilePadding: EdgeInsets.zero,
                children: [
                  _field(_ingredients, 'Ingredients', maxLines: 3),
                  _field(_allergens, 'Allergens', hint: 'milk, nuts, gluten'),
                  Text(
                    _item.nutrition.isEmpty
                        ? 'No nutrition data available. Check the package.'
                        : 'Per 100 g: ${_item.nutrition}',
                  ),
                  const Text(
                    'Product data may be incomplete. Always check the package for dietary safety.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Saving…'
                      : widget.isNew
                      ? 'Add batch'
                      : 'Save changes',
                ),
              ),
              if (!widget.isNew) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (navigator.mounted)
                                openNewBatch(navigator.context, product: _item);
                            });
                          },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add another batch'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            setState(() => _busy = true);
                            try {
                              await pantry.addShoppingItem(
                                _name.text,
                                barcode: _item.barcode,
                                imageUrl: _photo,
                                homeId: _home,
                                unit: _unit,
                                aisle: _category,
                                store: _store.text,
                              );
                              if (mounted) Navigator.pop(context);
                            } catch (_) {
                              if (mounted)
                                setState(() {
                                  _busy = false;
                                  _error =
                                      'Could not update the shopping list. Try again.';
                                });
                            }
                          },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to shopping list'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _useAmount,
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Use amount · oldest batch first'),
                ),
                TextButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            final current =
                                pantry.allItems
                                    .where((i) => i.id == _item.id)
                                    .firstOrNull;
                            if (current == null) return;
                            final entry = await askWaste(context, current);
                            if (entry == null || !mounted) return;
                            setState(() => _busy = true);
                            try {
                              await pantry.discardBatch(
                                current,
                                entry.amount,
                                entry.reason,
                              );
                              if (mounted) Navigator.pop(context);
                            } catch (_) {
                              if (mounted)
                                setState(() {
                                  _busy = false;
                                  _error = 'Could not record waste. Try again.';
                                });
                            }
                          },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Record as wasted'),
                ),
                TextButton(
                  onPressed:
                      _busy
                          ? null
                          : () =>
                              Navigator.pop(context, ItemSheetAction.delete),
                  child: const Text('Delete batch'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openNewBatch(BuildContext context, {PantryItem? product}) async {
  final pantry = context.read<PantryProvider>();
  final now = DateTime.now();
  final initial =
      product?.copyWith(
        batchId: 'batch-${now.microsecondsSinceEpoch}',
        quantity: 1,
        clearOpened: true,
      ) ??
      PantryItem(
        barcode: '',
        name: '',
        quantity: 1,
        expirationDate: DateTime(
          now.year,
          now.month,
          now.day + context.read<SettingsProvider>().shelfLifeDays,
        ),
        homeId: pantry.selectedHomeId ?? 'main',
      );
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ItemSheet(itemId: null, initialItem: initial, isNew: true),
  );
}
