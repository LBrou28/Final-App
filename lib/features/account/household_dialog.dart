import 'package:flutter/material.dart';

class HouseholdDialog extends StatefulWidget {
  const HouseholdDialog({
    super.key,
    required this.create,
    required this.submit,
  });
  final bool create;
  final Future<String> Function(String value) submit;
  @override
  State<HouseholdDialog> createState() => _HouseholdDialogState();
}

class _HouseholdDialogState extends State<HouseholdDialog> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  bool _busy = false;
  String? _error, _code;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit(_value.text.trim());
      if (!mounted) return;
      if (widget.create) {
        setState(() => _code = result);
      } else {
        Navigator.pop(context, result);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ArgumentError
              ? error.message.toString()
              : 'Could not ${widget.create ? 'create household' : 'join with this code'}. Check your connection${widget.create ? '' : ' and invite code'}, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        _code != null
            ? 'Household created'
            : widget.create
            ? 'Create household'
            : 'Join household',
      ),
      content: SingleChildScrollView(
        child: _code != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share this invite code with your roommates:'),
                  const SizedBox(height: 16),
                  SelectableText(
                    _code!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              )
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _value,
                      enabled: !_busy,
                      autofocus: true,
                      textCapitalization: widget.create
                          ? TextCapitalization.words
                          : TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: widget.create
                            ? 'Household name'
                            : 'Invite code',
                      ),
                      validator: (value) => widget.create
                          ? (value?.trim().isEmpty ?? true)
                                ? 'Enter a household name.'
                                : null
                          : !RegExp(r'^[A-HJ-NP-Z2-9]{10}$')
                                .hasMatch(value!.trim().toUpperCase())
                          ? 'Enter the 10-character invite code.'
                          : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!),
                      ),
                  ],
                ),
              ),
      ),
      actions: _code != null
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Saving...'
                      : widget.create
                      ? 'Create'
                      : 'Join',
                ),
              ),
            ],
    ),
  );
}
