import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/display_mode.dart';
import '../../data/models/otp_service.dart';
import '../../data/models/group.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/otp_service.dart';
import '../../utils/clipboard_utils.dart';
import '../../services/local_vault_encryption_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/twofas_icon_service.dart';
import 'otp_display_state.dart';

enum PasswordPromptReason { none, encryptedVault, encryptedBackup }

enum BusyOperation {
  unlockingVault,
  decryptingBackup,
  encryptingLocalData,
  changingVaultPassword,
}

class OtpState extends ChangeNotifier {
  final StorageRepository _storageRepository;
  final OtpGenerator _otpGenerator;

  List<OtpService> _services = [];
  List<Group> _groups = [];
  String _searchQuery = '';
  Map<String, List<OtpService>> _groupedServices = {};
  final Map<String, Timer?> _timers = {};
  final Map<String, OtpDisplayState> _otpDisplayStates = {};
  Timer? _debouncedSaveTimer;
  Timer? _usageResortTimer;
  List<OtpService>? _usageBasedSortCache;
  String _dataDirectory = '';
  bool _isLoading = true;
  bool _requiresPassword = false;
  String? _encryptionError;
  VaultLoadErrorKind? _encryptionErrorKind;
  bool _disposed = false;
  bool _hasExistingData = false;
  String? _selectedFilePath;
  DisplayMode _displayMode = DisplayMode.grouped;
  bool _dataInitialized = false;
  PasswordPromptReason _passwordPromptReason = PasswordPromptReason.none;
  bool _shouldPromptForEncryptionMigration = false;
  bool _encryptionMigrationDismissed = false;
  StorageDataSource _activeStorageSource = StorageDataSource.none;
  String? _localVaultPassword;
  Uint8List? _vaultKey;
  Uint8List? _vaultSalt;
  int? _vaultIterations;
  BusyOperation? _busyOperation;

