import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../pantry_actions.dart';
import '../../pantry_provider.dart';
import '../../pantry_item.dart';
import '../../settings_provider.dart';
import 'household_models.dart';
import 'event_planner.dart';

class HouseholdScreen extends StatelessWidget {
  const HouseholdScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Homes'),
            Tab(text: 'Tasks'),
            Tab(text: 'Guests'),
            Tab(text: 'Events'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _Homes(),
          _Records(kind: 'task'),
          _Records(kind: 'profile'),
          _Records(kind: 'event'),
          _ActivityList(),
        ],
      ),
    ),
  );
}

class HomeSelector extends StatelessWidget {
  const HomeSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    return PopupMenuButton<String>(
      tooltip: 'Select home',
      icon: const Icon(Icons.home_outlined),
      onSelected: (id) {
        if (id == '__manage') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HouseholdScreen()),
          );
        } else {
          final home = id == '__all' ? null : id;
          pantry.selectHome(home);
          context.read<SettingsProvider>().setExtra('homeId', home);
        }
      },
      itemBuilder:
          (_) => [
            CheckedPopupMenuItem(
              value: '__all',
              checked: pantry.selectedHomeId == null,
              child: const Text('All homes'),
            ),
            for (final h in pantry.homes)
              CheckedPopupMenuItem(
                value: h.id,
                checked: h.id == pantry.selectedHomeId,
                child: Text(h.name),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: '__manage',
              child: Text('Manage household'),
            ),
          ],
    );
  }
}

class _Homes extends StatelessWidget {
  const _Homes();
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'A pantry for every home',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep stock and shopping separate for each property. Choose All homes from the home menu to see everything.',
        ),
        const SizedBox(height: 20),
        for (final h in pantry.homes)
          Card(
            child: ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(h.name),
              subtitle: Text(h.locations.join(' · ')),
              isThreeLine: true,
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editHome(context, h),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _editHome(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Add home'),
        ),
      ],
    );
  }
}

Future<void> _editHome(BuildContext context, Home? home) async {
  final name = TextEditingController(text: home?.name ?? '');
  final locations = TextEditingController(
    text: (home?.locations ?? PantryItem.locations).join(', '),
  );
  final pantry = context.read<PantryProvider>();
  final form = GlobalKey<FormState>();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(home == null ? 'Add home' : 'Edit home'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Home name'),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Enter a name'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locations,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Storage locations',
                      helperText: 'Separate locations with commas',
                    ),
                    validator:
                        (v) =>
                            v == null ||
                                    v.split(',').every((s) => s.trim().isEmpty)
                                ? 'Add at least one location'
                                : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(c, true);
              },
              child: const Text('Save home'),
            ),
          ],
        ),
  );
  if (saved == true) {
    try {
      await pantry.saveHome(
        Home(
          id: home?.id ?? 'home-${DateTime.now().microsecondsSinceEpoch}',
          name: name.text.trim(),
          locations:
              locations.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList(),
        ),
      );
    } catch (_) {
      if (context.mounted) showMessage(context, 'Home not saved. Try again.');
    }
  }
  // Dialog route animations must finish before disposing their controllers.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  locations.dispose();
}

