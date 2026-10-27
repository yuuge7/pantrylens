import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pantry_provider.dart';
import '../../pantry_item.dart';
import '../../settings_provider.dart';
import 'insights_data.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String? _key;
  Future<PantryInsights>? _future;
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final key = '${pantry.revision}|${pantry.selectedHomeId}';
    if (_key != key) {
      _key = key;
      _future = pantry.data.getInsights(homeId: pantry.selectedHomeId);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Usage & waste')),
      body: FutureBuilder<PantryInsights>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Usage reports could not be loaded.'),
                    TextButton(
                      onPressed: () => setState(() => _key = null),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          final stats = snapshot.data!;
          final now = DateTime.now();
          final expired = pantry.items
              .where((i) => i.daysUntilExpiry() < 0)
              .fold<num>(0, (sum, i) => sum + i.value);
          final months = {
            for (final m in stats.months) m['month'] as String: m,
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                pantry.selectedHomeName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _Metric(
                'Pantry value',
                '${pantry.totalValue.toStringAsFixed(2)} $currency',
              ),
              _Metric(
                'Expired stock value',
                '${expired.toStringAsFixed(2)} $currency',
              ),
              _Metric(
                'Recorded waste',
                '${stats.wastedValue.toStringAsFixed(2)} $currency',
              ),
              const SizedBox(height: 24),
              Text(
                'Last 6 months',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Value of stock used and discarded. Set purchase prices for value totals.',
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Month')),
                    DataColumn(label: Text('Used'), numeric: true),
                    DataColumn(label: Text('Wasted'), numeric: true),
                  ],
                  rows: [
                    for (var n = 5; n >= 0; n--)
                      (() {
                        final month = DateTime(now.year, now.month - n);
                        final label =
                            '${month.year}-${month.month.toString().padLeft(2, '0')}';
                        final row = months[label];
                        return DataRow(
                          cells: [
                            DataCell(Text(label)),
                            DataCell(
                              Text(
                                (row?['used'] as num? ?? 0).toStringAsFixed(2),
                              ),
                            ),
                            DataCell(
                              Text(
                                (row?['wasted'] as num? ?? 0).toStringAsFixed(
                                  2,
                                ),
                              ),
                            ),
                          ],
                        );
                      })(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Most used', style: Theme.of(context).textTheme.titleLarge),
              if (stats.mostUsed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Record usage from a batch to see what your household uses most.',
                  ),
                ),
              for (final item in stats.mostUsed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item['name']} (${item['unit']})'),
                  trailing: Text(formatAmount(item['quantity'] as num)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
