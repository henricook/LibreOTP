import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/otp_service.dart';
import '../../config/app_config.dart';
import '../../data/repositories/storage_repository.dart';
import '../state/otp_state.dart';
import '../widgets/edit_service_dialog.dart';
import '../widgets/search_bar.dart';
import '../widgets/otp_table.dart';
import '../widgets/password_dialog.dart';
import 'about_page.dart';
import 'data_directory_page.dart';

class DashboardPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const DashboardPage({super.key, required this.onThemeChanged});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  int? _sortColumnIndex;
  bool _sortAscending = true;
  bool _migrationPromptHandled = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateSearchQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPasswordRequirement();
    });
  }

  void _checkForPasswordRequirement() {
    final otpState = Provider.of<OtpState>(context, listen: false);
    if (otpState.requiresPassword) {
      _showPasswordDialog();
    }
  }

  /// User-facing description of a load failure; internal exception text is
  /// logged, never rendered.
  String _loadErrorText(OtpState otpState) {
    switch (otpState.encryptionErrorKind) {
      case VaultLoadErrorKind.incorrectPassword:
        return 'Incorrect password. Please try again.';
      case VaultLoadErrorKind.corruptedVault:
        return 'The vault file appears to be corrupted or was created by a '
            'newer version of LibreOTP.';
      case VaultLoadErrorKind.unknown:
      case null:
        return 'Your stored data could not be read. It may be corrupted. '
            'You can retry or import a fresh 2FAS backup.';
    }
  }

  void _checkForEncryptionMigrationPrompt() {
    final otpState = Provider.of<OtpState>(context, listen: false);
    if (!otpState.shouldPromptForEncryptionMigration ||
        otpState.requiresPassword ||
        otpState.isLoading ||
        _migrationPromptHandled) {
      return;
    }

    _migrationPromptHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showEncryptionMigrationPrompt();
      }
    });
  }

  void _showPasswordDialog() async {
    final otpState = Provider.of<OtpState>(context, listen: false);

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordDialog(
        mode: otpState.requiresLocalVaultPassword
            ? PasswordDialogMode.unlockVault
            : PasswordDialogMode.decryptBackup,
        errorMessage: otpState.encryptionError,
        errorKind: otpState.encryptionErrorKind,
      ),
    );

    if (password != null && mounted) {
      await otpState.loadDataWithPassword(password);
      // Only re-prompt while a password is still the blocker; other load
      // failures are surfaced by the dashboard error state instead.
      if (otpState.requiresPassword && mounted) {
        _showPasswordDialog(); // Show dialog again with error
      }
    }
  }

  Future<void> _showEncryptionMigrationPrompt() async {
    final otpState = Provider.of<OtpState>(context, listen: false);

    final shouldEncrypt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encrypt Local Data'),
        content: const Text(
          'LibreOTP loaded plaintext local data from data.json. You can migrate it into an encrypted local vault and remove the plaintext file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Encrypt'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (shouldEncrypt != true) {
      otpState.dismissEncryptionMigrationPrompt();
      return;
    }

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const PasswordDialog(mode: PasswordDialogMode.createVaultPassword),
    );

    if (!mounted) {
      return;
    }

    if (password == null) {
      otpState.dismissEncryptionMigrationPrompt();
      return;
    }

    try {
      await otpState.migratePlaintextDataToEncryptedVault(password);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local data encrypted and migrated to data.bin'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encryption Failed'),
          content: Text(
            'LibreOTP could not migrate the local data into the encrypted vault.\n\n$e',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _migrationPromptHandled = false;
    }
  }

  Future<void> _showChangeVaultPasswordDialog() async {
    final otpState = Provider.of<OtpState>(context, listen: false);
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const PasswordDialog(mode: PasswordDialogMode.changeVaultPassword),
    );

    if (!mounted || password == null) {
      return;
    }

    try {
      await otpState.changeLocalVaultPassword(password);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault password updated'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Change Failed'),
          content: Text('LibreOTP could not update the vault password.\n\n$e'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleStorageAction(_StorageAction action) async {
    switch (action) {
      case _StorageAction.encryptLocalData:
        await _showEncryptionMigrationPrompt();
        break;
      case _StorageAction.changeVaultPassword:
        await _showChangeVaultPasswordDialog();
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchQuery() {
    final otpState = Provider.of<OtpState>(context, listen: false);
    otpState.setSearchQuery(_searchController.text);
  }

  void _handleTableSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _showEditDialog(BuildContext context, OtpService service) async {
    final result = await showDialog<EditServiceResult>(
      context: context,
      builder: (_) => EditServiceDialog(
        initialName: service.name,
        initialAccount: service.otp.account,
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    context.read<OtpState>().updateServiceDetails(
          serviceId: service.id,
          name: result.name,
          account: result.account,
        );
  }

  void _showDataDirectory(BuildContext context) {
    final otpState = Provider.of<OtpState>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DataDirectoryPage(dataDirectory: otpState.dataDirectory);
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AboutPage();
      },
    );
  }

  void _showImportDialog(BuildContext context) async {
    final otpState = Provider.of<OtpState>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog if there's existing data
    if (otpState.hasExistingData) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import New Backup'),
          content: const Text(
            'This will replace your current data with the imported backup. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Open file picker
    final success = await otpState.reimportData();

    if (success && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Backup imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (otpState.requiresPassword && mounted) {
      // Handle encrypted backup - use the already selected file
      _showPasswordDialogForSelectedFile();
    }
  }

  void _showPasswordDialogForSelectedFile() async {
    final otpState = Provider.of<OtpState>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    if (!mounted) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordDialog(
        mode: PasswordDialogMode.decryptBackup,
        errorMessage: otpState.encryptionError,
        errorKind: otpState.encryptionErrorKind,
      ),
    );

    if (password != null && mounted) {
      final success = await otpState.importSelectedFileWithPassword(password);
      if (success && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Encrypted backup imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (otpState.encryptionError != null && mounted) {
        _showPasswordDialogForSelectedFile(); // Show dialog again with error for same file
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConfig.getAppTitleSync(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                Consumer<OtpState>(
                  builder: (context, otpState, child) {
                    return Text(
                      '${otpState.services.length} services',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.upload_file,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                tooltip: 'Import 2FAS Backup',
                onPressed: () => _showImportDialog(context),
              ),
              IconButton(
                icon: Icon(
                  Icons.folder_open,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                tooltip: 'Show Data Directory',
                onPressed: () => _showDataDirectory(context),
              ),
              Consumer<OtpState>(
                builder: (context, otpState, child) {
                  final items = <PopupMenuEntry<_StorageAction>>[];
                  if (otpState.canEncryptLocalData) {
                    items.add(
                      const PopupMenuItem(
                        value: _StorageAction.encryptLocalData,
                        child: Row(
                          children: [
                            Icon(Icons.lock),
                            SizedBox(width: 8),
                            Text('Encrypt Local Data'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (otpState.usesEncryptedLocalStorage) {
                    items.add(
                      const PopupMenuItem(
                        value: _StorageAction.changeVaultPassword,
                        child: Row(
                          children: [
                            Icon(Icons.password),
                            SizedBox(width: 8),
                            Text('Change Vault Password'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return PopupMenuButton<_StorageAction>(
                    icon: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    tooltip: 'Storage',
                    onSelected: _handleStorageAction,
                    itemBuilder: (_) => items,
                  );
                },
              ),
              PopupMenuButton<ThemeMode>(
                icon: Icon(
                  Icons.brightness_medium,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                tooltip: 'Theme',
                onSelected: widget.onThemeChanged,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: ThemeMode.system,
                    child: Row(
                      children: [
                        Icon(Icons.brightness_auto),
                        SizedBox(width: 8),
                        Text('System'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: ThemeMode.light,
                    child: Row(
                      children: [
                        Icon(Icons.light_mode),
                        SizedBox(width: 8),
                        Text('Light'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: ThemeMode.dark,
                    child: Row(
                      children: [
                        Icon(Icons.dark_mode),
                        SizedBox(width: 8),
                        Text('Dark'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                tooltip: 'About',
                onPressed: () => _showAboutDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: Consumer<OtpState>(
        builder: (context, otpState, child) {
          _checkForEncryptionMigrationPrompt();
          final showFullScreenLoading = otpState.isLoading && !otpState.isBusy;
          late final Widget content;

          if (showFullScreenLoading) {
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Accessing secure storage...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          } else if (otpState.requiresPassword) {
            final isLocalVault = otpState.requiresLocalVaultPassword;
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLocalVault
                        ? 'Encrypted Vault Detected'
                        : 'Encrypted Backup Detected',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLocalVault
                        ? 'Please provide the password to unlock your local vault.'
                        : 'Please provide the password to decrypt your backup.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showPasswordDialog,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Enter Password'),
                  ),
                ],
              ),
            );
          } else if (otpState.encryptionError != null) {
            final isLocalVault = otpState.requiresLocalVaultPassword;
            final isPasswordRelated =
                isLocalVault || otpState.requiresBackupPassword;
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLocalVault
                        ? 'Failed to Unlock Vault'
                        : isPasswordRelated
                            ? 'Failed to Load Backup'
                            : 'Failed to Load Data',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadErrorText(otpState),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => otpState.retryDataLoad(),
                        child: const Text('Retry'),
                      ),
                      if (isPasswordRelated) ...[
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            if (isLocalVault) {
                              _showPasswordDialog();
                            } else {
                              otpState.clearStoredPassword();
                            }
                          },
                          child: const Text('Use Different Password'),
                        ),
                      ],
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showImportDialog(context),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import New Backup'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else if (!otpState.hasExistingData && otpState.services.isEmpty) {
            // Show import UI when no data exists
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to LibreOTP',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import your 2FAS backup to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showImportDialog(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import 2FAS Backup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Export your data from the 2FAS app and select the JSON file',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else {
            content = Stack(
              children: [
                Column(
                  children: [
                    SearchBarWidget(
                      controller: _searchController,
                      onClear: () {
                        _searchController.clear();
                        _updateSearchQuery();
                      },
                      onChanged: (_) => _updateSearchQuery(),
                      displayMode: otpState.displayMode,
                      onDisplayModeChanged: (mode) =>
                          otpState.setDisplayMode(mode),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: OtpTable(
                            groupedServices: otpState.groupedServices,
                            groupNames: otpState.getGroupNames(),
                            onRowTap: (service) => otpState
                                .generateOtpForService(service.id, context),
                            onEditService: (service) =>
                                _showEditDialog(context, service),
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            onSort: (columnIndex, _) => _handleTableSort(
                              columnIndex,
                              _sortColumnIndex == columnIndex
                                  ? !_sortAscending
                                  : true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: content),
              if (otpState.isBusy) const _BusyOverlay(),
            ],
          );
        },
      ),
    );
  }
}

enum _StorageAction { encryptLocalData, changeVaultPassword }

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    final otpState = context.watch<OtpState>();

    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.black54),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      otpState.busyMessage ?? 'Working with encrypted data...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
