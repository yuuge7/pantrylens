import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_provider.dart';
import 'home_tab.dart';
import 'inventory_tab.dart';
import 'scanner_screen.dart';
import 'settings_tab.dart';
import 'shopping_tab.dart';
import '../features/adding/document_scan_screen.dart';
import '../features/household/household_screen.dart';
import '../features/insights/insights_screen.dart';
import 'item_sheet.dart';
import '../settings_provider.dart';

enum AppTab { home, inventory, shopping, settings }

/// The app frame: one scaffold with bottom navigation between the tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;
  final Set<AppTab> _visited = {AppTab.home};
  InventoryFilter _inventoryFilter = InventoryFilter.all;

  void _selectTab(AppTab tab) {
    if (tab == _tab) return;
    FocusScope.of(context).unfocus();
    if (context.read<SettingsProvider>().vibrateOnScan)
      HapticFeedback.selectionClick();
    setState(() {
      _visited.add(tab);
      _tab = tab;
    });
  }

  void _openInventory(InventoryFilter filter) {
    setState(() {
      _inventoryFilter = filter;
      _visited.add(AppTab.inventory);
      _tab = AppTab.inventory;
    });
  }

  Future<void> _openScanner() async {
    final outcome = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute<ScanOutcome>(builder: (_) => const ScannerScreen()),
    );
    if (outcome != null && mounted) showScanOutcome(context, outcome);
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return switch (_tab) {
      AppTab.home => AppBar(
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PantryLens',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              context.watch<PantryProvider>().selectedHomeName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          const HomeSelector(),
          IconButton(
            tooltip: 'Usage & waste',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                ),
            icon: const Icon(Icons.insights_outlined),
          ),
          _addMenu(context),
          const SizedBox(width: 8),
        ],
      ),
      AppTab.inventory => AppBar(
        title: const Text('Inventory'),
        actions: [
          const HomeSelector(),
          _addMenu(context),
          const InventorySortButton(),
          const InventoryMenuButton(),
        ],
      ),
      AppTab.shopping => AppBar(
        title: const Text('Shopping list'),
        actions: const [HomeSelector()],
      ),
      AppTab.settings => AppBar(title: const Text('Settings')),
    };
  }

  Widget _addMenu(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Add to pantry',
    icon: const Icon(Icons.add_circle_outline),
    onSelected: (action) {
      switch (action) {
        case 'manual':
          openNewBatch(context);
        case 'barcode':
          addBarcodeManually(context);
        case 'receipt':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DocumentScanScreen()),
          );
      }
    },
    itemBuilder:
        (_) => const [
          PopupMenuItem(value: 'manual', child: Text('Add a batch')),
          PopupMenuItem(value: 'barcode', child: Text('Enter barcode')),
          PopupMenuItem(value: 'receipt', child: Text('Scan receipt')),
        ],
  );

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final showScanButton =
        (_tab == AppTab.home || _tab == AppTab.inventory) &&
        pantry.items.isNotEmpty;
    final toBuy = pantry.shoppingItemsToBuy;

    final wide = MediaQuery.sizeOf(context).width >= 840;
    final tabs = IndexedStack(
      index: _tab.index,
      children: [
        HomeTab(
          onOpenInventory: _openInventory,
          onOpenShopping: () => _selectTab(AppTab.shopping),
          onScan: _openScanner,
        ),
        if (_visited.contains(AppTab.inventory))
          InventoryTab(
            filter: _inventoryFilter,
            onFilterChanged:
                (filter) => setState(() => _inventoryFilter = filter),
            onScan: _openScanner,
          )
        else
          const SizedBox.shrink(),
        if (_visited.contains(AppTab.shopping))
          const ShoppingTab()
        else
          const SizedBox.shrink(),
        if (_visited.contains(AppTab.settings))
          const SettingsTab()
        else
          const SizedBox.shrink(),
      ],
    );
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(AppTab.home);
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: SafeArea(
          bottom: false,
          child:
              wide
                  ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _tab.index,
                        onDestinationSelected:
                            (n) => _selectTab(AppTab.values[n]),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            label: Text('Home'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.inventory_2_outlined),
                            label: Text('Inventory'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.shopping_basket_outlined),
                            label: Text('Shopping'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            label: Text('Settings'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: tabs),
                    ],
                  )
                  : tabs,
        ),
        floatingActionButton:
            showScanButton
                ? FloatingActionButton.extended(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan item'),
                )
                : null,
        bottomNavigationBar:
            wide
                ? null
                : NavigationBar(
                  selectedIndex: _tab.index,
                  onDestinationSelected:
                      (index) => _selectTab(AppTab.values[index]),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Inventory',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: toBuy > 0,
                        label: Text('$toBuy'),
                        child: const Icon(Icons.shopping_basket_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: toBuy > 0,
                        label: Text('$toBuy'),
                        child: const Icon(Icons.shopping_basket),
                      ),
                      label: 'Shopping',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
      ),
    );
  }
}
