import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Persistent bounded diagnostics, independent of optional remote reporting.
class ErrorReporter {
  static const dsn = String.fromEnvironment('SENTRY_DSN');
  static const _separator = '\n\n---\n\n';
  static const _maxCharacters = 96 * 1024;
  static Future<void> _writes = Zone.root.run(() => Future<void>.value());

  static void configure(SentryOptions options) {
    options.dsn = dsn;
    options.sendDefaultPii = false;
    options.beforeSend = (event, hint) async {
      // SDK-captured crashes also reach the local log. Manually reported errors
      // already have a local copy and must not be sent/logged twice.
      if (event.tags?['capture_origin'] != 'app') {
        await recordLocal(
          'Unhandled error ${event.throwable ?? event.exceptions?.map((e) => '${e.type}: ${e.value}').join('; ') ?? event.message?.formatted ?? event.eventId}',
        );
      }
      return event;
    };
  }

  static Future<String> readLog() async {
    await _writes;
    final file = File(
      '${(await getApplicationSupportDirectory()).path}/diagnostics.log',
    );
    if (!await file.exists()) return 'No errors recorded.';
    final handle = await file.open();
    try {
      final size = await handle.length();
      await handle.setPosition(
        size > _maxCharacters ? size - _maxCharacters : 0,
      );
      return utf8.decode(
        await handle.read(_maxCharacters),
        allowMalformed: true,
      );
    } finally {
      await handle.close();
    }
  }

  static Future<void> recordLocal(String message) {
    debugPrint(message);
    final job = Zone.root.run(
      () => _writes.then((_) async {
        try {
          final dir = await getApplicationSupportDirectory();
          await dir.create(recursive: true);
          final file = File('${dir.path}/diagnostics.log');
          var previous = '';
          if (await file.exists()) {
            final handle = await file.open();
            try {
              final size = await handle.length();
              await handle.setPosition(
                size > _maxCharacters ? size - _maxCharacters : 0,
              );
              previous = utf8.decode(
                await handle.read(_maxCharacters),
                allowMalformed: true,
              );
            } finally {
              await handle.close();
            }
          }
          final entries = <String>[
            ...previous.split(_separator).where((s) => s.isNotEmpty),
            '${DateTime.now().toIso8601String()} ${message.length > 12000 ? message.substring(0, 12000) : message}',
          ];
          while (entries.length > 50 ||
              entries.join(_separator).length > _maxCharacters) {
            entries.removeAt(0);
          }
          await file.writeAsString(entries.join(_separator), flush: true);
        } catch (error) {
          debugPrint('Diagnostic log unavailable: $error');
        }
      }),
    );
    _writes = job;
    return job;
  }

  static Future<void> capture(Object error, StackTrace stack) async {
    final local = recordLocal('${error.runtimeType}: $error\n$stack');
    // Remote capture still runs when storage is full or unavailable.
    if (Sentry.isEnabled) {
      try {
        await Sentry.captureException(
          error,
          stackTrace: stack,
          withScope: (scope) => scope.setTag('capture_origin', 'app'),
        );
      } catch (reportingError) {
        debugPrint('Remote diagnostics unavailable: $reportingError');
      }
    }
    await local;
  }
}
