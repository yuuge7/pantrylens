import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../pantry_item.dart';
import '../settings_provider.dart';

class PlannedReminder {
  final DateTime at;
  final String title;
  final String body;
  const PlannedReminder(this.at, this.title, this.body);
}

DateTime outsideQuietHours(DateTime at, int start, int end) {
  if (start == end) return at; // Equal endpoints disable quiet hours.
  final quiet =
      start > end
          ? at.hour >= start || at.hour < end
          : at.hour >= start && at.hour < end;
  if (!quiet) return at;
  return DateTime(
    at.year,
    at.month,
    at.day + (start > end && at.hour >= start ? 1 : 0),
    end,
  );
}

List<PlannedReminder> planReminders(
  List<PantryItem> items,
  SettingsProvider settings,
  DateTime now,
) {
  if (!settings.remindersEnabled) return [];
  final result = <PlannedReminder>[];
  if (settings.dailyDigest) {
    for (var n = 0; n < 30; n++) {
      final day = DateTime(now.year, now.month, now.day + n);
      final soon =
          items.where((i) {
            final d = i.daysUntilExpiry(day);
            return d >= 0 && d <= settings.useSoonDays;
          }).toList();
      if (soon.isEmpty) continue;
      final at = outsideQuietHours(
        DateTime(
          day.year,
          day.month,
          day.day,
          settings.reminderHour,
          settings.reminderMinute,
        ),
        settings.quietStart,
        settings.quietEnd,
      );
      if (at.isAfter(now))
        result.add(
          PlannedReminder(
            at,
            '${soon.length} ${soon.length == 1 ? 'batch' : 'batches'} to use soon',
            soon.take(4).map((i) => i.name).join(', '),
          ),
        );
    }
  } else {
    for (final item in items) {
      final date = item.effectiveExpiry;
      final at = outsideQuietHours(
        DateTime(
          date.year,
          date.month,
          date.day - 1,
          settings.reminderHour,
          settings.reminderMinute,
        ),
        settings.quietStart,
        settings.quietEnd,
      );
      if (at.isAfter(now))
        result.add(
          PlannedReminder(
            at,
            '${item.name}: best-before reminder',
            '${item.amountLabel} · ${item.location} · ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          ),
        );
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result.take(60).toList(); // Below iOS's 64 pending-notification limit.
}

class ReminderService {
  static final instance = ReminderService();
  final plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> initialize() async {
    if (_initialized || !(Platform.isAndroid || Platform.isIOS)) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(
      tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
    );
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid)
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    if (Platform.isIOS)
      return await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    return false;
  }

  Future<void> sync(List<PantryItem> items, SettingsProvider settings) async {
    await initialize();
    if (!_initialized) return;
    // The timezone may have changed while the application was in background.
    tz.setLocalLocation(
      tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
    );
    await plugin.cancelAllPendingNotifications();
    final plans = planReminders(items, settings, DateTime.now());
    for (final (n, p) in plans.indexed) {
      await plugin.zonedSchedule(
        id: 1000 + n,
        title: p.title,
        body: p.body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          p.at.year,
          p.at.month,
          p.at.day,
          p.at.hour,
          p.at.minute,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry',
            'Expiry reminders',
            channelDescription: 'Food to use before its best-before date',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
