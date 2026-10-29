import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../services/error_reporter.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<String> _log = ErrorReporter.readLog();
  bool _busy = false;
  String? _status;
  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    await ErrorReporter.capture(
      StateError('PantryLens diagnostic check (intentional, non-fatal)'),
      StackTrace.current,
    );
    if (mounted)
      setState(() {
        _busy = false;
        _status =
            Sentry.isEnabled
                ? 'Diagnostic check recorded locally and handed to Sentry. Confirm delivery in your Sentry project.'
                : 'Diagnostic check recorded on this device.';
        _log = ErrorReporter.readLog();
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diagnostics')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          Sentry.isEnabled
              ? 'Local diagnostics and Sentry reporting are enabled.'
              : 'Errors are recorded on this device. Remote reporting is not configured.',
        ),
        const SizedBox(height: 8),
        const Text(
          'The check button adds an intentional test entry to the log below.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _check,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(_busy ? 'Recording check…' : 'Run diagnostic check'),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(liveRegion: true, child: Text(_status!)),
          ),
        const SizedBox(height: 24),
        Text(
          'Recent diagnostic entries',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        FutureBuilder<String>(
          future: _log,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LinearProgressIndicator(
                semanticsLabel: 'Loading diagnostic log',
              );
            if (snapshot.hasError)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The diagnostic log could not be read. Check available storage and retry.',
                  ),
                  TextButton(
                    onPressed:
                        () => setState(() => _log = ErrorReporter.readLog()),
                    child: const Text('Retry log'),
                  ),
                ],
              );
            return SelectableText(snapshot.data ?? 'No errors recorded.');
          },
        ),
      ],
    ),
  );
}
