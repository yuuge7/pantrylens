import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../pantry_actions.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  static String _describeDays(int days) {
    return switch (days) {
      7 => '1 week',
      14 => '2 weeks',
      30 => '1 month',
      90 => '3 months',
      180 => '6 months',
      365 => '1 year',
      1 => '1 day',
      _ => '$days days',
    };
  }

  Future<void> _pickDays({
    required String title,
    required List<int> options,
    required int current,
    required ValueChanged<int> onSelected,
  }) async {
    final selected = await showDialog<int>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: Text(title),
            children: [
              for (final days in options)
                ListTile(
                  title: Text(_describeDays(days)),
                  selected: days == current,
                  trailing:
                      days == current ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.of(context).pop(days),
                ),
            ],
          ),
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    required String doneMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await action();
      if (mounted) showMessage(context, doneMessage);
    } catch (_) {
      if (mounted) showMessage(context, 'Nothing was deleted. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final pantry = context.watch<PantryProvider>();
    final theme = Theme.of(context);
    final itemCount = pantry.items.length;
    final listCount = pantry.shoppingItems.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const _SectionHeader('Appearance'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) {
              settings.themeMode = selection.first;
            },
          ),
        ),
        const _SectionHeader('Inventory'),
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: const Text('Default best-before'),
          subtitle: Text(
            'New items expire ${_describeDays(settings.shelfLifeDays)} '
            'after scanning',
          ),
          onTap:
              () => _pickDays(
                title: 'Default best-before',
                options: SettingsProvider.shelfLifeOptions,
                current: settings.shelfLifeDays,
                onSelected: (days) => settings.shelfLifeDays = days,
              ),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Use-soon warning'),
          subtitle: Text(
            'Flag items ${_describeDays(settings.useSoonDays)} before '
            'they expire',
          ),
          onTap:
              () => _pickDays(
                title: 'Use-soon warning',
                options: SettingsProvider.useSoonOptions,
                current: settings.useSoonDays,
                onSelected: (days) => settings.useSoonDays = days,
              ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.playlist_add_rounded),
          title: const Text('Auto-add to shopping list'),
          subtitle: const Text('When you mark an item as used up'),
          value: settings.addUsedUpToShoppingList,
          onChanged: (value) => settings.addUsedUpToShoppingList = value,
        ),
        const _SectionHeader('Scanning'),
        SwitchListTile(
          secondary: const Icon(Icons.travel_explore_rounded),
          title: const Text('Look up product details'),
          subtitle: const Text(
            'Get names and photos from Open Food Facts. Needs internet.',
          ),
          value: settings.lookUpProducts,
          onChanged: (value) => settings.lookUpProducts = value,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.burst_mode_outlined),
          title: const Text('Keep scanning'),
          subtitle: const Text(
            'Stay on the camera after each item to add several in a row',
          ),
          value: settings.keepScanning,
          onChanged: (value) => settings.keepScanning = value,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.vibration_rounded),
          title: const Text('Vibrate on scan'),
          value: settings.vibrateOnScan,
          onChanged: (value) => settings.vibrateOnScan = value,
        ),
        const _SectionHeader('Data'),
        ListTile(
          leading: const Icon(Icons.remove_shopping_cart_outlined),
          title: const Text('Clear shopping list'),
          subtitle: Text(listCount == 1 ? '1 entry' : '$listCount entries'),
          enabled: listCount > 0,
          onTap:
              () => _confirmAndRun(
                title: 'Clear shopping list?',
                message:
                    'All $listCount entries will be removed. This can’t be '
                    'undone.',
                confirmLabel: 'Clear list',
                action: pantry.clearShoppingList,
                doneMessage: 'Shopping list cleared',
              ),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: itemCount > 0 ? theme.colorScheme.error : null,
          ),
          title: Text(
            'Delete all pantry items',
            style: TextStyle(
              color: itemCount > 0 ? theme.colorScheme.error : null,
            ),
          ),
          subtitle: Text(itemCount == 1 ? '1 item' : '$itemCount items'),
          enabled: itemCount > 0,
          onTap:
              () => _confirmAndRun(
                title: 'Delete all pantry items?',
                message:
                    'All $itemCount items and their quantities will be '
                    'removed from this device. This can’t be undone.',
                confirmLabel: 'Delete all',
                action: pantry.clearInventory,
                doneMessage: 'Pantry cleared',
              ),
        ),
        const _SectionHeader('About'),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: const Text('PantryLens'),
              subtitle: Text(
                info == null
                    ? 'Local-first pantry inventory'
                    : 'Version ${info.version} (${info.buildNumber})',
              ),
            );
          },
        ),
        const ListTile(
          leading: Icon(Icons.lock_outline_rounded),
          title: Text('Your data stays on this device'),
          subtitle: Text(
            'Only new barcodes are sent to Open Food Facts, and only when '
            'product lookup is on.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.public_rounded),
          title: Text('Product data'),
          subtitle: Text(
            'Open Food Facts, available under the Open Database License',
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
