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
  bool shouldSimulateFileNotExists = false;
  bool shouldThrowException = false;

  @override
  Future<AppData> loadData({String? password}) async {
    if (shouldThrowException) {
      throw Exception('Test exception');
    }
    // Add a small delay to simulate real behavior but keep it short for tests
    await Future.delayed(const Duration(milliseconds: 5));
    return AppData(groups: _groups, services: _services);
  }

  @override
  Future<File> getLocalFile() async {
    // Use a real temporary file for testing to avoid mocking complexity
    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/test_data.json');
    
    if (!shouldSimulateFileNotExists) {
      // Create the file with test data
      await testFile.writeAsString('''
{
  "groups": [],
  "services": []
}
''');
    } else {
      // Ensure file doesn't exist
      if (await testFile.exists()) {
        await testFile.delete();
      }
    }
    
    return testFile;
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

    setUp(() async {
      mockRepository = MockStorageRepository();
      mockGenerator = MockOtpGenerator();
      otpState = OtpState(mockRepository, mockGenerator);
      // Wait for async initialization to complete before running tests
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() async {
      // Give any pending async operations a chance to complete before disposing
      await Future.delayed(const Duration(milliseconds: 10));
      otpState.dispose();
      // Give a moment for disposal to complete
      await Future.delayed(const Duration(milliseconds: 10));
    });

    group('Initialization', () {
      test('should eventually finish loading', () {
        // Initialization already completed in setUp
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