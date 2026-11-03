import 'package:flutter/material.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key});

  @override
  State<GroceryListPage> createState() => _GroceryListPageState();
}

class _GroceryListPageState extends State<GroceryListPage> {
  final List<_GroceryListItem> _items = [];

  Future<void> _showAddItemDialog() async {
    final item = await showDialog<_GroceryListItem>(
      context: context,
      builder: (_) => const _AddGroceryItemDialog(),
    );

    if (item != null) {
      setState(() => _items.add(item));
    }
  }

  Future<void> _changePurchaseStatus(
    _GroceryListItem item,
    bool isPurchased,
  ) async {
    if (!isPurchased) {
      setState(() {
        item.isPurchased = false;
        item.pantryDetails = null;
      });
      return;
    }

    final details = await showDialog<_PantryDetails>(
      context: context,
      builder: (_) => _MoveToPantryDialog(itemName: item.name),
    );

    if (details != null) {
      setState(() {
        item.isPurchased = true;
        item.pantryDetails = details;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery list')),
      body: _items.isEmpty
          ? const Center(
              child: Text(
                'Your grocery list is empty. Add an item to get started.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return CheckboxListTile(
                  value: item.isPurchased,
                  onChanged: (value) =>
                      _changePurchaseStatus(item, value ?? false),
                  title: Text(item.name),
                  subtitle: Text(
                    item.pantryDetails == null
                        ? 'Quantity: ${item.quantityLabel}'
                        : 'Quantity: ${item.quantityLabel} • ${item.pantryDetails!.label}',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }
}

class _GroceryListItem {
  _GroceryListItem({required this.name, required this.quantity});

  final String name;
  final double quantity;
  bool isPurchased = false;
  _PantryDetails? pantryDetails;

  String get quantityLabel => quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
}

class _PantryDetails {
  const _PantryDetails({required this.location, this.expiresOn});

  final String location;
  final DateTime? expiresOn;

  String get label {
    if (expiresOn == null) return '$location • No expiration date';
    return '$location • Expires ${expiresOn!.month}/${expiresOn!.day}/${expiresOn!.year}';
  }
}

class _AddGroceryItemDialog extends StatefulWidget {
  const _AddGroceryItemDialog();

  @override
  State<_AddGroceryItemDialog> createState() => _AddGroceryItemDialogState();
}

class _MoveToPantryDialog extends StatefulWidget {
  const _MoveToPantryDialog({required this.itemName});

  final String itemName;

  @override
  State<_MoveToPantryDialog> createState() => _MoveToPantryDialogState();
}

class _MoveToPantryDialogState extends State<_MoveToPantryDialog> {
  static const _locations = ['Fridge', 'Freezer', 'Cupboard'];
  String _location = _locations.first;
  DateTime? _expiresOn;

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) setState(() => _expiresOn = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move ${widget.itemName} to pantry?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _location,
            decoration: const InputDecoration(labelText: 'Storage location'),
            items: _locations
                .map(
                  (location) =>
                      DropdownMenuItem(value: location, child: Text(location)),
                )
                .toList(),
            onChanged: (location) => setState(() => _location = location!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _expiresOn == null
                      ? 'No expiration date'
                      : 'Expires ${_expiresOn!.month}/${_expiresOn!.day}/${_expiresOn!.year}',
                ),
              ),
              TextButton(
                onPressed: _pickExpirationDate,
                child: const Text('Choose date'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _PantryDetails(location: _location, expiresOn: _expiresOn),
          ),
          child: const Text('Move item'),
        ),
      ],
    );
  }
}

class _AddGroceryItemDialogState extends State<_AddGroceryItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    if (name.isEmpty || quantity == null || quantity <= 0) return;
    Navigator.pop(context, _GroceryListItem(name: name, quantity: quantity));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add grocery item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Item name'),
            textInputAction: TextInputAction.next,
          ),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(labelText: 'Quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _addItem(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _addItem, child: const Text('Add')),
      ],
    );
  }
}
