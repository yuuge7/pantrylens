import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../pantry_item.dart';
import '../../pantry_provider.dart';
import '../../settings_provider.dart';
import '../../services/error_reporter.dart';
import 'text_parsers.dart';

class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key, this.expiryOnly = false});
  final bool expiryOnly;
  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  List<DateTime> _dates = [];
  List<ReceiptLine> _lines = [];
  final Set<int> _excluded = {};
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _dates = parseExpiryDates(_text.text);
      _lines = parseReceipt(_text.text);
      _excluded.clear();
    });
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final recognizer = TextRecognizer();
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null) return;
      final result = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      if (!mounted) return;
      _text.text = result.text;
      _parse();
      if (result.text.trim().isEmpty)
        _error = 'No text found. Try a sharper photo or type the text below.';
    } catch (e, s) {
      await ErrorReporter.capture(e, s);
      if (mounted)
        _error =
            'Could not read the photo. Allow camera access or choose a photo from your library.';
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final pantry = context.read<PantryProvider>();
    final days = context.read<SettingsProvider>().shelfLifeDays;
    final chosen =
        _lines.indexed
            .where((e) => !_excluded.contains(e.$1))
            .map((e) => e.$2)
            .toList();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await pantry.addBatches([
        for (final (n, line) in chosen.indexed)
          PantryItem(
            barcode: 'receipt-${now.microsecondsSinceEpoch}-$n',
            name: line.name,
            quantity: line.quantity,
            price: line.unitPrice,
            homeId: pantry.selectedHomeId ?? 'main',
            expirationDate: DateTime(now.year, now.month, now.day + days),
          ),
      ]);
      if (mounted) Navigator.pop(context);
    } catch (e, s) {
      await ErrorReporter.capture(e, s);
      if (mounted)
        setState(
          () =>
              _error =
                  'Receipt was not saved. Review the entries and try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.expiryOnly ? 'Read best-before date' : 'Scan receipt'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.expiryOnly
                ? 'Photograph the printed date. Check the suggested date before using it.'
                : 'Photograph a receipt, then review each line. Prices and quantities may need correcting.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _scan(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Recognized text',
              hintText: 'You can also paste or type text here',
            ),
            onChanged: (_) => _parse(),
          ),
          const SizedBox(height: 16),
          if (widget.expiryOnly) ...[
            if (_dates.isEmpty)
              const Text(
                'No complete date found. Try DD/MM/YYYY or choose the date manually in the batch editor.',
              ),
            for (final date in _dates)
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  MaterialLocalizations.of(context).formatFullDate(date),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, date),
              ),
          ] else ...[
            Text('Review items', style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'Edit the text above to correct an item. Uncheck lines you do not want to add.',
            ),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No priced items yet. Example: 2 x Milk 3.60'),
              ),
            for (final (n, line) in _lines.indexed)
              CheckboxListTile(
                value: !_excluded.contains(n),
                onChanged:
                    (v) => setState(() {
                      v == true ? _excluded.remove(n) : _excluded.add(n);
                    }),
                title: Text(line.name),
                subtitle: Text(
                  '${formatAmount(line.quantity)} pieces · ${line.unitPrice.toStringAsFixed(2)} each',
                ),
              ),
            FilledButton(
              onPressed:
                  _busy || _lines.length == _excluded.length ? null : _save,
              child: Text('Add ${_lines.length - _excluded.length} items'),
            ),
          ],
        ],
      ),
    ),
  );
}
