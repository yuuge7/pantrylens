import 'dart:io';
import 'package:home_widget/home_widget.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';

class WidgetService {
  static const appGroup = 'group.com.pantrylens.pantrylens';
  static Future<void> sync(
    PantryProvider pantry,
    SettingsProvider settings,
  ) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroup);
    final soon =
        pantry.items
            .where((i) => i.daysUntilExpiry() <= settings.useSoonDays)
            .toList()
          ..sort((a, b) => a.effectiveExpiry.compareTo(b.effectiveExpiry));
    final shopping = pantry.shoppingItems.where((i) => !i.isChecked).toList();
    await HomeWidget.saveWidgetData<String>('home', pantry.selectedHomeName);
    await HomeWidget.saveWidgetData<String>(
      'useSoon',
      soon
          .take(5)
          .map(
            (i) =>
                '${i.name} · ${i.amountLabel}\n${i.location} · ${i.daysUntilExpiry() < 0 ? 'Expired' : '${i.daysUntilExpiry()} days left'}',
          )
          .join('\n\n'),
    );
    await HomeWidget.saveWidgetData<String>(
      'shopping',
      shopping
          .take(6)
          .map((i) => '☐ ${i.name} · ${i.quantity} ${i.unit}')
          .join('\n'),
    );
    await HomeWidget.saveWidgetData<String>(
      'updated',
      'Updated ${DateTime.now().toLocal().toString().substring(0, 16)}',
    );
    await HomeWidget.updateWidget(
      androidName: 'PantryWidgetProvider',
      iOSName: 'PantryLensWidget',
    );
    await HomeWidget.updateWidget(
      androidName: 'ShoppingWidgetProvider',
      iOSName: 'PantryLensShoppingWidget',
    );
  }
}
