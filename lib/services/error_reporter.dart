import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Always keeps a bounded local diagnostic log; remote capture requires a DSN.
class ErrorReporter {
  static const dsn = String.fromEnvironment('SENTRY_DSN');
  static final recent = <String>[];
  static Future<void> capture(Object error, StackTrace stack) async {
    final line =
        '${DateTime.now().toIso8601String()} ${error.runtimeType}: $error\n$stack';
    recent.add(line);
    if (recent.length > 50) recent.removeAt(0);
    debugPrint(line);
    try {
      final dir = await getApplicationSupportDirectory();
      await File(
        '${dir.path}/diagnostics.log',
      ).writeAsString(recent.join('\n\n'), flush: true);
      if (dsn.isNotEmpty)
        await Sentry.captureException(error, stackTrace: stack);
    } catch (loggingError) {
      debugPrint('Diagnostic log unavailable: $loggingError');
    }
  }
}
