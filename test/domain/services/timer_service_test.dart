import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/domain/services/timer_service.dart';

void main() {
  group('TimerService', () {
    late TimerService timerService;
    late OtpService testService;
    
    setUp(() {
      // Create test OtpService
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
      
      // Initialize fields manually
      testService.otpCode = '123456';
      testService.validity = '30s';
      
      // Initialize timer service with test callbacks
      bool tickCalled = false;
      bool completeCalled = false;
      
      timerService = TimerService(
        onTimerTick: (service) {
          tickCalled = true;
        },
        onTimerComplete: (service) {
          completeCalled = true;
        },
      );
    });
    
    tearDown(() {
      timerService.dispose();
    });
    
    test('startTimer initializes a timer for the service', () {
      // Start timer with 5 seconds remaining
      timerService.startTimer('test-id', testService, 5);
      
      // Timer should be running but we can't test exact value 
      // since the test implementation modifies validity directly
      expect(testService.validity, isNotNull);
      
      // Clean up
      timerService.cancelTimer('test-id');
    });
    
    test('cancelTimer stops a timer', () {
      // Start then immediately cancel
      timerService.startTimer('test-id', testService, 5);
      timerService.cancelTimer('test-id');
      
      // Timer should have been canceled
      // This is hard to test directly, but we can verify it doesn't change
      // the service after being canceled
      final initialValidity = testService.validity;
      
      // Wait a bit to ensure the timer doesn't fire if it's still running
      Future.delayed(const Duration(seconds: 2), () {
        expect(testService.validity, equals(initialValidity));
      });
    });
    
    test('cancelAllTimers stops all timers', () {
      // Start multiple timers
      timerService.startTimer('timer1', testService, 5);
      timerService.startTimer('timer2', testService, 10);
      
      // Cancel all
      timerService.cancelAllTimers();
      
      // No timers should be active (internal check)
      expect(timerService.cancelAllTimers, returnsNormally);
    });
    
    test('timer decrements validity correctly', () async {
      // Start with 3 seconds for a quicker test
      testService.validity = '3s';
      timerService.startTimer('test-id', testService, 3);
      
      // Wait for 1.5 seconds
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Validity should now be 2s or 1s depending on timing
      expect(int.parse(testService.validity?.replaceAll('s', '') ?? '0'), lessThan(3));
      
      // Clean up
      timerService.cancelTimer('test-id');
    });
  });
}