class _Records extends StatelessWidget {
  const _Records({required this.kind});
  final String kind;
  String get singular => switch (kind) {
    'task' => 'task',
    'profile' => 'guest profile',
    _ => 'event',
  };
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final records = pantry.records.where((r) => r.kind == kind).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: () => _editRecord(context, kind, null),
          icon: const Icon(Icons.add),
          label: Text('Add $singular'),
        ),
        const SizedBox(height: 20),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(switch (kind) {
              'task' =>
                'Plan a restock, assign it to someone and track each step.',
              'profile' =>
                'Save allergies, dietary needs and favorite foods for household members and visitors.',
              _ =>
                'Plan a meal and add missing ingredients to the shopping list.',
            }),
          ),
        for (final r in records)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${r.data['name']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      [
                        if (r.data['assignee']?.toString().isNotEmpty == true)
                          'Assigned to ${r.data['assignee']}',
                        if (r.data['due']?.toString().isNotEmpty == true)
                          'Due ${r.data['due']}',
                        if (kind == 'profile') '${r.data['diet'] ?? ''}',
                        pantry.homes
                                .where((h) => h.id == r.homeId)
                                .firstOrNull
                                ?.name ??
                            r.homeId,
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Edit $singular',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editRecord(context, kind, r),
                    ),
                  ),
                  if (kind == 'task') ...[
                    for (final (n, step)
                        in ((r.data['steps'] as List?) ?? []).indexed)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${step['text']}'),
                        value: step['done'] == true,
                        onChanged: (value) async {
                          final steps = [
                            for (final s in r.data['steps'] as List)
                              Map<String, dynamic>.from(s as Map),
                          ];
                          steps[n]['done'] = value;
                          try {
                            await pantry.saveRecord(
                              HouseholdRecord(
                                id: r.id,
                                kind: r.kind,
                                homeId: r.homeId,
                                data: {...r.data, 'steps': steps},
                              ),
                            );
                          } catch (_) {
                            if (context.mounted)
                              showMessage(
                                context,
                                'Checklist not saved. Try again.',
                              );
                          }
                        },
                      ),
                    if (r.data['notes']?.toString().isNotEmpty == true)
                      Text('${r.data['notes']}'),
                    if (r.data['photo'] is String)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Image.file(
                          File(r.data['photo'] as String),
                          height: 160,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Text(
                                'Photo unavailable. Edit the task to attach it again.',
                              ),
                        ),
                      ),
                  ],
                  if (kind == 'profile') ...[
                    if ('${r.data['allergies'] ?? ''}'.isNotEmpty)
                      Text(
                        'Allergies: ${r.data['allergies']}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Text('Favorites: ${r.data['favorites'] ?? ''}'),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          for (final name in '${r.data['favorites'] ?? ''}'
                              .split(',')
                              .where((n) => n.trim().isNotEmpty)) {
                            await pantry.addShoppingItem(
                              name.trim(),
                              homeId: r.homeId,
                            );
                          }
                          if (context.mounted)
                            showMessage(
                              context,
                              'Favorites added to shopping list',
                            );
                        } catch (_) {
                          if (context.mounted)
                            showMessage(
                              context,
                              'Could not add favorites. Try again.',
                            );
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Shop favorites'),
                    ),
                  ],
                  if (kind == 'event') _EventRequirements(record: r),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EventRequirements extends StatelessWidget {
  const _EventRequirements({required this.record});
  final HouseholdRecord record;
  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final requirements =
        ((record.data['requirements'] as List?) ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
    final missing = missingIngredients(
      requirements,
      pantry.allItems,
      record.homeId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in requirements)
          Text(
            '${r['name']} · ${formatAmount(r['quantity'] as num)} ${r['unit']}',
          ),
        const SizedBox(height: 8),
        Text(
          missing.isEmpty
              ? 'Everything is in stock'
              : 'Missing: ${missing.map((r) => '${r['name']} (${formatAmount(r['quantity'] as num)} ${r['unit']})').join(', ')}',
        ),
        TextButton.icon(
          onPressed:
              missing.isEmpty
                  ? null
                  : () async {
                    try {
                      for (final r in missing) {
                        await pantry.addShoppingItem(
                          r['name'] as String,
                          quantity: r['quantity'] as num,
                          unit: r['unit'] as String,
                          homeId: record.homeId,
                          ensureQuantity: true,
                        );
                      }
                      if (context.mounted)
                        showMessage(
                          context,
                          'Missing ingredients added to shopping list',
                        );
                    } catch (_) {
                      if (context.mounted)
                        showMessage(
                          context,
                          'Could not update the list. Try again.',
                        );
                    }
                  },
          icon: const Icon(Icons.playlist_add),
          label: const Text('Shop missing ingredients'),
        ),
      ],
    );
  }
}

