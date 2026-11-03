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
                      setState(() => item.isPurchased = value ?? false),
                  title: Text(item.name),
                  subtitle: Text('Quantity: ${item.quantityLabel}'),
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

  String get quantityLabel => quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
}

class _AddGroceryItemDialog extends StatefulWidget {
  const _AddGroceryItemDialog();

  @override
  State<_AddGroceryItemDialog> createState() => _AddGroceryItemDialogState();
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
