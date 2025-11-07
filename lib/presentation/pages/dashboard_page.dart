import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../state/otp_state.dart';
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
  final bool _sortAscending = true;

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

  void _showPasswordDialog() async {
    final otpState = Provider.of<OtpState>(context, listen: false);

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordDialog(
        errorMessage: otpState.encryptionError,
      ),
    );

    if (password != null && mounted) {
      await otpState.loadDataWithPassword(password);
      if (otpState.encryptionError != null && mounted) {
        _showPasswordDialog(); // Show dialog again with error
      }
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
              'This will replace your current data with the imported backup. Are you sure you want to continue?'),
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
        errorMessage: otpState.encryptionError,
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
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.upload_file, color: Theme.of(context).colorScheme.onPrimary),
                tooltip: 'Import 2FAS Backup',
                onPressed: () => _showImportDialog(context),
              ),
              IconButton(
                icon: Icon(Icons.folder_open, color: Theme.of(context).colorScheme.onPrimary),
                tooltip: 'Show Data Directory',
                onPressed: () => _showDataDirectory(context),
              ),
              PopupMenuButton<ThemeMode>(
                icon: Icon(Icons.brightness_medium, color: Theme.of(context).colorScheme.onPrimary),
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
                icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onPrimary),
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
          if (otpState.isLoading) {
            return Center(
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
          }

          if (otpState.requiresPassword) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text(
                    'Encrypted Backup Detected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please provide the password to decrypt your backup.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          }

          if (otpState.encryptionError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to Load Backup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    otpState.encryptionError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () => otpState.clearStoredPassword(),
                        child: const Text('Use Different Password'),
                      ),
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
          }

          // Show import UI when no data exists
          if (!otpState.hasExistingData && otpState.services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to LibreOTP',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import your 2FAS backup to get started',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showImportDialog(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import 2FAS Backup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Export your data from the 2FAS app and select the JSON file',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Stack(
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
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: OtpTable(
                            groupedServices: otpState.groupedServices,
                            groupNames: otpState.getGroupNames(),
                            onRowTap: (groupId, index) =>
                                otpState.generateOtp(groupId, index, context),
                            sortAscending: _sortAscending,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
