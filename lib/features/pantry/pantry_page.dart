import 'package:flutter/material.dart';

import '../../backend/models.dart';
import '../../backend/pantry_data_source.dart';
import 'pantry_logic.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key, required this.householdId, required this.source});

  final String householdId;
  final PantryDataSource source;

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  late Stream<List<PantryItem>> _stream;
  String? _location;
  bool _useSoon = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _stream = widget.source.watchPantryItems(widget.householdId);
  }

  @override
  void didUpdateWidget(covariant PantryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId || oldWidget.source != widget.source) {
      _stream = widget.source.watchPantryItems(widget.householdId);
    }
  }

  Future<void> _useUp(PantryItem item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Used up ${item.name}?'),
      content: const Text('This removes the item from household inventory.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Used up')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(item.id));
    try {
      await widget.source.useUpPantryItem(householdId: widget.householdId, itemId: item.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove the item. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_useSoon ? 'Use Soon' : 'Pantry inventory')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: false, label: Text('Inventory'), icon: Icon(Icons.kitchen_outlined)),
          ButtonSegment(value: true, label: Text('Use Soon'), icon: Icon(Icons.schedule)),
        ], selected: {_useSoon}, onSelectionChanged: (value) => setState(() => _useSoon = value.single)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('All'), selected: _location == null, onSelected: (_) => setState(() => _location = null)),
          for (final location in storageLocations)
            ChoiceChip(label: Text(locationLabel(location)), selected: _location == location, onSelected: (_) => setState(() => _location = location)),
        ]),
        if (_useSoon) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Entered dates are reminders, not food-safety advice. Highlighted items have a date within 7 days or a date that has passed.')),
      ])),
      Expanded(child: StreamBuilder<List<PantryItem>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load the pantry. Please try again.'),
            TextButton(onPressed: () => setState(() => _stream = widget.source.watchPantryItems(widget.householdId)), child: const Text('Retry')),
          ]));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          if (all.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Your pantry is empty. Buy an item from the grocery list and move it to the fridge, freezer, or cupboard.')));
          final items = sortedPantry(all.where((item) => _location == null || item.storageLocationId.toLowerCase() == _location));
          if (items.isEmpty) return Center(child: Text('No items in ${locationLabel(_location!)}. Try All to see the rest of your pantry.'));
          final dated = items.where((item) => item.expiresOn != null).toList();
          final undated = items.where((item) => item.expiresOn == null).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            if (_useSoon && dated.isEmpty) const ListTile(title: Text('No dated items'), subtitle: Text('Edit an item to add an optional reminder date.')),
            if (_useSoon && dated.isNotEmpty) const ListTile(title: Text('By entered date')),
            for (final item in _useSoon ? dated : items) _tile(item),
            if (_useSoon && undated.isNotEmpty) const ListTile(title: Text('No date entered')),
            if (_useSoon) for (final item in undated) _tile(item),
          ]);
        },
      )),
    ]),
  );

  Widget _tile(PantryItem item) => Card(
    color: _useSoon && isUseSoon(item, DateTime.now()) ? Theme.of(context).colorScheme.secondaryContainer : null,
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.name, style: Theme.of(context).textTheme.titleMedium),
      Text('Quantity: ${item.quantity} • ${locationLabel(item.storageLocationId)}'),
      Text(reminderLabel(item, DateTime.now())),
      if (_busy.contains(item.id)) const LinearProgressIndicator() else Wrap(spacing: 8, children: [
        TextButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => PantryEditDialog(item: item, householdId: widget.householdId, source: widget.source)), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
        TextButton.icon(onPressed: () => _useUp(item), icon: const Icon(Icons.check), label: const Text('Used up')),
      ]),
    ])),
  );
}

class PantryEditDialog extends StatefulWidget {
  const PantryEditDialog({super.key, required this.item, required this.householdId, required this.source});
  final PantryItem item;
  final String householdId;
  final PantryDataSource source;

  @override
  State<PantryEditDialog> createState() => _PantryEditDialogState();
}

class _PantryEditDialogState extends State<PantryEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantity = TextEditingController(text: widget.item.quantity.toString());
  late String _location = widget.item.storageLocationId.toLowerCase();
  late DateTime? _date = widget.item.expiresOn;
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _quantity.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context,
      initialDate: _date ?? DateTime.now(), firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31));
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.source.updatePantryItem(householdId: widget.householdId, itemId: widget.item.id,
        quantity: num.parse(_quantity.text.trim()), storageLocationId: _location, expiresOn: _date);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Could not save changes. Your input is kept. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(canPop: !_saving, child: AlertDialog(
    title: Text('Edit ${widget.item.name}'),
    content: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _quantity, enabled: !_saving, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: validatePantryQuantity),
      DropdownButtonFormField<String>(initialValue: _location, decoration: const InputDecoration(labelText: 'Storage location'),
        items: {...storageLocations, _location}.map((value) => DropdownMenuItem(value: value, child: Text(locationLabel(value)))).toList(),
        onChanged: _saving ? null : (value) => setState(() => _location = value!)),
      const SizedBox(height: 12),
      Text(_date == null ? 'No date entered' : 'Entered date: ${dateLabel(_date!)}'),
      Wrap(children: [TextButton(onPressed: _saving ? null : _pickDate, child: const Text('Choose date')),
        if (_date != null) TextButton(onPressed: _saving ? null : () => setState(() => _date = null), child: const Text('Clear date'))]),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
      if (_saving) const LinearProgressIndicator(),
    ]))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save'))],
  ));
}
