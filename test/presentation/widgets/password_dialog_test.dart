import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/presentation/widgets/password_dialog.dart';

void main() {
  Widget buildDialog(PasswordDialog dialog) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog<String>(context: context, builder: (_) => dialog);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester, PasswordDialog dialog) async {
    await tester.pumpWidget(buildDialog(dialog));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('PasswordDialog', () {
    testWidgets('shows vault unlock copy and action label', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(mode: PasswordDialogMode.unlockVault),
      );

      expect(find.text('Encrypted Vault Detected'), findsOneWidget);
      expect(
        find.text(
          'This local vault is encrypted. Enter the password to unlock your stored services.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('preserves surrounding whitespace in the submitted password', (
      WidgetTester tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  submitted = await showDialog<String>(
                    context: context,
                    builder: (_) => const PasswordDialog(
                      mode: PasswordDialogMode.unlockVault,
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

      await tester.enterText(
        find.byType(TextField).first,
        '  spaced password  ',
      );
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(submitted, equals('  spaced password  '));
    });

    testWidgets('shows backup decrypt copy and action label', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(mode: PasswordDialogMode.decryptBackup),
      );

      expect(find.text('Encrypted Backup Detected'), findsOneWidget);
      expect(
        find.text(
          'This backup file is encrypted. Enter the password to decrypt it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Decrypt'), findsOneWidget);
    });

    testWidgets('shows confirmation field in create vault mode', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(mode: PasswordDialogMode.createVaultPassword),
      );

      expect(find.text('Create Vault Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Vault'), findsOneWidget);
    });

    testWidgets('shows mismatch error in create vault mode', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(mode: PasswordDialogMode.createVaultPassword),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'password-one',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'password-two',
      );
      await tester.tap(find.text('Create Vault'));
      await tester.pumpAndSettle();

      expect(
        find.text('Passwords do not match. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('returns password when vault creation confirmation matches', (
      WidgetTester tester,
    ) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const PasswordDialog(
                      mode: PasswordDialogMode.createVaultPassword,
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
      await tester.enterText(
        find.widgetWithText(TextField, 'New Password'),
        'matching-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'matching-password',
      );
      await tester.tap(find.text('Create Vault'));
      await tester.pumpAndSettle();

      expect(result, equals('matching-password'));
    });

    testWidgets('shows change vault password copy and confirm field', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(mode: PasswordDialogMode.changeVaultPassword),
      );

      expect(find.text('Change Vault Password'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(TextField, 'New Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Confirm Password'),
        findsOneWidget,
      );
    });

    testWidgets('renders corrupted vault error copy', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(
          mode: PasswordDialogMode.unlockVault,
          errorKind: VaultLoadErrorKind.corruptedVault,
        ),
      );

      expect(
        find.text(
          'This vault file appears to be corrupted or was created by a newer version.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders incorrect password error copy', (
      WidgetTester tester,
    ) async {
      await openDialog(
        tester,
        const PasswordDialog(
          mode: PasswordDialogMode.unlockVault,
          errorKind: VaultLoadErrorKind.incorrectPassword,
        ),
      );

      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
