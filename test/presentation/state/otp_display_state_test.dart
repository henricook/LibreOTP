import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/presentation/state/otp_display_state.dart';

void main() {
  group('OtpDisplayState', () {
    test('should create an OtpDisplayState with all fields', () {
      const displayState = OtpDisplayState(
        otpCode: '123456',
        validity: '25s',
      );

      expect(displayState.otpCode, equals('123456'));
      expect(displayState.validity, equals('25s'));
    });

    test('should provide empty constant', () {
      const emptyState = OtpDisplayState.empty;

      expect(emptyState.otpCode, equals(''));
      expect(emptyState.validity, equals(''));
    });

    test('should handle equality correctly', () {
      const state1 = OtpDisplayState(
        otpCode: '123456',
        validity: '25s',
      );

      const state2 = OtpDisplayState(
        otpCode: '123456',
        validity: '25s',
      );

      const state3 = OtpDisplayState(
        otpCode: '654321',
        validity: '25s',
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should have consistent hashCode', () {
      const state1 = OtpDisplayState(
        otpCode: '123456',
        validity: '25s',
      );

      const state2 = OtpDisplayState(
        otpCode: '123456',
        validity: '25s',
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('should handle empty states correctly', () {
      const emptyState1 = OtpDisplayState.empty;
      const emptyState2 = OtpDisplayState(otpCode: '', validity: '');

      expect(emptyState1, equals(emptyState2));
      expect(emptyState1.hashCode, equals(emptyState2.hashCode));
    });
  });
}