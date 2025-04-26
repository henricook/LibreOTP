import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/utils/error_utils.dart';

void main() {
  group('ErrorUtils', () {
    testWidgets('showErrorSnackbar displays a snackbar with the error message', (WidgetTester tester) async {
      // Build a test app with scaffold
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorUtils.showErrorSnackbar(context, 'Test error message');
                  },
                  child: const Text('Show Error'),
                );
              },
            ),
          ),
        ),
      );
      
      // Tap button to trigger the snackbar
      await tester.tap(find.text('Show Error'));
      await tester.pump(); // Build scheduled animation frames
      
      // Verify snackbar appears with correct message
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.text('DISMISS'), findsOneWidget);
    });
    
    testWidgets('showErrorDialog displays a dialog with the error message', (WidgetTester tester) async {
      // Build a test app with scaffold
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorUtils.showErrorDialog(
                      context, 
                      'Error Title',
                      'Test error message'
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );
      
      // Tap button to trigger the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle(); // Wait for dialog animation
      
      // Verify dialog appears with correct title and message
      expect(find.text('Error Title'), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      
      // Test dismissing the dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      
      // Verify dialog is dismissed
      expect(find.text('Error Title'), findsNothing);
    });
    
    test('logError logs error information', () {
      // This is mostly a smoke test since we can't easily verify debug prints
      // in flutter_test, but it ensures the method doesn't throw
      
      expect(() => ErrorUtils.logError(
        'Test error message',
        error: Exception('Test exception'),
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.warning
      ), returnsNormally);
    });
  });
}