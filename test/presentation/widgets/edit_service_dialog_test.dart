import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/presentation/widgets/edit_service_dialog.dart';

void main() {
  group('EditServiceDialog', () {
    Future<EditServiceResult?> openAndSubmit(
      WidgetTester tester, {
      required String name,
      required String account,
    }) async {
      EditServiceResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<EditServiceResult>(
                    context: context,
                    builder: (_) => const EditServiceDialog(
                      initialName: 'GitHub',
                      initialAccount: 'me@example.com',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, name);
      await tester.enterText(find.byType(TextField).last, account);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      return result;
    }

    testWidgets('rejects a whitespace-only name', (WidgetTester tester) async {
      final result = await openAndSubmit(tester, name: '   ', account: 'a@b.c');

      expect(find.text('Name cannot be empty.'), findsOneWidget);
      expect(find.byType(EditServiceDialog), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('returns trimmed values and allows an empty account',
        (WidgetTester tester) async {
      final result =
          await openAndSubmit(tester, name: '  GitHub Work  ', account: '  ');

      expect(result, isNotNull);
      expect(result!.name, equals('GitHub Work'));
      expect(result.account, isEmpty);
    });
  });
}
