import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pantry_provider.dart';
import '../../settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  bool _busy = false;
  String? _error;
  Future<void> _finish({bool sample = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (sample) await context.read<PantryProvider>().loadSamplePantry();
      if (mounted)
        await context.read<SettingsProvider>().setExtra(
          'onboardingComplete',
          true,
        );
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = 'Could not set up your pantry. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      (
        Icons.kitchen_outlined,
        'Know what is in your kitchen',
        'Keep every batch, amount and best-before date together. Separate your fridge, freezer and pantry, across every home.',
      ),
      (
        Icons.document_scanner_outlined,
        'Add it once, use it in time',
        'Scan barcodes, read printed dates or photograph a receipt. Camera access is requested when you choose to scan; you can always add items by hand.',
      ),
      (
        Icons.people_outline,
        'A household that runs together',
        'Plan restocks, remember guest preferences and shop for your next dinner. Your inventory stays on this device. Turn on reminders in Settings.',
      ),
    ];
    final p = pages[_page];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(32),
              children: [
                Icon(
                  p.$1,
                  size: 88,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(p.$2, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(p.$3, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Step ${_page + 1} of 3',
                  child: Text('${_page + 1} / 3'),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed:
                      _busy
                          ? null
                          : _page < 2
                          ? () => setState(() => _page++)
                          : _finish,
                  child: Text(_page < 2 ? 'Continue' : 'Start my pantry'),
                ),
                if (_page == 2)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _finish(sample: true),
                    child: const Text('Explore a sample pantry'),
                  ),
                if (_page > 0)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _page--),
                    child: const Text('Back'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
