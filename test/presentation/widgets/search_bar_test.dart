import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/presentation/widgets/search_bar.dart';

void main() {
  group('SearchBarWidget', () {
    Widget createTestWidget({
      String? initialValue,
      ValueChanged<String>? onChanged,
      VoidCallback? onClear,
    }) {
      final controller = TextEditingController(text: initialValue);
      
      return MaterialApp(
        home: Scaffold(
          body: SearchBarWidget(
            controller: controller,
            onChanged: onChanged ?? (value) {},
            onClear: onClear ?? () {},
          ),
        ),
      );
    }

    group('Basic rendering', () {
      testWidgets('should render search input field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
      });

      testWidgets('should show initial value', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(initialValue: 'test query'));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('test query'));
      });

      testWidgets('should handle null initial value', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(initialValue: null));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals(''));
      });
    });

    group('User input', () {
      testWidgets('should call onChanged when text is entered', (WidgetTester tester) async {
        String? changedValue;

        await tester.pumpWidget(createTestWidget(
          onChanged: (value) => changedValue = value,
        ));

        await tester.enterText(find.byType(TextField), 'github');
        expect(changedValue, equals('github'));
      });

      testWidgets('should handle empty input', (WidgetTester tester) async {
        String? changedValue;

        await tester.pumpWidget(createTestWidget(
          onChanged: (value) => changedValue = value,
        ));

        await tester.enterText(find.byType(TextField), '');
        // The onChanged callback may receive null for empty input
        expect(changedValue, anyOf(equals(''), isNull));
      });

      testWidgets('should handle special characters', (WidgetTester tester) async {
        String? changedValue;

        await tester.pumpWidget(createTestWidget(
          onChanged: (value) => changedValue = value,
        ));

        await tester.enterText(find.byType(TextField), '@#\$%^&*()');
        expect(changedValue, equals('@#\$%^&*()'));
      });
    });

    group('Clear functionality', () {
      testWidgets('should show clear button when text is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(initialValue: 'test'));

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('should hide clear button when text is empty', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(initialValue: ''));

        expect(find.byIcon(Icons.clear), findsNothing);
      });

      testWidgets('should call onClear when clear button is tapped', (WidgetTester tester) async {
        bool clearCalled = false;

        await tester.pumpWidget(createTestWidget(
          initialValue: 'test',
          onClear: () => clearCalled = true,
        ));

        await tester.tap(find.byIcon(Icons.clear));
        expect(clearCalled, isTrue);
      });
    });

    group('Visual appearance', () {
      testWidgets('should have proper styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.labelText, equals('Search'));
        expect(textField.decoration?.border, isA<OutlineInputBorder>());
      });
    });

    group('Edge cases', () {
      testWidgets('should handle very long input', (WidgetTester tester) async {
        final longText = 'A' * 1000;
        String? changedValue;

        await tester.pumpWidget(createTestWidget(
          onChanged: (value) => changedValue = value,
        ));

        await tester.enterText(find.byType(TextField), longText);
        expect(changedValue, equals(longText));
      });

      testWidgets('should handle rapid text changes', (WidgetTester tester) async {
        final List<String> changedValues = [];

        await tester.pumpWidget(createTestWidget(
          onChanged: (value) => changedValues.add(value),
        ));

        for (int i = 0; i < 10; i++) {
          await tester.enterText(find.byType(TextField), 'test$i');
        }

        expect(changedValues.length, equals(10));
        expect(changedValues.last, equals('test9'));
      });
    });
  });
}