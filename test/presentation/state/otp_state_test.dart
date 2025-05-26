import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/group.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/domain/services/otp_service.dart';
import 'package:libreotp/presentation/state/otp_display_state.dart';
import 'package:libreotp/presentation/state/otp_state.dart';

// Mock classes
class MockStorageRepository extends StorageRepository {
  List<Group> _groups = [];
  List<OtpService> _services = [];

  @override
  Future<AppData> loadData() async {
    return AppData(groups: _groups, services: _services);
  }

  @override
  Future<File> getLocalFile() async {
    // Return a mock file for testing
    return File('/test/path/data.json');
  }

  // Test helper methods
  void setTestData(List<Group> groups, List<OtpService> services) {
    _groups = groups;
    _services = services;
  }
}

class MockOtpGenerator extends OtpGenerator {
  String _nextCode = '123456';
  int _nextRemainingSeconds = 25;

  @override
  String generateOtp(OtpService service) => _nextCode;

  @override
  int getRemainingSeconds(OtpService service) => _nextRemainingSeconds;

  // Test helper methods
  void setNextCode(String code) => _nextCode = code;
  void setNextRemainingSeconds(int seconds) => _nextRemainingSeconds = seconds;
}

void main() {
  group('OtpState', () {
    late MockStorageRepository mockRepository;
    late MockOtpGenerator mockGenerator;
    late OtpState otpState;

    setUp(() {
      mockRepository = MockStorageRepository();
      mockGenerator = MockOtpGenerator();
      otpState = OtpState(mockRepository, mockGenerator);
    });

    tearDown(() {
      otpState.dispose();
    });

    group('Initialization', () {
      test('should eventually finish loading', () async {
        // Wait for async initialization to complete
        await Future.delayed(const Duration(milliseconds: 10));
        expect(otpState.isLoading, isFalse);
      });

      test('should create OtpState instance', () {
        expect(otpState, isA<OtpState>());
        expect(otpState.services, isA<List<OtpService>>());
        expect(otpState.groups, isA<List<Group>>());
      });
    });

    group('Search functionality', () {
      test('should have setSearchQuery method', () {
        expect(() => otpState.setSearchQuery('test'), returnsNormally);
      });

      test('should access groupedServices without error', () {
        expect(() => otpState.groupedServices, returnsNormally);
        expect(otpState.groupedServices, isA<Map<String, List<OtpService>>>());
      });
    });

    group('OTP generation', () {
      test('should return empty display state for non-existent service', () {
        final displayState = otpState.getOtpDisplayState('non-existent');
        expect(displayState, equals(OtpDisplayState.empty));
      });

      testWidgets('should handle generateOtp method calls', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: Container()));
        final context = tester.element(find.byType(Container));

        expect(() => otpState.generateOtp('invalid-group', 0, context), returnsNormally);
      });
    });

    group('Group names', () {
      test('should have getGroupNames method', () {
        expect(() => otpState.getGroupNames(), returnsNormally);
        expect(otpState.getGroupNames(), isA<Map<String, String>>());
      });
    });

    group('State notifications', () {
      test('should be a ChangeNotifier', () {
        expect(otpState, isA<ChangeNotifier>());
        expect(() => otpState.addListener(() {}), returnsNormally);
        expect(() => otpState.removeListener(() {}), returnsNormally);
      });
    });
  });
}