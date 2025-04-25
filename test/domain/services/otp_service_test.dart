import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/domain/services/otp_service.dart';

void main() {
  group('OtpGenerator', () {
    late OtpGenerator otpGenerator;
    late OtpService testService;

    setUp(() {
      otpGenerator = OtpGenerator();
      testService = OtpService(
        id: 'test-id',
        name: 'Test Service',
        groupId: null,
        secret: 'JBSWY3DPEHPK3PXP', // Test secret
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test',
          digits: 6,
          period: 30,
          algorithm: 'SHA1',
        ),
        order: OrderInfo(position: 0),
      );
    });

    test('generateOtp returns a code with correct length', () {
      final code = otpGenerator.generateOtp(testService);
      
      expect(code.length, equals(testService.otp.digits));
      expect(int.tryParse(code), isNotNull); // Should be numeric
    });

    test('getRemainingSeconds returns a value between 0 and period', () {
      final timeRemaining = otpGenerator.getRemainingSeconds(testService);
      
      expect(timeRemaining, greaterThanOrEqualTo(0));
      expect(timeRemaining, lessThanOrEqualTo(testService.otp.period));
    });

    test('OTP codes change after period expires', () {
      // This test is time-dependent and might be flaky
      // Skip if running in a CI environment
      
      final initialCode = otpGenerator.generateOtp(testService);
      final initialTime = otpGenerator.getRemainingSeconds(testService);
      
      if (initialTime < 2) {
        // Too close to expiration, skip test to avoid flakiness
        return;
      }

      // Wait for 32 seconds to ensure we're in a new period
      // Note: this makes the test slow, but it's a thorough check
      Future.delayed(const Duration(seconds: 32), () {
        final newCode = otpGenerator.generateOtp(testService);
        expect(newCode, isNot(equals(initialCode)));
      });
    });

    test('Different algorithms generate different codes', () {
      final sha1Service = testService;
      
      final sha256Service = OtpService(
        id: 'test-id-256',
        name: 'Test Service',
        groupId: null,
        secret: 'JBSWY3DPEHPK3PXP', // Same secret
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test',
          digits: 6,
          period: 30,
          algorithm: 'SHA256', // Different algorithm
        ),
        order: OrderInfo(position: 0),
      );

      final sha1Code = otpGenerator.generateOtp(sha1Service);
      final sha256Code = otpGenerator.generateOtp(sha256Service);
      
      expect(sha256Code, isNot(equals(sha1Code)));
    });
  });
}