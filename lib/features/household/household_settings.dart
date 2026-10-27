import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pantry_actions.dart';
import '../../settings_provider.dart';
import '../../services/error_reporter.dart';
import '../../services/reminder_service.dart';
import '../insights/insights_screen.dart';
import 'household_screen.dart';
import 'offline_photos_screen.dart';
import 'diagnostics_screen.dart';

class HouseholdSettings extends StatelessWidget {
  const HouseholdSettings({super.key});
  Future<void> _text(
    BuildContext context,
    String key,
    String title,
    String value,
  ) async {
    final controller = TextEditingController(text: value);
    final settings = context.read<SettingsProvider>();
    final answer = await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty)
                    Navigator.pop(c, controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (answer != null) await settings.setExtra(key, answer);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<void> _time(
    BuildContext context,
    String key,
    int hour, {
    int minute = 0,
    bool minutes = false,
  }) async {
    final settings = context.read<SettingsProvider>();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (time != null) {
      await settings.setExtra(key, time.hour);
      if (minutes) await settings.setExtra('reminderMinute', time.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    String time(int h, [int m = 0]) =>
        TimeOfDay(hour: h, minute: m).format(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('Homes & household'),
          subtitle: const Text(
            'Locations, staff tasks, guests, events and activity',
          ),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HouseholdScreen()),
              ),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Your name in activity'),
          subtitle: Text(s.actorName),
          onTap: () => _text(context, 'actorName', 'Your name', s.actorName),
        ),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Currency'),
          subtitle: Text(s.currency),
          onTap: () => _text(context, 'currency', 'Currency label', s.currency),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Usage & waste'),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.offline_pin_outlined),
          title: const Text('Offline photos'),
          subtitle: const Text('Check saved photos and retry downloads'),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflinePhotosScreen()),
              ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Expiry reminders'),
          subtitle: const Text('Local reminders for all homes'),
          value: s.remindersEnabled,
          onChanged: (v) async {
            try {
              if (v && !await ReminderService.instance.requestPermission()) {
                if (context.mounted)
                  showMessage(
                    context,
                    'Notifications are off. Enable PantryLens notifications in your device settings, then try again.',
                  );
                return;
              }
              await s.setExtra('remindersEnabled', v);
            } catch (e, stack) {
              await ErrorReporter.capture(e, stack);
              if (context.mounted)
                showMessage(
                  context,
                  'Reminders could not be enabled. Try again.',
                );
            }
          },
        ),
        if (s.remindersEnabled) ...[
          SwitchListTile(
            title: const Text('Daily digest'),
            subtitle: Text(
              s.dailyDigest
                  ? 'One summary of batches to use soon'
                  : 'Individual reminders the day before expiry',
            ),
            value: s.dailyDigest,
            onChanged: (v) => s.setExtra('dailyDigest', v),
          ),
          ListTile(
            title: const Text('Reminder time'),
            subtitle: Text(time(s.reminderHour, s.reminderMinute)),
            onTap:
                () => _time(
                  context,
                  'reminderHour',
                  s.reminderHour,
                  minute: s.reminderMinute,
                  minutes: true,
                ),
          ),
          ListTile(
            title: const Text('Quiet hours start'),
            subtitle: Text(time(s.quietStart)),
            onTap: () => _time(context, 'quietStart', s.quietStart),
          ),
          ListTile(
            title: const Text('Quiet hours end'),
            subtitle: Text(time(s.quietEnd)),
            onTap: () => _time(context, 'quietEnd', s.quietEnd),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Reminders in quiet hours move to the end of quiet hours. Matching start and end times disable quiet hours. Schedules refresh when the pantry changes or you reopen the app.',
            ),
          ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.widgets_outlined),
          title: const Text('Home screen widgets'),
          subtitle: const Text(
            'Add Use soon or Shopping from your device’s widget picker. Open PantryLens to refresh; the widget shows its last update time.',
          ),
          onTap:
              () => showDialog(
                context: context,
                builder:
                    (c) => AlertDialog(
                      title: const Text('Add a PantryLens widget'),
                      content: const Text(
                        'Touch and hold your home screen, choose Widgets and find PantryLens. Choose Use soon or Shopping, then drag it onto your home screen. Touch and hold a placed widget to resize it.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
              ),
        ),
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: const Text('Replay introduction'),
          onTap: () => s.setExtra('onboardingComplete', false),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Diagnostics'),
          subtitle: Text(
            ErrorReporter.dsn.isEmpty
                ? 'Errors are logged on this device'
                : 'Local diagnostics and Sentry reporting enabled',
          ),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              ),
        ),
      ],
    );
  }
}
