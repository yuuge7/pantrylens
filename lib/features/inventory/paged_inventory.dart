import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pantry_actions.dart';
import '../../pantry_item.dart';
import '../../pantry_provider.dart';
import '../../settings_provider.dart';
import '../../screens/inventory_tab.dart';
import '../../screens/item_sheet.dart';
import '../../widgets/product_image.dart';
import '../../widgets/freshness_label.dart';
import '../../services/error_reporter.dart';

class PagedInventory extends StatefulWidget {
  const PagedInventory({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onScan,
  });
  final InventoryFilter filter;
  final ValueChanged<InventoryFilter> onFilterChanged;
  final VoidCallback onScan;
  @override
  State<PagedInventory> createState() => _PagedInventoryState();
}

class _PagedInventoryState extends State<PagedInventory> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<PantryItem> _rows = [];
  String? _location, _category;
  String? _error;
  String _signature = '';
  bool _busy = false, _more = true;
  int _generation = 0;
  int? _selected;
  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 220), _reset);
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 500 && !_busy && _more) _fetch();
    });
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  @override
  void didUpdateWidget(PagedInventory old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _reset();
  }

  void _check() {
    final p = context.watch<PantryProvider>();
    final s = context.watch<SettingsProvider>();
    final sig =
        '${p.revision}|${p.selectedHomeId}|${s.inventorySort}|${s.useSoonDays}';
    if (sig != _signature) {
      _signature = sig;
      _reset();
    }
  }

  void _reset() {
    _generation++;
    _more = true;
    _busy = false;
    _fetch(replace: true);
  }

  Future<void> _fetch({bool replace = false}) async {
    final generation = _generation;
    _busy = true;
    _error = null;
    final p = context.read<PantryProvider>();
    final s = context.read<SettingsProvider>();
    // Never set state from didChangeDependencies; the awaited query yields first.
    try {
      final rows = await p.data.getItemsPage(
        offset: replace ? 0 : _rows.length,
        homeId: p.selectedHomeId,
        query: _search.text.trim(),
        location: _location,
        category: _category,
        filter: widget.filter.name,
        useSoonDays: s.useSoonDays,
        sort: s.inventorySort.name,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (replace) _rows.clear();
        _rows.addAll(rows);
        _more = rows.length == 60;
        _busy = false;
      });
    } catch (e, s) {
      unawaited(ErrorReporter.capture(e, s));
      if (mounted && generation == _generation)
        setState(() {
          _busy = false;
          _error = 'Inventory could not be loaded. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final settings = context.watch<SettingsProvider>();
    final useSoon =
        pantry.items
            .where((i) => i.daysUntilExpiry() <= settings.useSoonDays)
            .length;
    final expired = pantry.items.where((i) => i.daysUntilExpiry() < 0).length;
    final selected = pantry.items.where((i) => i.id == _selected).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search inventory',
              hintText: 'Name, barcode or tag',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Clear search',
                onPressed: _search.clear,
                icon: const Icon(Icons.close),
              ),
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (filter, label) in [
                (InventoryFilter.all, 'All ${pantry.items.length}'),
                (InventoryFilter.useSoon, 'Use soon $useSoon'),
                (InventoryFilter.expired, 'Expired $expired'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: widget.filter == filter,
                    onSelected: (_) => widget.onFilterChanged(filter),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Filter by storage location',
                onSelected: (v) {
                  setState(() => _location = v.isEmpty ? null : v);
                  _reset();
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: '',
                        child: Text('All locations'),
                      ),
                      for (final l in pantry.locations)
                        PopupMenuItem(value: l, child: Text(l)),
                    ],
                child: Chip(
                  avatar: const Icon(Icons.kitchen_outlined, size: 18),
                  label: Text(_location ?? 'All locations'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Filter by category',
                onSelected: (v) {
                  setState(() => _category = v.isEmpty ? null : v);
                  _reset();
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: '',
                        child: Text('All categories'),
                      ),
                      for (final c in PantryItem.categories)
                        PopupMenuItem(value: c, child: Text(c)),
                    ],
                child: Chip(label: Text(_category ?? 'All categories')),
              ),
            ],
          ),
        ),
        if (_busy && _rows.isEmpty) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await pantry.loadItems();
              _reset();
            },
            child:
                _rows.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 52),
                        const SizedBox(height: 16),
                        Text(
                          _error ??
                              (pantry.items.isEmpty
                                  ? 'Your pantry is ready for its first batch'
                                  : 'No batches match these filters'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed:
                              _error == null
                                  ? () => openNewBatch(context)
                                  : _reset,
                          child: Text(
                            _error == null ? 'Add a batch' : 'Try again',
                          ),
                        ),
                        if (_error == null)
                          TextButton(
                            onPressed: widget.onScan,
                            child: const Text('Scan an item'),
                          ),
                      ],
                    )
                    : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                      itemCount: _rows.length + 1,
                      itemBuilder: (context, n) {
                        if (n == _rows.length)
                          return _error != null
                              ? TextButton(
                                onPressed: _fetch,
                                child: const Text('Retry loading more'),
                              )
                              : _more
                              ? TextButton(
                                onPressed: _busy ? null : _fetch,
                                child: Text(_busy ? 'Loading…' : 'Load more'),
                              )
                              : const SizedBox(height: 16);
                        final item = _rows[n];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InventoryTile(
                            key: ValueKey(item.id),
                            item: item,
                            useSoonDays: settings.useSoonDays,
                            onOpen:
                                wide
                                    ? () => setState(() => _selected = item.id)
                                    : null,
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
    if (!wide) return list;
    return Row(
      children: [
        Expanded(flex: 3, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child:
              selected == null
                  ? const Center(
                    child: Text('Select a batch to see its details'),
                  )
                  : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ProductImage(
                          imageUrl: selected.imageUrl,
                          size: 120,
                          viewerTitle: selected.name,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        selected.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('${selected.amountLabel} · ${selected.location}'),
                      FreshnessLabel(
                        item: selected,
                        useSoonDays: settings.useSoonDays,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => openItemSheet(context, selected),
                        child: const Text('Edit batch'),
                      ),
                      OutlinedButton(
                        onPressed:
                            () => openNewBatch(context, product: selected),
                        child: const Text('Add another batch'),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}
