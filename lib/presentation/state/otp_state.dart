import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/otp_service.dart';
import '../../data/models/group.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/otp_service.dart';
import '../../utils/clipboard_utils.dart';
import 'otp_display_state.dart';

class OtpState extends ChangeNotifier {
  final StorageRepository _storageRepository;
  final OtpGenerator _otpGenerator;

  List<OtpService> _services = [];
  List<Group> _groups = [];
  String _searchQuery = '';
  Map<String, List<OtpService>> _groupedServices = {};
  final bool _showNotification = false;
  final Map<String, Timer?> _timers = {};
  final Map<String, OtpDisplayState> _otpDisplayStates = {};
  String _dataDirectory = '';
  bool _isLoading = true;

  OtpState(this._storageRepository, this._otpGenerator) {
    _initializeData();
  }

  // Getters
  List<OtpService> get services => _services;
  List<Group> get groups => _groups;
  Map<String, List<OtpService>> get groupedServices => _filterAndGroupData();
  bool get showNotification => _showNotification;
  String get dataDirectory => _dataDirectory;
  bool get isLoading => _isLoading;

  OtpDisplayState getOtpDisplayState(String serviceKey) {
    return _otpDisplayStates[serviceKey] ?? OtpDisplayState.empty;
  }

  @override
  void dispose() {
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
    final keysToRemove = _timers.keys.where((key) => key.startsWith('$serviceKey-')).toList();
    for (final key in keysToRemove) {
      _timers[key]?.cancel();
      _timers.remove(key);
    }
  }

  // Methods
  Future<void> _initializeData() async {
    _isLoading = true;
    notifyListeners();

    final data = await _storageRepository.loadData();
    _services = data.services;
    _groups = data.groups;

    // Get the data directory path
    final file = await _storageRepository.getLocalFile();
    _dataDirectory = file.parent.path;

    _groupedServices = _groupServicesByGroup();

    _isLoading = false;
    notifyListeners();
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
    final String timerKey = '$serviceKey-${DateTime.now().millisecondsSinceEpoch}';

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
}
