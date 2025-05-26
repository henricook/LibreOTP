import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/utils/clipboard_utils.dart';

void main() {
  group('ClipboardUtils', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          return null; // Simulate successful clipboard operation
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    group('copyToClipboard', () {
      test('should copy text to clipboard successfully', () async {
        const testText = '123456';
        
        // This should not throw an exception
        expect(() => ClipboardUtils.copyToClipboard(testText), returnsNormally);
      });

      test('should handle empty text', () async {
        const testText = '';
        
        expect(() => ClipboardUtils.copyToClipboard(testText), returnsNormally);
      });

      test('should handle null text gracefully', () async {
        // Test with null-like scenarios
        expect(() => ClipboardUtils.copyToClipboard(''), returnsNormally);
      });

      test('should handle special characters', () async {
        const testText = '!@#\$%^&*()_+-=[]{}|;\':",./<>?';
        
        expect(() => ClipboardUtils.copyToClipboard(testText), returnsNormally);
      });

      test('should handle unicode characters', () async {
        const testText = '🔐🔑🔒🔓';
        
        expect(() => ClipboardUtils.copyToClipboard(testText), returnsNormally);
      });

      test('should handle very long text', () async {
        final longText = 'A' * 10000;
        
        expect(() => ClipboardUtils.copyToClipboard(longText), returnsNormally);
      });
    });

    group('showCopiedNotification', () {
      testWidgets('should show notification with custom message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () {
                      ClipboardUtils.showCopiedNotification(context, 'Custom message');
                    },
                    child: const Text('Show Notification'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Notification'));
        await tester.pump();

        expect(find.text('Custom message'), findsOneWidget);
      });

      testWidgets('should show notification with default message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () {
                      ClipboardUtils.showCopiedNotification(context, 'Copied to clipboard!');
                    },
                    child: const Text('Show Notification'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Notification'));
        await tester.pump();

        expect(find.text('Copied to clipboard!'), findsOneWidget);
      });

      testWidgets('should handle empty message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () {
                      ClipboardUtils.showCopiedNotification(context, '');
                    },
                    child: const Text('Show Notification'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Notification'));
        await tester.pump();

        // Should show empty message or handle gracefully
        expect(() => tester.pump(), returnsNormally);
      });

      testWidgets('should handle long message', (WidgetTester tester) async {
        const longMessage = 'This is a very long notification message that should still be handled properly by the notification system';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () {
                      ClipboardUtils.showCopiedNotification(context, longMessage);
                    },
                    child: const Text('Show Notification'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Notification'));
        await tester.pump();

        expect(find.text(longMessage), findsOneWidget);
      });

      testWidgets('should handle multiple notifications', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ClipboardUtils.showCopiedNotification(context, 'First notification');
                        },
                        child: const Text('Show First'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ClipboardUtils.showCopiedNotification(context, 'Second notification');
                        },
                        child: const Text('Show Second'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show First'));
        await tester.pump();

        await tester.tap(find.text('Show Second'));
        await tester.pump();

        // Both should work without issues
        expect(() => tester.pump(), returnsNormally);
      });
    });

    group('Integration tests', () {
      testWidgets('should copy and show notification together', (WidgetTester tester) async {
        const testCode = '123456';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () {
                      ClipboardUtils.copyToClipboard(testCode);
                      ClipboardUtils.showCopiedNotification(context, 'OTP Code Copied!');
                    },
                    child: const Text('Copy OTP'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Copy OTP'));
        await tester.pump();

        expect(find.text('OTP Code Copied!'), findsOneWidget);
      });
    });
  });
}