Future<void> _editRecord(
  BuildContext context,
  String kind,
  HouseholdRecord? record,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _RecordEditor(kind: kind, record: record),
);

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({required this.kind, this.record});
  final String kind;
  final HouseholdRecord? record;
  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'name',
      'assignee',
      'notes',
      'allergies',
      'favorites',
      'diet',
    ])
      key: TextEditingController(text: '${widget.record?.data[key] ?? ''}'),
  };
  late final _steps = TextEditingController(
    text: ((widget.record?.data['steps'] as List?) ?? [])
        .map((s) => s['text'])
        .join('\n'),
  );
  late final _requirements = TextEditingController(
    text: ((widget.record?.data['requirements'] as List?) ?? [])
        .map((s) => '${s['name']} | ${s['quantity']} | ${s['unit']}')
        .join('\n'),
  );
  late String _home =
      widget.record?.homeId ??
      context.read<PantryProvider>().selectedHomeId ??
      'main';
  late String _due = widget.record?.data['due'] as String? ?? '';
  late String? _photo = widget.record?.data['photo'] as String?;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [..._fields.values, _steps, _requirements]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        for (final e in _fields.entries) e.key: e.value.text.trim(),
        'due': _due,
        if (_photo != null) 'photo': _photo,
      };
      if (widget.kind == 'task')
        data['steps'] = [
          for (final text in _steps.text
              .split('\n')
              .where((t) => t.trim().isNotEmpty))
            {
              'text': text.trim(),
              'done': ((widget.record?.data['steps'] as List?) ?? []).any(
                (s) => s['text'] == text.trim() && s['done'] == true,
              ),
            },
        ];
      if (widget.kind == 'event') {
        data['requirements'] = parseRequirements(_requirements.text);
        if ((data['requirements'] as List).isEmpty)
          throw const FormatException('Add at least one ingredient.');
      }
      await context.read<PantryProvider>().saveRecord(
        HouseholdRecord(
          id: widget.record?.id,
          kind: widget.kind,
          homeId: _home,
          data: data,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = e is FormatException ? e.message : 'Not saved. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final isTask = widget.kind == 'task';
    final isGuest = widget.kind == 'profile';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.record == null ? 'Add' : 'Edit'} ${isTask
                    ? 'task'
                    : isGuest
                    ? 'guest profile'
                    : 'event'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fields['name'],
                decoration: InputDecoration(
                  labelText: isGuest ? 'Guest or household member' : 'Name',
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _home,
                decoration: const InputDecoration(labelText: 'Home'),
                items:
                    pantry.homes
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _home = v);
                },
              ),
              for (final (key, label)
                  in isGuest
                      ? [
                        ('allergies', 'Allergies (comma separated)'),
                        ('diet', 'Dietary preferences'),
                        ('favorites', 'Favorite foods (comma separated)'),
                      ]
                      : isTask
                      ? [('assignee', 'Assigned to'), ('notes', 'Notes')]
                      : <(String, String)>[]) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fields[key],
                  decoration: InputDecoration(labelText: label),
                ),
              ],
              if (!isGuest) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(_due.isEmpty ? 'Choose date' : _due),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_due) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted)
                      setState(
                        () => _due = date.toIso8601String().substring(0, 10),
                      );
                  },
                ),
                TextFormField(
                  controller: isTask ? _steps : _requirements,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText:
                        isTask
                            ? 'Checklist · one step per line'
                            : 'Ingredients · one per line',
                    hintText:
                        isTask
                            ? 'Check fridge\nRestock breakfast supplies'
                            : 'Tomatoes | 2 | kg\nMilk | 1 | l',
                    helperText:
                        isTask ? null : 'Units: pieces, g, kg, ml, l, bottle',
                  ),
                ),
              ],
              if (isTask)
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final photo = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 85,
                      );
                      if (photo == null) return;
                      final dir = await getApplicationDocumentsDirectory();
                      final path =
                          '${dir.path}/task-${DateTime.now().microsecondsSinceEpoch}.jpg';
                      await File(photo.path).copy(path);
                      if (mounted) setState(() => _photo = path);
                    } catch (_) {
                      if (mounted)
                        setState(
                          () => _error = 'Photo not attached. Try again.',
                        );
                    }
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _photo == null ? 'Attach photo' : 'Replace photo',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
              if (widget.record != null)
                TextButton(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            try {
                              await pantry.deleteRecord(widget.record!.id!);
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              if (mounted)
                                setState(
                                  () => _error = 'Could not delete. Try again.',
                                );
                            }
                          },
                  child: const Text('Delete'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList();
  @override
  Widget build(BuildContext context) {
    final activity = context.watch<PantryProvider>().activity;
    if (activity.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Activity appears here when someone adds, uses, moves or removes stock. Set your name in Settings.',
          ),
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activity.length,
      itemBuilder: (context, n) {
        final a = activity[n];
        return ListTile(
          leading: Icon(
            a.action == 'wasted' ? Icons.delete_sweep_outlined : Icons.history,
          ),
          title: Text('${a.actor} ${a.action} ${a.name}'),
          subtitle: Text(
            '${formatAmount(a.quantity)} ${a.unit} · ${a.at.toLocal().toString().substring(0, 16)}',
          ),
        );
      },
    );
  }
}
