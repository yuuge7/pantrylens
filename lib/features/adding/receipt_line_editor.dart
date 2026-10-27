import 'package:flutter/material.dart';
import '../../pantry_item.dart';
import 'text_parsers.dart';

Future<ReceiptLine?> editReceiptLine(BuildContext context, ReceiptLine? line) =>
    showDialog<ReceiptLine>(
      context: context,
      builder: (_) => _ReceiptLineEditor(line: line),
    );

class _ReceiptLineEditor extends StatefulWidget {
  const _ReceiptLineEditor({this.line});
  final ReceiptLine? line;
  @override
  State<_ReceiptLineEditor> createState() => _ReceiptLineEditorState();
}

class _ReceiptLineEditorState extends State<_ReceiptLineEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.line?.name ?? '');
  late final _quantity = TextEditingController(
    text: formatAmount(widget.line?.quantity ?? 1),
  );
  late final _initialPrice = (widget.line?.unitPrice ?? 0).toStringAsFixed(2);
  late final _price = TextEditingController(text: _initialPrice);
  late String _unit = widget.line?.unit ?? 'pieces';
  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  num? number(String? v) => num.tryParse((v ?? '').replaceAll(',', '.'));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.line == null ? 'Add receipt item' : 'Edit receipt item'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator:
                  (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (v) =>
                      number(v) == null ||
                              !number(v)!.isFinite ||
                              number(v)! <= 0
                          ? 'Enter an amount above 0'
                          : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [
                for (final unit in PantryItem.units)
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
              onChanged: (v) {
                if (v != null) _unit = v;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price per unit'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (v) =>
                      number(v) == null ||
                              !number(v)!.isFinite ||
                              number(v)! < 0
                          ? 'Enter 0 or more'
                          : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(
              context,
              ReceiptLine(
                _name.text.trim(),
                number(_quantity.text)!,
                _price.text == _initialPrice && widget.line != null
                    ? widget.line!.unitPrice
                    : number(_price.text)!,
                unit: _unit,
              ),
            );
        },
        child: const Text('Keep item'),
      ),
    ],
  );
}
