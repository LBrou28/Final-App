import 'package:flutter/material.dart';

import '../../backend/grocery_data_source.dart';
import '../../backend/models.dart';
import '../pantry/pantry_logic.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({
    super.key,
    required this.householdId,
    required this.source,
  });
  final String householdId;
  final GroceryDataSource source;

  @override
  State<GroceryListPage> createState() => _GroceryListPageState();
}

class _GroceryListPageState extends State<GroceryListPage> {
  late Stream<List<GroceryItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.source.watchGroceryItems(widget.householdId);
  }

  @override
  void didUpdateWidget(covariant GroceryListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId ||
        oldWidget.source != widget.source) {
      _items = widget.source.watchGroceryItems(widget.householdId);
    }
  }

  Future<void> _edit([GroceryItem? item]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GroceryEditor(
      item: item,
      save: (name, quantity) => item == null
          ? widget.source.addGroceryItem(
              householdId: widget.householdId,
              name: name,
              quantity: quantity,
            )
          : widget.source.updateGroceryItem(
              householdId: widget.householdId,
              expected: item,
              name: name,
              quantity: quantity,
            ),
    ),
  );

  Future<void> _purchase(GroceryItem item) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PurchaseDialog(
      item: item,
      save: (location, date) => widget.source.purchaseToPantry(
        householdId: widget.householdId,
        groceryItemId: item.id,
        storageLocationId: location,
        expiresOn: date,
      ),
    ),
  );

  Future<void> _delete(GroceryItem item) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteDialog(
      item: item,
      remove: () => widget.source.deleteGroceryItem(
        householdId: widget.householdId,
        expected: item,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Grocery list')),
    body: StreamBuilder<List<GroceryItem>>(
      key: ValueKey(widget.householdId),
      stream: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load groceries.'),
                TextButton(
                  onPressed: () => setState(
                    () => _items = widget.source.watchGroceryItems(
                      widget.householdId,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your shared grocery list is empty. Add an item or choose ingredients from Recipes.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            final contributor = item.createdBy == widget.source.currentUserId
                ? 'you'
                : 'household member';
            return ListTile(
              key: ValueKey(item.id),
              leading: Checkbox(
                value: item.isPurchased,
                onChanged: item.isPurchased ? null : (_) => _purchase(item),
                semanticLabel: 'Purchase ${item.name}',
              ),
              title: Text(item.name),
              subtitle: Text(
                'Quantity: ${item.quantity} • Added by $contributor${item.isPurchased ? '\nPurchased - manage inventory in Pantry' : ''}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Options for ${item.name}',
                onSelected: (action) =>
                    action == 'edit' ? _edit(item) : _delete(item),
                itemBuilder: (_) => [
                  if (!item.isPurchased)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Add item'),
    ),
  );
}

/// Dialog state owns pending writes so duplicate taps and navigation cannot
/// accidentally submit the same operation twice.
mixin _SaveState<T extends StatefulWidget> on State<T> {
  bool saving = false;
  String? error;

  Future<void> submit(Future<void> Function() action) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = failure is GroceryConflict
              ? failure.toString()
              : 'Could not save. Check your connection and try again.';
        });
      }
    }
  }

  Widget errorMessage() => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
}

class _GroceryEditor extends StatefulWidget {
  const _GroceryEditor({this.item, required this.save});
  final GroceryItem? item;
  final Future<void> Function(String, num) save;
  @override
  State<_GroceryEditor> createState() => _GroceryEditorState();
}

class _GroceryEditorState extends State<_GroceryEditor> with _SaveState {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _quantity = TextEditingController(
    text: widget.item?.quantity.toString() ?? '1',
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      submit(
        () => widget.save(_name.text.trim(), num.parse(_quantity.text.trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(
        widget.item == null ? 'Add grocery item' : 'Edit grocery item',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !saving,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Item name'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an item name.'
                    : null,
              ),
              TextFormField(
                controller: _quantity,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: validatePantryQuantity,
                onFieldSubmitted: (_) => _save(),
              ),
              errorMessage(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(
            saving
                ? 'Saving...'
                : widget.item == null
                ? 'Add'
                : 'Save',
          ),
        ),
      ],
    ),
  );
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.item, required this.save});
  final GroceryItem item;
  final Future<void> Function(String, DateTime?) save;
  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> with _SaveState {
  String _location = 'fridge';
  DateTime? _date;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text('Move ${widget.item.name} to pantry?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _location,
              decoration: const InputDecoration(labelText: 'Storage location'),
              items: storageLocations
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(locationLabel(id)),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() => _location = value!),
            ),
            const SizedBox(height: 16),
            Text(
              _date == null
                  ? 'No expiration date'
                  : 'Entered date: ${dateLabel(_date!)}',
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: saving ? null : _pickDate,
                  child: const Text('Choose date'),
                ),
                if (_date != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() => _date = null),
                    child: const Text('Clear date'),
                  ),
              ],
            ),
            errorMessage(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () => submit(() => widget.save(_location, _date)),
          child: Text(saving ? 'Moving...' : 'Move item'),
        ),
      ],
    ),
  );
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.item, required this.remove});
  final GroceryItem item;
  final Future<void> Function() remove;
  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> with _SaveState {
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text('Delete ${widget.item.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.item.isPurchased
                ? 'Remove this entry from the grocery list? The pantry inventory will be kept.'
                : 'Remove this item from the shared grocery list?',
          ),
          errorMessage(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : () => submit(widget.remove),
          child: Text(saving ? 'Deleting...' : 'Delete'),
        ),
      ],
    ),
  );
}
