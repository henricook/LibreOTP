import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/presentation/widgets/secret_export_dialog.dart';

void main() {
  const service = OtpService(
    id: 'service-1',
    name: 'GitHub',
    secret: 'jbswy3dpehpk3pxp',
    otp: OtpConfig(account: 'me@example.com', issuer: 'GitHub'),
    order: OrderInfo(position: 0),
  );

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SecretExportDialog(service: service)),
      ),
    );
  }

  testWidgets('shows the secret and otpauth URI', (tester) async {
    await pumpDialog(tester);

    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    expect(find.text(service.toOtpAuthUri()), findsOneWidget);
    expect(find.text('me@example.com - GitHub'), findsOneWidget);
  });

  testWidgets('copies the secret and URI to the clipboard', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byTooltip('Copy Secret key'));
    await tester.pump();
    expect(clipboardText, equals('JBSWY3DPEHPK3PXP'));
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byTooltip('Copy otpauth URI'));
    await tester.pump();
    expect(clipboardText, equals(service.toOtpAuthUri()));
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