  // Helper method to yield control to allow UI updates
  Future<void> _yieldToUI([int milliseconds = 16]) async {
    // Give enough time for multiple UI frames - tests will pump through these quickly
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  Future<T> _runBusyOperation<T>(
    BusyOperation operation,
    Future<T> Function() action,
  ) async {
    final changedOperation = _busyOperation != operation;
    if (changedOperation) {
      _busyOperation = operation;
      if (!_disposed) {
        notifyListeners();
      }
      await _yieldToUI();
    }

    try {
      return await action();
    } finally {
      if (_busyOperation == operation) {
        _busyOperation = null;
        if (!_disposed) {
          notifyListeners();
        }
      }
    }
  }

  /// Creates a new OtpState instance.
  ///
  /// In production (when WidgetsBinding is available), initialization is automatically
  /// scheduled after the first frame using [_initializeDataWithYields], which includes
  /// UI yields to prevent blocking the initial render and ensure smooth animations.
  ///
  /// In test environments where WidgetsBinding is not available, initialization is
  /// skipped and tests must manually call [initializeData] to trigger initialization
  /// without UI yields (for faster test execution).
  OtpState(this._storageRepository, this._otpGenerator) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_disposed) {
          await _initializeDataWithYields();
        }
      });
    } catch (e) {
      debugPrint('WidgetsBinding not available, skipping auto-initialization');
    }
  }

  // Getters
  List<OtpService> get services => _services;
  List<Group> get groups => _groups;
  Map<String, List<OtpService>> get groupedServices => _filterAndGroupData();
  String get dataDirectory => _dataDirectory;
  bool get isLoading => _isLoading;
  bool get requiresPassword => _requiresPassword;
  bool get requiresLocalVaultPassword =>
      _passwordPromptReason == PasswordPromptReason.encryptedVault;
  bool get requiresBackupPassword =>
      _passwordPromptReason == PasswordPromptReason.encryptedBackup;
  String? get encryptionError => _encryptionError;
  VaultLoadErrorKind? get encryptionErrorKind => _encryptionErrorKind;
  bool get hasExistingData => _hasExistingData;
  String? get selectedFilePath => _selectedFilePath;
  DisplayMode get displayMode => _displayMode;
  bool get shouldPromptForEncryptionMigration =>
      _shouldPromptForEncryptionMigration;
  bool get usesEncryptedLocalStorage =>
      _activeStorageSource == StorageDataSource.encryptedVault;
  bool get canEncryptLocalData =>
      !usesEncryptedLocalStorage &&
      (_services.isNotEmpty || _groups.isNotEmpty);
  bool get isBusy => _busyOperation != null;
  String? get busyMessage {
    switch (_busyOperation) {
      case BusyOperation.unlockingVault:
        return 'Unlocking encrypted vault...';
      case BusyOperation.decryptingBackup:
        return 'Decrypting encrypted backup...';
      case BusyOperation.encryptingLocalData:
        return 'Encrypting local data...';
      case BusyOperation.changingVaultPassword:
        return 'Updating vault password...';
      case null:
        return null;
    }
  }

  OtpDisplayState getOtpDisplayState(String serviceKey) {
    return _otpDisplayStates[serviceKey] ?? OtpDisplayState.empty;
  }

  @override
  void dispose() {
    _disposed = true;
    _clearVaultSessionKey();
    _cancelAllTimers();
    _debouncedSaveTimer?.cancel();
    _usageResortTimer?.cancel();
    super.dispose();
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer?.cancel();
    }
    _timers.clear();
  }

  void _cancelTimerForService(String serviceKey) {
    // Cancel any existing timers for this service (there might be multiple with different timestamps)
    final keysToRemove =
        _timers.keys.where((key) => key.startsWith('$serviceKey-')).toList();
    for (final key in keysToRemove) {
      _timers[key]?.cancel();
      _timers.remove(key);
    }
  }

  void _scheduleDebouncedSave() {
    // Cancel any pending save
    _debouncedSaveTimer?.cancel();

    // Schedule a new save after 2 seconds of inactivity
    _debouncedSaveTimer = Timer(const Duration(seconds: 2), () async {
      // Never write concurrently with a vault operation (migrate, change
      // password, import) - both paths share the same vault temp file.
      if (_busyOperation != null) {
        _scheduleDebouncedSave();
        return;
      }
      try {
        await _persistCurrentData();
        debugPrint('Usage data saved successfully');
      } catch (e) {
        debugPrint('Error saving usage data: $e');
      }
    });
  }

  /// Production initialization with UI yields for smooth animations.
  ///
  /// This method is called automatically in production after the first frame.
  /// It includes strategic delays (UI yields) to:
  /// - Prevent blocking the initial UI render
  /// - Allow smooth fade-in animations to complete
  /// - Ensure the app feels responsive even during data loading
  ///
  /// The multiple 16ms yields (approximately one frame at 60fps) give the UI
  /// thread time to render frames smoothly during startup.
  Future<void> _initializeDataWithYields() async {
    if (_disposed || _dataInitialized) return;

    _isLoading = true;
    _requiresPassword = false;
    _encryptionError = null;
    _encryptionErrorKind = null;
    _passwordPromptReason = PasswordPromptReason.none;
    if (!_disposed) {
      notifyListeners();
    }

    // Use multiple shorter yields to ensure smooth animation
    for (int i = 0; i < 3; i++) {
      await _yieldToUI(16); // Multiple 16ms yields for smooth startup
      if (_disposed) return;
    }

    await _doInitialization(withUIYields: true);
  }

  /// Test-friendly initialization without UI yields.
  ///
  /// This method should be called manually in tests to trigger initialization.
  /// It skips UI yields for faster test execution since tests use [WidgetTester.pump]
  /// to manually control frame timing and don't need real-time delays.
  ///
  /// Call this in your tests after creating an OtpState instance:
  /// ```dart
  /// final state = OtpState(repository, generator);
  /// await state.initializeData();
  /// ```
  Future<void> initializeData() async {
    if (_disposed) return;

    _isLoading = true;
    _requiresPassword = false;
    _encryptionError = null;
    _encryptionErrorKind = null;
    _passwordPromptReason = PasswordPromptReason.none;
    if (!_disposed) {
      notifyListeners();
    }

    await _doInitialization(withUIYields: false);
  }

  Future<void> _doInitialization({bool withUIYields = false}) async {
    try {
      // Load preferences and file info concurrently
      final results = await Future.wait([
        AppConfig.getDisplayMode().catchError((_) => DisplayMode.grouped),
        _storageRepository.getLocalFile(),
        _storageRepository.hasExistingData(),
        AppConfig.getEncryptionMigrationDismissed().catchError((_) => false),
      ]);
      _displayMode = results[0] as DisplayMode;
      final file = results[1] as File;
      _dataDirectory = file.parent.path;
      _hasExistingData = results[2] as bool;
      _encryptionMigrationDismissed = results[3] as bool;

      // Yield after file system access to keep UI responsive
      if (withUIYields) await _yieldToUI(16);

      final result = await _storageRepository.loadStoredData();

      if (withUIYields) await _yieldToUI(24);

      _applyLoadedData(result);
      _groupedServices = _groupServicesByGroup();

      // Preload icons for imported services asynchronously
      _preloadIconsForServices();
    } on StoragePasswordRequiredException catch (e) {
      _requiresPassword = true;
      _passwordPromptReason = e.source == StorageDataSource.encryptedVault
          ? PasswordPromptReason.encryptedVault
          : PasswordPromptReason.encryptedBackup;
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    } on StorageLoadException catch (e) {
      if (e.source != StorageDataSource.none) {
        _requiresPassword = true;
        _passwordPromptReason = e.source == StorageDataSource.encryptedVault
            ? PasswordPromptReason.encryptedVault
            : PasswordPromptReason.encryptedBackup;
      }
      _encryptionError = e.toString();
      _encryptionErrorKind = e.kind;
      debugPrint(_encryptionError);
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    } catch (e) {
      _encryptionError = 'Error loading data: $e';
      debugPrint(_encryptionError);
    }

    _isLoading = false;
    _dataInitialized = true;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadDataWithPassword(String password) async {
    _isLoading = true;
    _encryptionError = null;
    _encryptionErrorKind = null;
    notifyListeners();

    final busyOperation =
        _passwordPromptReason == PasswordPromptReason.encryptedVault
            ? BusyOperation.unlockingVault
            : BusyOperation.decryptingBackup;

    await _runBusyOperation(busyOperation, () async {
      try {
        final result = await _storageRepository.loadStoredData(
          password: password,
        );
        _applyLoadedData(result, password: password);
        _groupedServices = _groupServicesByGroup();
        _requiresPassword = false;
        _passwordPromptReason = PasswordPromptReason.none;
        _encryptionErrorKind = null;

        if (result.source == StorageDataSource.encryptedVault) {
          await _cacheVaultSessionKey(password);
        }

        // Preload icons for imported services asynchronously
        _preloadIconsForServices();
      } on StoragePasswordRequiredException catch (e) {
        _requiresPassword = true;
        _passwordPromptReason = e.source == StorageDataSource.encryptedVault
            ? PasswordPromptReason.encryptedVault
            : PasswordPromptReason.encryptedBackup;
      } on StorageLoadException catch (e) {
        _encryptionError = e.toString();
        _encryptionErrorKind = e.kind;
        if (e.source == StorageDataSource.none) {
          _requiresPassword = false;
          _passwordPromptReason = PasswordPromptReason.none;
        } else {
          _requiresPassword = true;
          _passwordPromptReason = e.source == StorageDataSource.encryptedVault
              ? PasswordPromptReason.encryptedVault
              : PasswordPromptReason.encryptedBackup;
        }
        debugPrint('Error loading encrypted data: $e');
      } catch (e) {
        _encryptionError = e.toString();
        debugPrint('Error loading encrypted data: $e');
      }
    });

    _isLoading = false;
    notifyListeners();
  }

  void retryDataLoad() {
    initializeData();
  }

  void dismissEncryptionMigrationPrompt() {
    _encryptionMigrationDismissed = true;
    AppConfig.setEncryptionMigrationDismissed(true).catchError((e) {
      debugPrint('Could not persist encryption migration dismissal: $e');
    });
    if (!_shouldPromptForEncryptionMigration) {
      return;
    }
    _shouldPromptForEncryptionMigration = false;
    notifyListeners();
  }

  Future<void> clearStoredPassword() async {
    try {
      await SecureStorageService.clearStoredPassword();
      _requiresPassword = true;
      _encryptionError = null;
      _passwordPromptReason = PasswordPromptReason.encryptedBackup;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing stored password: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _clearUsageSortCache();
    notifyListeners();
  }

  void setDisplayMode(DisplayMode mode) {
    _displayMode = mode;
    _clearUsageSortCache();
    AppConfig.setDisplayMode(mode).catchError((e) {
      debugPrint('Could not persist display mode preference: $e');
    });
    notifyListeners();
  }

  bool updateServiceDetails({
    required String serviceId,
    required String name,
    required String account,
  }) {
    final serviceIndex =
        _services.indexWhere((service) => service.id == serviceId);
    if (serviceIndex == -1) {
      return false;
    }

    final currentService = _services[serviceIndex];
    final updatedName = name.trim();
    final updatedAccount = account.trim();

    if (currentService.name == updatedName &&
        currentService.otp.account == updatedAccount) {
      return true;
    }

    _services[serviceIndex] = currentService.copyWith(
      name: updatedName,
      otp: currentService.otp.copyWith(account: updatedAccount),
    );
    _groupedServices = _groupServicesByGroup();
    _clearUsageSortCache();
    _scheduleDebouncedSave();
    notifyListeners();
    return true;
  }

  void _clearUsageSortCache() {
    _usageResortTimer?.cancel();
    _usageResortTimer = null;
    _usageBasedSortCache = null;
  }

  Map<String, List<OtpService>> _groupServicesByGroup() {
    Map<String, List<OtpService>> groupedData = {};

    // Group services by groupId
    for (var group in _groups) {
      String groupId = group.id;
      groupedData[groupId] = _services
          .where((service) => service.groupId == groupId)
          .toList()
        ..sort((a, b) => a.order.position.compareTo(b.order.position));
    }

    // Add ungrouped services
    groupedData['Ungrouped'] = _services
        .where((service) => service.groupId == null)
        .toList()
      ..sort((a, b) => a.order.position.compareTo(b.order.position));

    return groupedData;
  }

  Map<String, List<OtpService>> _groupServicesByUsage() {
    // Use cached sort if available (prevents immediate re-sort after clicking)
    final List<OtpService> sortedServices;

    if (_usageBasedSortCache != null) {
      // Use cached order - update service data but preserve order
      sortedServices = _usageBasedSortCache!.map((cachedService) {
        // Find the current version of this service with updated usage counts
        return _services.firstWhere(
          (s) => s.id == cachedService.id,
          orElse: () => cachedService,
        );
      }).toList();
    } else {
      // Compute fresh sort
      sortedServices = List<OtpService>.from(_services)
        ..sort((a, b) {
          // Primary sort: usage count (descending)
          final countComparison = b.usageCount.compareTo(a.usageCount);
          if (countComparison != 0) {
            return countComparison;
          }

          // Tie-breaker: last used time (descending - most recent first)
          // Handle null values: never-used items go to the bottom
          if (a.lastUsedAt == null && b.lastUsedAt == null) {
            return 0; // Both never used, maintain stable order
          }
          if (a.lastUsedAt == null) {
            return 1; // a is never used, b wins
          }
          if (b.lastUsedAt == null) {
            return -1; // b is never used, a wins
          }
          return b.lastUsedAt!.compareTo(a.lastUsedAt!);
        });

      // Cache the fresh sort
      _usageBasedSortCache = sortedServices;
    }

    return {'Most Used': sortedServices};
  }

  Map<String, List<OtpService>> _filterAndGroupData() {
    // Get the appropriate grouping based on display mode
    final baseGrouping = _displayMode == DisplayMode.usageBased
        ? _groupServicesByUsage()
        : _groupedServices;

    if (_searchQuery.isEmpty) {
      return baseGrouping;
    }

    Map<String, List<OtpService>> filteredData = {};
    baseGrouping.forEach((groupId, services) {
      final filteredServices = services
          .where(
            (service) =>
                service.name.toLowerCase().contains(_searchQuery) ||
                service.otp.account.toLowerCase().contains(_searchQuery) ||
                service.otp.issuer.toLowerCase().contains(_searchQuery),
          )
          .toList();

      if (filteredServices.isNotEmpty) {
        filteredData[groupId] = filteredServices;
      }
    });

    return filteredData;
  }

  Map<String, String> getGroupNames() {
    Map<String, String> groupNames = {};
    for (var group in _groups) {
      groupNames[group.id] = group.name;
    }
    // Add synthetic "Ungrouped" group name
    groupNames['Ungrouped'] = 'Ungrouped';
    return groupNames;
  }

  void generateOtpForService(String serviceId, BuildContext context) {
    final serviceIndexInList =
        _services.indexWhere((service) => service.id == serviceId);
    if (serviceIndexInList == -1) return;

    final service = _services[serviceIndexInList];
    _generateOtpForResolvedService(service, serviceIndexInList, context);
  }

  void generateOtp(String groupId, int serviceIndex, BuildContext context) {
    final services = groupedServices[groupId];
    if (services == null || serviceIndex >= services.length) return;

    final service = services[serviceIndex];
    final serviceIndexInList = _services.indexWhere((s) => s.id == service.id);
    if (serviceIndexInList == -1) return;

    _generateOtpForResolvedService(service, serviceIndexInList, context);
  }

  void _generateOtpForResolvedService(
    OtpService service,
    int serviceIndexInList,
    BuildContext context,
  ) {
    // Use service ID as the unique key
    final String serviceKey = service.id;

    // Generate fresh OTP code (time-based)
    final String newCode = _otpGenerator.generateOtp(service);
    final int timeRemaining = _otpGenerator.getRemainingSeconds(service);

    // Check if this is a new code (different TOTP period) or first generation
    final existingState = _otpDisplayStates[serviceKey];
    final bool isNewCode =
        existingState == null || existingState.otpCode != newCode;

    // Only increment usage count when the code is different (new TOTP period)
    if (isNewCode) {
      _services[serviceIndexInList] = service.copyWith(
        usageCount: service.usageCount + 1,
        lastUsedAt: DateTime.now().toUtc(),
      );
      _scheduleDebouncedSave();

      // Schedule delayed resort refresh only when usage actually changed
      _scheduleUsageResortRefresh();
    }

    // Create unique timer key using timestamp to allow multiple generations
    final String timerKey =
        '$serviceKey-${DateTime.now().millisecondsSinceEpoch}';

    // Cancel any existing timer for this service
    _cancelTimerForService(serviceKey);

    // Update display state with fresh code
    _otpDisplayStates[serviceKey] = OtpDisplayState(
      otpCode: newCode,
      validity: '${timeRemaining}s',
    );

    // Copy to clipboard
    ClipboardUtils.copyToClipboard(newCode);
    ClipboardUtils.showCopiedNotification(
      context,
      'OTP Code Copied to Clipboard!',
    );

    _startOtpTimer(serviceKey, timerKey, timeRemaining);

    notifyListeners();
  }

  void _scheduleUsageResortRefresh() {
    // Cancel any existing timer
    _usageResortTimer?.cancel();

    // Schedule refresh after 60 seconds
    _usageResortTimer = Timer(const Duration(seconds: 60), () {
      if (!_disposed) {
        // Clear cache to trigger fresh sort on next build
        _usageBasedSortCache = null;
        notifyListeners();
      }
    });
  }

  void _startOtpTimer(String serviceKey, String timerKey, int timeRemaining) {
    // Start a new timer with unique key
    _timers[timerKey] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = _otpDisplayStates[serviceKey];
      if (currentState == null) {
        timer.cancel();
        _timers.remove(timerKey);
        return;
      }

      final secondsLeft =
          int.tryParse(currentState.validity.replaceAll('s', '')) ?? 0;
      if (secondsLeft > 1) {
        _otpDisplayStates[serviceKey] = OtpDisplayState(
          otpCode: currentState.otpCode,
          validity: '${secondsLeft - 1}s',
        );
        notifyListeners();
      } else {
        _otpDisplayStates.remove(serviceKey);
        timer.cancel();
        _timers.remove(timerKey);
        notifyListeners();
      }
    });
  }

  /// Opens a file picker for the user to select a 2FAS backup file
  Future<String?> pickBackupFile() async {
    try {
      return await _storageRepository.pickBackupFile();
    } catch (e) {
      _encryptionError = 'Failed to open file picker: $e';
      notifyListeners();
      return null;
    }
  }

  /// Imports a 2FAS backup file and replaces current data
  Future<bool> importBackupFile(String filePath, {String? password}) async {
    _debouncedSaveTimer?.cancel();
    _isLoading = true;
    _encryptionError = null;
    notifyListeners();

    final busyOperation = password != null
        ? BusyOperation.decryptingBackup
        : usesEncryptedLocalStorage
            ? BusyOperation.encryptingLocalData
            : null;

    Future<bool> performImport() async {
      try {
        final data = await _storageRepository.importBackupFile(
          filePath,
          password: password,
        );
        _services = data.services;
        _groups = data.groups;
        _setStorageModeAfterImport();
        _groupedServices = _groupServicesByGroup();
        _hasExistingData = true;
        _requiresPassword = false;
        _passwordPromptReason = PasswordPromptReason.none;
        _isLoading = false;
        await _persistCurrentData();
        notifyListeners();

        // Preload icons for imported services asynchronously
        _preloadIconsForServices();

        return true;
      } on StoragePasswordRequiredException catch (_) {
        _requiresPassword = true;
        _passwordPromptReason = PasswordPromptReason.encryptedBackup;
        _encryptionError = null;
        _isLoading = false;
        notifyListeners();
        return false;
      } catch (e) {
        _encryptionError = 'Failed to import backup: $e';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    if (busyOperation == null) {
      return performImport();
    }

    return _runBusyOperation(busyOperation, performImport);
  }

  /// Reimports data by opening file picker and importing selected file
  Future<bool> reimportData() async {
    final filePath = await pickBackupFile();
    if (filePath != null) {
      _selectedFilePath = filePath;
      return await importBackupFile(filePath);
    }
    return false;
  }

  /// Imports the currently selected file with a password (for encrypted backups)
  Future<bool> importSelectedFileWithPassword(String password) async {
    if (_selectedFilePath == null) return false;
    return await importBackupFile(_selectedFilePath!, password: password);
  }

  Future<void> migratePlaintextDataToEncryptedVault(String password) async {
    _debouncedSaveTimer?.cancel();
    await _runBusyOperation(BusyOperation.encryptingLocalData, () async {
      final data = AppData(services: _services, groups: _groups);
      await _storageRepository.migratePlaintextDataToEncryptedVault(
        data,
        password,
      );
      _activeStorageSource = StorageDataSource.encryptedVault;
      _localVaultPassword = password;
      await _cacheVaultSessionKey(password);
      _shouldPromptForEncryptionMigration = false;
      _hasExistingData = true;
      notifyListeners();
    });
  }

  Future<void> changeLocalVaultPassword(String password) async {
    if (!usesEncryptedLocalStorage) {
      throw StateError('Encrypted local storage is not active');
    }

    _debouncedSaveTimer?.cancel();
    await _runBusyOperation(BusyOperation.changingVaultPassword, () async {
      final data = AppData(services: _services, groups: _groups);
      await _storageRepository.saveData(
        data,
        source: StorageDataSource.encryptedVault,
        password: password,
        verify: true,
      );
      _localVaultPassword = password;
      await _cacheVaultSessionKey(password);
      notifyListeners();
    });
  }

  /// Preloads icons for the current services asynchronously
  void _preloadIconsForServices() {
    if (_services.isEmpty) return;

    final serviceNames = _services.map((s) => s.name).toList();
    final issuers = _services.map((s) => s.otp.issuer).toList();

    // Preload icons in the background (non-blocking)
    TwoFasIconService.preloadIconsForServices(serviceNames, issuers);
  }

  void _applyLoadedData(LoadedAppData result, {String? password}) {
    _services = result.data.services;
    _groups = result.data.groups;
    _activeStorageSource = result.source;
    _localVaultPassword =
        result.source == StorageDataSource.encryptedVault ? password : null;
    if (result.source != StorageDataSource.encryptedVault) {
      _clearVaultSessionKey();
    }
    _shouldPromptForEncryptionMigration = !_encryptionMigrationDismissed &&
        result.source == StorageDataSource.plaintextJson &&
        (_services.isNotEmpty || _groups.isNotEmpty);
  }

  void _setStorageModeAfterImport() {
    if (_activeStorageSource == StorageDataSource.encryptedVault) {
      _shouldPromptForEncryptionMigration = false;
      return;
    }

    _activeStorageSource = StorageDataSource.plaintextJson;
    _localVaultPassword = null;
    _clearVaultSessionKey();
    _shouldPromptForEncryptionMigration = !_encryptionMigrationDismissed &&
        (_services.isNotEmpty || _groups.isNotEmpty);
  }

  Future<void> _persistCurrentData() async {
    final data = AppData(services: _services, groups: _groups);

    if (_activeStorageSource == StorageDataSource.encryptedVault &&
        _vaultKey != null &&
        _vaultSalt != null &&
        _vaultIterations != null) {
      await _storageRepository.saveEncryptedDataWithKey(
        data,
        _vaultKey!,
        salt: _vaultSalt!,
        iterations: _vaultIterations!,
      );
      await _storageRepository.deletePlaintextData();
      return;
    }

    await _storageRepository.saveData(
      data,
      source: _activeStorageSource,
      password: _localVaultPassword,
    );
  }

  Future<void> _cacheVaultSessionKey(String password) async {
    try {
      final params = await _storageRepository.readVaultKdfParameters();
      _vaultKey = await LocalVaultEncryptionService.deriveKey(
        password,
        params.salt,
        params.iterations,
      );
      _vaultSalt = params.salt;
      _vaultIterations = params.iterations;
    } catch (e) {
      debugPrint('Could not cache vault session key: $e');
      _clearVaultSessionKey();
    }
  }

  void _clearVaultSessionKey() {
    _vaultKey = null;
    _vaultSalt = null;
    _vaultIterations = null;
  }
}
