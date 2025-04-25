import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../data/models/otp_service.dart';
import '../../data/models/group.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/otp_service.dart';
import '../../domain/services/timer_service.dart';
import '../../utils/clipboard_utils.dart';
import '../../utils/error_utils.dart';

class OtpState extends ChangeNotifier {
  final StorageRepository _storageRepository;
  final OtpGenerator _otpGenerator;
  late final TimerService _timerService;
  
  List<OtpService> _services = [];
  List<Group> _groups = [];
  String _searchQuery = '';
  Map<String, List<OtpService>> _groupedServices = {};
  bool _showNotification = false;
  String _dataDirectory = '';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  OtpState(this._storageRepository, this._otpGenerator) {
    _timerService = TimerService(
      onTimerTick: (_) => notifyListeners(),
      onTimerComplete: (_) => notifyListeners(),
    );
    _initializeData();
  }
  
  // Getters
  List<OtpService> get services => _services;
  List<Group> get groups => _groups;
  Map<String, List<OtpService>> get groupedServices => _filterAndGroupData();
  bool get showNotification => _showNotification;
  String get dataDirectory => _dataDirectory;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  
  @override
  void dispose() {
    _timerService.cancelAllTimers();
    super.dispose();
  }
  
  // Methods
  Future<void> _initializeData() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    
    try {
      final data = await _storageRepository.loadData();
      _services = data.services;
      _groups = data.groups;
      
      // Get the data directory path
      final file = await _storageRepository.getLocalFile();
      _dataDirectory = file.parent.path;
      
      _groupedServices = _groupServicesByGroup();
    } catch (e, stackTrace) {
      _hasError = true;
      _errorMessage = 'Failed to load OTP data: ${e.toString()}';
      ErrorUtils.logError(
        kErrorLoadingData,
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.error
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshData() async {
    await _initializeData();
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
    groupedData[kUngroupedId] = _services
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
      final filteredServices = services.where((service) =>
        service.name.toLowerCase().contains(_searchQuery) ||
        service.otp.account.toLowerCase().contains(_searchQuery) ||
        service.otp.issuer.toLowerCase().contains(_searchQuery)
      ).toList();
      
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
    groupNames[kUngroupedId] = kUngroupedName;
    return groupNames;
  }
  
  void generateOtp(String groupId, int serviceIndex, BuildContext context) {
    try {
      final services = groupedServices[groupId];
      if (services == null || serviceIndex >= services.length) return;
      
      final service = services[serviceIndex];
      
      // Generate OTP code
      final String newCode = _otpGenerator.generateOtp(service);
      final int timeRemaining = _otpGenerator.getRemainingSeconds(service);
      
      service.otpCode = newCode;
      service.validity = '${timeRemaining}s';
      
      // Copy to clipboard
      ClipboardUtils.copyToClipboard(newCode);
      ClipboardUtils.showCopiedNotification(context, kOtpCopiedMessage);
      
      // Start timer
      final String timerId = '$groupId-$serviceIndex';
      _timerService.startTimer(timerId, service, timeRemaining);
      
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorUtils.logError(
        'Failed to generate OTP code',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.error
      );
      ErrorUtils.showErrorSnackbar(context, 'Failed to generate OTP code');
    }
  }
}