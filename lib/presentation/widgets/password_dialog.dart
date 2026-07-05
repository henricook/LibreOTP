import 'package:flutter/material.dart';

import '../../data/repositories/storage_repository.dart';

enum PasswordDialogMode {
  unlockVault,
  decryptBackup,
  createVaultPassword,
  changeVaultPassword,
}

class PasswordDialog extends StatefulWidget {
  final PasswordDialogMode mode;
  final String? errorMessage;
  final VaultLoadErrorKind? errorKind;

  const PasswordDialog({
    super.key,
    required this.mode,
    this.errorMessage,
    this.errorKind,
  });

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _validationError;

  bool get _requiresConfirmation =>
      widget.mode == PasswordDialogMode.createVaultPassword ||
      widget.mode == PasswordDialogMode.changeVaultPassword;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_titleText()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_descriptionText()),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _requiresConfirmation ? 'New Password' : 'Password',
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
            onChanged: _clearValidationError,
            onSubmitted: _isLoading ? null : (_) => _submitPassword(),
          ),
          if (_requiresConfirmation) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              onChanged: _clearValidationError,
              onSubmitted: _isLoading ? null : (_) => _submitPassword(),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a strong password you can remember. If you lose it, the encrypted local data cannot be recovered.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_effectiveErrorMessage() != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _effectiveErrorMessage()!,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
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
              : Text(_submitButtonText()),
        ),
      ],
    );
  }

  void _submitPassword() {
    // Never trim: surrounding whitespace is part of the password.
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() {
        _validationError = _requiresConfirmation
            ? 'A password is required to create the encrypted vault.'
            : _modeNameForMissingPassword();
      });
      return;
    }

    if (_requiresConfirmation && password != confirmPassword) {
      setState(() {
        _validationError = 'Passwords do not match. Please try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _validationError = null;
    });

    Navigator.of(context).pop(password);
  }

  void _clearValidationError(String _) {
    if (_validationError == null) {
      return;
    }
    setState(() {
      _validationError = null;
    });
  }

  String _titleText() {
    switch (widget.mode) {
      case PasswordDialogMode.unlockVault:
        return 'Encrypted Vault Detected';
      case PasswordDialogMode.decryptBackup:
        return 'Encrypted Backup Detected';
      case PasswordDialogMode.createVaultPassword:
        return 'Create Vault Password';
      case PasswordDialogMode.changeVaultPassword:
        return 'Change Vault Password';
    }
  }

  String _descriptionText() {
    switch (widget.mode) {
      case PasswordDialogMode.unlockVault:
        return 'This local vault is encrypted. Enter the password to unlock your stored services.';
      case PasswordDialogMode.decryptBackup:
        return 'This backup file is encrypted. Enter the password to decrypt it.';
      case PasswordDialogMode.createVaultPassword:
        return 'Choose a password for the encrypted local vault.';
      case PasswordDialogMode.changeVaultPassword:
        return 'Choose a new password for the encrypted local vault.';
    }
  }

  String _submitButtonText() {
    switch (widget.mode) {
      case PasswordDialogMode.unlockVault:
        return 'Unlock';
      case PasswordDialogMode.decryptBackup:
        return 'Decrypt';
      case PasswordDialogMode.createVaultPassword:
        return 'Create Vault';
      case PasswordDialogMode.changeVaultPassword:
        return 'Change Password';
    }
  }

  String _modeNameForMissingPassword() {
    switch (widget.mode) {
      case PasswordDialogMode.unlockVault:
        return 'A password is required to unlock this vault.';
      case PasswordDialogMode.decryptBackup:
        return 'A password is required to decrypt this backup.';
      case PasswordDialogMode.createVaultPassword:
        return 'A password is required to create the encrypted vault.';
      case PasswordDialogMode.changeVaultPassword:
        return 'A password is required to change the encrypted vault password.';
    }
  }

  String? _effectiveErrorMessage() {
    if (_validationError != null) {
      return _validationError;
    }

    if (_requiresConfirmation) {
      if (widget.errorMessage == null && widget.errorKind == null) {
        return null;
      }
      return 'An error occurred while creating the encrypted vault. Please try again.';
    }

    switch (widget.errorKind) {
      case VaultLoadErrorKind.corruptedVault:
        return 'This vault file appears to be corrupted or was created by a newer version.';
      case VaultLoadErrorKind.incorrectPassword:
        return 'Incorrect password. Please try again.';
      case VaultLoadErrorKind.unknown:
      case null:
        break;
    }

    if (widget.errorMessage == null) {
      return null;
    }

    if (widget.mode == PasswordDialogMode.unlockVault) {
      return 'An error occurred while unlocking the vault. Please try again.';
    }

    return 'An error occurred while decrypting the backup. Please try again.';
  }
}
