import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_provider.dart';
import 'home_tab.dart';
import 'inventory_tab.dart';
import 'scanner_screen.dart';
import 'settings_tab.dart';
import 'shopping_tab.dart';

enum AppTab { home, inventory, shopping, settings }

/// The app frame: one scaffold with bottom navigation between the tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;
  InventoryFilter _inventoryFilter = InventoryFilter.all;

  void _selectTab(AppTab tab) {
    if (tab == _tab) return;
    FocusScope.of(context).unfocus();
    setState(() => _tab = tab);
  }

  void _openInventory(InventoryFilter filter) {
    setState(() {
      _inventoryFilter = filter;
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
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PantryLens', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              'Your pantry, at a glance',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Enter barcode',
            onPressed: () => addBarcodeManually(context),
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      AppTab.inventory => AppBar(
        title: const Text('Inventory'),
        actions: const [InventorySortButton(), SizedBox(width: 8)],
      ),
      AppTab.shopping => AppBar(title: const Text('Shopping list')),
      AppTab.settings => AppBar(title: const Text('Settings')),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final showScanButton =
        (_tab == AppTab.home || _tab == AppTab.inventory) &&
        pantry.items.isNotEmpty;
    final toBuy = pantry.shoppingItemsToBuy;

    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(AppTab.home);
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab.index,
            children: [
              HomeTab(
                onOpenInventory: _openInventory,
                onOpenShopping: () => _selectTab(AppTab.shopping),
                onScan: _openScanner,
              ),
              InventoryTab(
                filter: _inventoryFilter,
                onFilterChanged:
                    (filter) => setState(() => _inventoryFilter = filter),
                onScan: _openScanner,
              ),
              const ShoppingTab(),
              const SettingsTab(),
            ],
          ),
        ),
        floatingActionButton:
            showScanButton
                ? FloatingActionButton.extended(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan item'),
                )
                : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) => _selectTab(AppTab.values[index]),
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
