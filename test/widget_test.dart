// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:libreotp/config/app_config.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/domain/services/otp_service.dart';
import 'package:libreotp/presentation/state/otp_state.dart';
import 'package:libreotp/main.dart';

void main() {
  testWidgets('App title is shown', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => OtpState(StorageRepository(), OtpGenerator()),
        child: const LibreOTPApp(),
      ),
    );

    // Pump with duration to handle async operations and timers
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the app name is shown somewhere in the UI
    expect(find.textContaining('LibreOTP'), findsOneWidget);
  });
}
