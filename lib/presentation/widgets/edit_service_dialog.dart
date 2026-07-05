import 'package:flutter/material.dart';

class EditServiceDialog extends StatefulWidget {
  final String initialName;
  final String initialAccount;

  const EditServiceDialog({
    super.key,
    required this.initialName,
    required this.initialAccount,
  });

  @override
  State<EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<EditServiceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _accountController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _accountController = TextEditingController(text: widget.initialAccount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit entry'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: 'Account',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Name cannot be empty.';
      });
      return;
    }
    Navigator.of(context).pop(
      EditServiceResult(
        name: name,
        account: _accountController.text.trim(),
      ),
    );
  }
}

class EditServiceResult {
  final String name;
  final String account;

  const EditServiceResult({
    required this.name,
    required this.account,
  });
}
