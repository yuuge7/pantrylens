import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'pantry_provider.dart';
import 'screens/home_shell.dart';
import 'settings_provider.dart';
import 'services/error_reporter.dart';
import 'services/platform_sync.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  const traceStartup = bool.fromEnvironment('PROFILE_STARTUP');
  final startup = Stopwatch()..start();
  void markStartup(String step) {
    if (traceStartup)
      debugPrint(
        'PantryLens startup: $step at ${startup.elapsedMilliseconds} ms',
      );
  }

  markStartup('Dart entry');
  WidgetsFlutterBinding.ensureInitialized();
  // Load preferences before the first frame so the chosen theme never flashes.
  final settings = await SettingsProvider.load();
  markStartup('Preferences ready');
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      ErrorReporter.capture(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(ErrorReporter.capture(error, stack));
    return true;
  };
  final pantry = PantryProvider()..actor = settings.actorName;
  markStartup('Provider started');
  final sync = PlatformSync(pantry, settings);
  var homeRestored = false;
  pantry.addListener(() {
    if (!pantry.isLoading && !homeRestored) {
      homeRestored = true;
      pantry.selectHome(settings.homeId);
    }
  });
  void launch() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => markStartup('First frame'),
    );
    runApp(
      _AppLifetime(
        sync: sync,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: pantry),
          ],
          child: const MyApp(),
        ),
      ),
    );
  }

  if (ErrorReporter.dsn.isNotEmpty) {
    await SentryFlutter.init((o) {
      o.dsn = ErrorReporter.dsn;
      o.sendDefaultPii = false;
    }, appRunner: launch);
  } else {
    launch();
  }
}

class _AppLifetime extends StatefulWidget {
  const _AppLifetime({required this.sync, required this.child});
  final PlatformSync sync;
  final Widget child;
  @override
  State<_AppLifetime> createState() => _AppLifetimeState();
}

class _AppLifetimeState extends State<_AppLifetime> {
  @override
  void dispose() {
    widget.sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (settings) => settings.themeMode,
    );

    return MaterialApp(
      title: 'PantryLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home:
          context.watch<SettingsProvider>().onboardingComplete
              ? const HomeShell()
              : const OnboardingScreen(),
    );
  }
}
