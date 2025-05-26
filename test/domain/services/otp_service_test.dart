import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/domain/services/otp_service.dart';

void main() {
  group('OtpGenerator', () {
    late OtpGenerator otpGenerator;

    setUp(() {
      otpGenerator = OtpGenerator();
    });

    group('generateOtp', () {
      test('should generate 6-digit OTP for TOTP service', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP', // "Hello" in base32
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp = otpGenerator.generateOtp(service);

        expect(otp, isA<String>());
        expect(otp.length, equals(6));
        expect(int.tryParse(otp), isNotNull);
      });

      test('should generate 8-digit OTP when specified', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 8,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp = otpGenerator.generateOtp(service);

        expect(otp.length, equals(8));
        expect(int.tryParse(otp), isNotNull);
      });

      test('should generate different OTPs for different secrets', () {
        const service1 = OtpService(
          id: 'test-service-1',
          name: 'Test Service 1',
          secret: 'JBSWY3DPEHPK3PXP', // "Hello"
          otp: OtpConfig(
            account: 'test1@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        const service2 = OtpService(
          id: 'test-service-2',
          name: 'Test Service 2',
          secret: 'KRUGKIDROVUWG2ZAMJZG653OEBYB64DTLKXWK3DPMV2HK4RAHUQG', // Different secret
          otp: OtpConfig(
            account: 'test2@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp1 = otpGenerator.generateOtp(service1);
        final otp2 = otpGenerator.generateOtp(service2);

        expect(otp1, isNot(equals(otp2)));
      });

      test('should handle SHA256 algorithm', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA256',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp = otpGenerator.generateOtp(service);

        expect(otp, isA<String>());
        expect(otp.length, equals(6));
        expect(int.tryParse(otp), isNotNull);
      });

      test('should handle SHA512 algorithm', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA512',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp = otpGenerator.generateOtp(service);

        expect(otp, isA<String>());
        expect(otp.length, equals(6));
        expect(int.tryParse(otp), isNotNull);
      });

      test('should handle custom period', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 60, // 1 minute period
          ),
          order: OrderInfo(position: 0),
        );

        final otp = otpGenerator.generateOtp(service);

        expect(otp, isA<String>());
        expect(otp.length, equals(6));
        expect(int.tryParse(otp), isNotNull);
      });

      test('should pad OTP with leading zeros if necessary', () {
        // Test multiple times to increase chance of getting a number that would need padding
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        for (int i = 0; i < 10; i++) {
          final otp = otpGenerator.generateOtp(service);
          expect(otp.length, equals(6));
          expect(RegExp(r'^\d{6}$').hasMatch(otp), isTrue);
        }
      });

      test('should handle invalid base32 secret gracefully', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'invalid-base32!@#', // Invalid base32
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        expect(() => otpGenerator.generateOtp(service), throwsA(isA<Exception>()));
      });
    });

    group('getRemainingSeconds', () {
      test('should return remaining seconds in current period', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final remaining = otpGenerator.getRemainingSeconds(service);

        expect(remaining, isA<int>());
        expect(remaining, greaterThan(0));
        expect(remaining, lessThanOrEqualTo(30));
      });

      test('should return correct remaining seconds for custom period', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 60,
          ),
          order: OrderInfo(position: 0),
        );

        final remaining = otpGenerator.getRemainingSeconds(service);

        expect(remaining, isA<int>());
        expect(remaining, greaterThan(0));
        expect(remaining, lessThanOrEqualTo(60));
      });

      test('should handle period of 1 second', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 1,
          ),
          order: OrderInfo(position: 0),
        );

        final remaining = otpGenerator.getRemainingSeconds(service);

        expect(remaining, equals(1));
      });
    });

    group('Time-based generation', () {
      test('should generate same OTP for same time window', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        final otp1 = otpGenerator.generateOtp(service);
        final otp2 = otpGenerator.generateOtp(service);

        // Should be the same since generated within the same time window
        expect(otp1, equals(otp2));
      });

      test('should generate fresh OTP each call based on current time', () {
        const service = OtpService(
          id: 'test-service',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@example.com',
            issuer: 'Test Issuer',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        // Generate multiple OTPs to ensure the method works consistently
        final otps = <String>[];
        for (int i = 0; i < 5; i++) {
          otps.add(otpGenerator.generateOtp(service));
        }

        // All should be valid 6-digit numbers
        for (final otp in otps) {
          expect(otp.length, equals(6));
          expect(int.tryParse(otp), isNotNull);
        }

        // Since we're in the same time window, they should all be the same
        expect(otps.toSet().length, equals(1));
      });
    });
  });
}