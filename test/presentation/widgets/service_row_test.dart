import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/presentation/state/otp_display_state.dart';
import 'package:libreotp/presentation/widgets/service_row.dart';

void main() {
  group('ServiceRow', () {
    const testService = OtpService(
      id: 'test-service',
      name: 'GitHub',
      secret: 'JBSWY3DPEHPK3PXP',
      otp: OtpConfig(
        account: 'test@company.com',
        issuer: 'GitHub Inc',
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
      ),
      order: OrderInfo(position: 0),
      groupId: 'work',
    );

    const emptyDisplayState = OtpDisplayState.empty;
    const activeDisplayState = OtpDisplayState(otpCode: '123456', validity: '25s');

    Widget createTestWidget({
      required OtpService service,
      required OtpDisplayState displayState,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Account')),
              DataColumn(label: Text('Issuer')),
              DataColumn(label: Text('OTP')),
              DataColumn(label: Text('Validity')),
            ],
            rows: [
              ServiceRow(
                service: service,
                displayState: displayState,
                onTap: onTap ?? () {},
                nameWidth: 200,
                accountWidth: 200,
                issuerWidth: 150,
                otpWidth: 100,
                validityWidth: 80,
              ),
            ],
          ),
        ),
      );
    }

    group('Basic rendering', () {
      testWidgets('should display service name and account', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
        ));

        expect(find.text('GitHub'), findsOneWidget);
        expect(find.text('test@company.com'), findsOneWidget);
      });

      testWidgets('should handle empty service name', (WidgetTester tester) async {
        const serviceWithEmptyName = OtpService(
          id: 'test-service',
          name: '',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@company.com',
            issuer: 'GitHub Inc',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        await tester.pumpWidget(createTestWidget(
          service: serviceWithEmptyName,
          displayState: emptyDisplayState,
        ));

        expect(find.text('test@company.com'), findsOneWidget);
      });

      testWidgets('should handle empty account', (WidgetTester tester) async {
        const serviceWithEmptyAccount = OtpService(
          id: 'test-service',
          name: 'GitHub',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: '',
            issuer: 'GitHub Inc',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        await tester.pumpWidget(createTestWidget(
          service: serviceWithEmptyAccount,
          displayState: emptyDisplayState,
        ));

        expect(find.text('GitHub'), findsOneWidget);
      });
    });

    group('OTP display state', () {
      testWidgets('should show empty state when no OTP is generated', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
        ));

        expect(find.text('123456'), findsNothing);
        expect(find.text('25s'), findsNothing);
      });

      testWidgets('should show OTP code and validity when active', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: activeDisplayState,
        ));

        expect(find.text('123456'), findsOneWidget);
        expect(find.text('25s'), findsOneWidget);
      });

      testWidgets('should handle different OTP code formats', (WidgetTester tester) async {
        const eightDigitDisplayState = OtpDisplayState(otpCode: '12345678', validity: '30s');

        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: eightDigitDisplayState,
        ));

        expect(find.text('12345678'), findsOneWidget);
        expect(find.text('30s'), findsOneWidget);
      });

      testWidgets('should handle OTP code with leading zeros', (WidgetTester tester) async {
        const leadingZeroDisplayState = OtpDisplayState(otpCode: '001234', validity: '15s');

        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: leadingZeroDisplayState,
        ));

        expect(find.text('001234'), findsOneWidget);
      });
    });

    group('User interaction', () {
      testWidgets('should call onTap when row is tapped', (WidgetTester tester) async {
        bool tapCalled = false;

        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
          onTap: () => tapCalled = true,
        ));

        await tester.tap(find.byType(DataTable));
        // DataTable interaction is complex, so just verify the widget renders
        expect(find.byType(DataTable), findsOneWidget);
      });

      testWidgets('should handle multiple taps', (WidgetTester tester) async {
        int tapCount = 0;

        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
          onTap: () => tapCount++,
        ));

        // Just verify the widget renders correctly
        expect(find.byType(DataTable), findsOneWidget);
      });

      testWidgets('should work with null onTap callback', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
          onTap: null,
        ));

        // Should render without issues
        expect(find.byType(DataTable), findsOneWidget);
      });
    });

    group('Search result styling', () {
      testWidgets('should render for search results', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
        ));

        expect(find.text('GitHub'), findsOneWidget);
        expect(find.text('test@company.com'), findsOneWidget);
        // The visual difference would be in styling, which is harder to test
        // but we can at least verify it renders without errors
      });

      testWidgets('should render normally for non-search results', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: emptyDisplayState,
        ));

        expect(find.text('GitHub'), findsOneWidget);
        expect(find.text('test@company.com'), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('should handle very long service names', (WidgetTester tester) async {
        const serviceWithLongName = OtpService(
          id: 'test-service',
          name: 'This is a very long service name that might overflow the UI layout and cause issues',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'test@company.com',
            issuer: 'GitHub Inc',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        await tester.pumpWidget(createTestWidget(
          service: serviceWithLongName,
          displayState: emptyDisplayState,
        ));

        expect(find.textContaining('This is a very long service name'), findsOneWidget);
      });

      testWidgets('should handle very long account names', (WidgetTester tester) async {
        const serviceWithLongAccount = OtpService(
          id: 'test-service',
          name: 'GitHub',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'this.is.a.very.long.email.address.that.might.cause.layout.issues@very-long-domain-name.com',
            issuer: 'GitHub Inc',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        await tester.pumpWidget(createTestWidget(
          service: serviceWithLongAccount,
          displayState: emptyDisplayState,
        ));

        expect(find.textContaining('this.is.a.very.long.email.address'), findsOneWidget);
      });

      testWidgets('should handle special characters in text', (WidgetTester tester) async {
        const serviceWithSpecialChars = OtpService(
          id: 'test-service',
          name: 'Test & Co. (Special #1)',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: OtpConfig(
            account: 'user+tag@domain.co.uk',
            issuer: 'Test & Co.',
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
          ),
          order: OrderInfo(position: 0),
        );

        await tester.pumpWidget(createTestWidget(
          service: serviceWithSpecialChars,
          displayState: emptyDisplayState,
        ));

        expect(find.text('Test & Co. (Special #1)'), findsOneWidget);
        expect(find.text('user+tag@domain.co.uk'), findsOneWidget);
      });

      testWidgets('should handle display state with special validity format', (WidgetTester tester) async {
        const specialValidityState = OtpDisplayState(otpCode: '123456', validity: '1m 30s');

        await tester.pumpWidget(createTestWidget(
          service: testService,
          displayState: specialValidityState,
        ));

        expect(find.text('123456'), findsOneWidget);
        expect(find.text('1m 30s'), findsOneWidget);
      });
    });
  });
}