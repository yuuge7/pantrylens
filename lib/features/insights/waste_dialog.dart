import 'package:flutter/material.dart';
import '../../pantry_item.dart';

typedef WasteEntry = ({num amount, String reason});

Future<WasteEntry?> askWaste(BuildContext context, PantryItem item) =>
    showDialog<WasteEntry>(
      context: context,
      builder: (_) => _WasteDialog(item: item),
    );

class _WasteDialog extends StatefulWidget {
  const _WasteDialog({required this.item});
  final PantryItem item;
  @override
  State<_WasteDialog> createState() => _WasteDialogState();
}

class _WasteDialogState extends State<_WasteDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: formatAmount(widget.item.quantity),
  );
  late String _reason =
      widget.item.daysUntilExpiry() < 0 ? 'expired' : 'spoiled';
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record waste'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.item.name),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              decoration: InputDecoration(
                labelText: 'Amount (${widget.item.unit})',
                helperText: '${widget.item.amountLabel} in this batch',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                return n == null ||
                        !n.isFinite ||
                        n <= 0 ||
                        n > widget.item.quantity
                    ? 'Enter more than 0, up to ${formatAmount(widget.item.quantity)}'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: const [
                DropdownMenuItem(
                  value: 'expired',
                  child: Text('Past expiry date'),
                ),
                DropdownMenuItem(
                  value: 'spoiled',
                  child: Text('Spoiled or damaged'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other reason')),
              ],
              onChanged: (v) {
                if (v != null) _reason = v;
              },
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
            Navigator.pop(context, (
              amount: num.parse(_amount.text.replaceAll(',', '.')),
              reason: _reason,
            ));
        },
        child: const Text('Record waste'),
      ),
    ],
  );
}
