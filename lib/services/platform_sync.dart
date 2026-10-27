import 'dart:async';
import 'package:flutter/widgets.dart';
import '../pantry_provider.dart';
import '../settings_provider.dart';
import 'error_reporter.dart';
import 'reminder_service.dart';
import 'widget_service.dart';
import 'photo_cache.dart';

/// Debounces database changes and refreshes local-date dependent surfaces.
class PlatformSync with WidgetsBindingObserver {
  PlatformSync(this.pantry, this.settings) {
    pantry.addListener(changed);
    settings.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    changed();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (_day != now.day) {
        _day = now.day;
        pantry.loadItems();
      }
    });
  }
  final PantryProvider pantry;
  final SettingsProvider settings;
  Timer? _timer;
  Timer? _clock;
  int _day = DateTime.now().day;
  Future<void> _work = Future.value();
  void changed() {
    pantry.actor = settings.actorName;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      _work = _work.then((_) async {
        if (pantry.isLoading) return;
        try {
          await ReminderService.instance.sync(pantry.allItems, settings);
          await WidgetService.sync(pantry, settings);
        } catch (e, s) {
          await ErrorReporter.capture(e, s);
        }
        unawaited(
          PhotoCache.instance.sync([
            ...pantry.allItems.map((i) => i.imageUrl),
            ...pantry.allShoppingItems.map((i) => i.imageUrl),
          ]),
        );
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      pantry.loadItems();
      changed();
    }
  }

  void dispose() {
    _timer?.cancel();
    _clock?.cancel();
    pantry.removeListener(changed);
    settings.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
  }
}
