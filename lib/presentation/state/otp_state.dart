import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/otp_service.dart';
import '../../data/models/group.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/otp_service.dart';
import '../../utils/clipboard_utils.dart';
import '../../services/twofas_decryption_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/twofas_icon_service.dart';
import 'otp_display_state.dart';

class OtpState extends ChangeNotifier {
  final StorageRepository _storageRepository;
  final OtpGenerator _otpGenerator;

  List<OtpService> _services = [];
  List<Group> _groups = [];
  String _searchQuery = '';
  Map<String, List<OtpService>> _groupedServices = {};
  final Map<String, Timer?> _timers = {};
  final Map<String, OtpDisplayState> _otpDisplayStates = {};
  String _dataDirectory = '';
  bool _isLoading = true;
  bool _requiresPassword = false;
  String? _encryptionError;
  bool _disposed = false;
  bool _hasExistingData = false;
  String? _selectedFilePath;

  // Helper method to yield control to allow UI updates
  Future<void> _yieldToUI([int milliseconds = 16]) async {
    // Give enough time for multiple UI frames - tests will pump through these quickly
    await Future.delayed(Duration(milliseconds: milliseconds));
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
  String? get encryptionError => _encryptionError;
  bool get hasExistingData => _hasExistingData;
  String? get selectedFilePath => _selectedFilePath;

  OtpDisplayState getOtpDisplayState(String serviceKey) {
    return _otpDisplayStates[serviceKey] ?? OtpDisplayState.empty;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelAllTimers();
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
    if (_disposed) return;

    _isLoading = true;
    _requiresPassword = false;
    _encryptionError = null;
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
    if (!_disposed) {
      notifyListeners();
    }

    await _doInitialization(withUIYields: false);
  }

  Future<void> _doInitialization({bool withUIYields = false}) async {
    try {
      // Check if file exists and if it's encrypted
      final file = await _storageRepository.getLocalFile();
      _dataDirectory = file.parent.path;
      _hasExistingData = await _storageRepository.hasExistingData();

      // Yield after file system access to keep UI responsive
      if (withUIYields) await _yieldToUI(16);

      if (await file.exists()) {
        final contents = await file.readAsString();

        // Yield after file read to keep UI responsive
        if (withUIYields) await _yieldToUI(24);

        final jsonData = jsonDecode(contents) as Map<String, dynamic>;

        // Yield after JSON parsing to keep UI responsive
        if (withUIYields) await _yieldToUI(16);

        if (TwoFasDecryptionService.isEncrypted(jsonData)) {
          // Try to load with stored password first
          try {
            final data = await _storageRepository.loadData();

            // Yield after secure storage access to keep UI responsive
            if (withUIYields) await _yieldToUI(32);

            _services = data.services;
            _groups = data.groups;

            // Yield before data processing to keep UI responsive
            if (withUIYields) await _yieldToUI(16);

            _groupedServices = _groupServicesByGroup();
            _isLoading = false;
            if (!_disposed) {
              notifyListeners();
            }

            // Preload icons for imported services asynchronously
            _preloadIconsForServices();

            return;
          } catch (e) {
            // If stored password failed, require manual password entry
            if (e.toString().contains('Password required')) {
              _requiresPassword = true;
              _isLoading = false;
              if (!_disposed) {
                notifyListeners();
              }
              return;
            } else {
              // Other errors (like wrong stored password) should be handled
              _encryptionError = 'Failed to decrypt backup: ${e.toString()}';
              _requiresPassword = true;
              _isLoading = false;
              if (!_disposed) {
                notifyListeners();
              }
              return;
            }
          }
        }
      }

      final data = await _storageRepository.loadData();
      _services = data.services;
      _groups = data.groups;
      _groupedServices = _groupServicesByGroup();

      // Preload icons for imported services asynchronously
      _preloadIconsForServices();
    } catch (e) {
      _encryptionError = 'Error loading data: $e';
      debugPrint(_encryptionError);
    }

    _isLoading = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadDataWithPassword(String password) async {
    _isLoading = true;
    _encryptionError = null;
    notifyListeners();

    try {
      final data = await _storageRepository.loadData(password: password);
      _services = data.services;
      _groups = data.groups;
      _groupedServices = _groupServicesByGroup();
      _requiresPassword = false;

      // Preload icons for imported services asynchronously
      _preloadIconsForServices();
    } catch (e) {
      _encryptionError = e.toString();
      debugPrint('Error loading encrypted data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void retryDataLoad() {
    initializeData();
  }

  Future<void> clearStoredPassword() async {
    try {
      await SecureStorageService.clearStoredPassword();
      _requiresPassword = true;
      _encryptionError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing stored password: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
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

  Map<String, List<OtpService>> _filterAndGroupData() {
    if (_searchQuery.isEmpty) {
      return _groupedServices;
    }

    Map<String, List<OtpService>> filteredData = {};
    _groupedServices.forEach((groupId, services) {
      final filteredServices = services
          .where((service) =>
              service.name.toLowerCase().contains(_searchQuery) ||
              service.otp.account.toLowerCase().contains(_searchQuery) ||
              service.otp.issuer.toLowerCase().contains(_searchQuery))
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

  void generateOtp(String groupId, int serviceIndex, BuildContext context) {
    final services = groupedServices[groupId];
    if (services == null || serviceIndex >= services.length) return;

    final service = services[serviceIndex];

    // Create unique service key using group and index to ensure uniqueness
    final String serviceKey = '$groupId-$serviceIndex';

    // Generate fresh OTP code each time (time-based)
    final String newCode = _otpGenerator.generateOtp(service);
    final int timeRemaining = _otpGenerator.getRemainingSeconds(service);

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
        context, 'OTP Code Copied to Clipboard!');

    _startOtpTimer(serviceKey, timerKey, timeRemaining);

    notifyListeners();
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
    _isLoading = true;
    _encryptionError = null;
    notifyListeners();

    try {
      final data = await _storageRepository.importBackupFile(filePath,
          password: password);
      _services = data.services;
      _groups = data.groups;
      _groupedServices = _groupServicesByGroup();
      _hasExistingData = true;
      _requiresPassword = false;
      _isLoading = false;
      notifyListeners();

      // Preload icons for imported services asynchronously
      _preloadIconsForServices();

      return true;
    } catch (e) {
      if (e.toString().contains('Password required')) {
        _requiresPassword = true;
        _encryptionError = null;
      } else {
        _encryptionError = 'Failed to import backup: $e';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
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

  /// Preloads icons for the current services asynchronously
  void _preloadIconsForServices() {
    if (_services.isEmpty) return;

    final serviceNames = _services.map((s) => s.name).toList();
    final issuers = _services.map((s) => s.otp.issuer).toList();

    // Preload icons in the background (non-blocking)
    TwoFasIconService.preloadIconsForServices(serviceNames, issuers);
  }
}
