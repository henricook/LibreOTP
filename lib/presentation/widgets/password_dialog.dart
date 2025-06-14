import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  final String? errorMessage;
  
  const PasswordDialog({super.key, this.errorMessage});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Encrypted Backup Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This backup file is encrypted. Please enter the password to decrypt it.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            onSubmitted: _isLoading ? null : (_) => _submitPassword(),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getErrorMessage(widget.errorMessage!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Decrypt'),
        ),
      ],
    );
  }

  void _submitPassword() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    Navigator.of(context).pop(password);
  }

  String _getErrorMessage(String error) {
    if (error.contains('Invalid password') || error.contains('Decryption failed')) {
      return 'Incorrect password. Please try again.';
    } else if (error.contains('Invalid vault file') || error.contains('Invalid encrypted backup format')) {
      return 'This backup file appears to be corrupted or invalid.';
    } else if (error.contains('Password required')) {
      return 'A password is required to decrypt this backup.';
    } else {
      return 'An error occurred while decrypting the backup. Please try again.';
    }
  }
}