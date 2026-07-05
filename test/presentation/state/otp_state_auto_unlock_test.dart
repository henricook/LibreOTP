import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/domain/services/otp_service.dart';
import 'package:libreotp/presentation/state/otp_state.dart';
import 'package:libreotp/services/local_vault_encryption_service.dart';
import 'package:libreotp/services/vault_keyring_service.dart';

class FakeVaultKeyringService extends VaultKeyringService {
  VaultKeyringRecord? record;
  bool throwOnWrite = false;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<VaultKeyringRecord?> read() async => record;

  @override
  Future<void> write(VaultKeyringRecord newRecord) async {
    if (throwOnWrite) {
      throw StateError('Simulated keyring write failure');
    }
    writeCount++;
    record = newRecord;
  }

  @override
  Future<void> delete() async {
    deleteCount++;
    record = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OtpState auto-unlock', () {
    late Directory tempDir;
    late FakeVaultKeyringService keyring;
    final generator = OtpGenerator();
    final states = <OtpState>[];

    OtpState newState(StorageRepository repository) {
      final state = OtpState(repository, generator);
      states.add(state);
      return state;
    }

    StorageRepository newRepository() => StorageRepository(
          localPathOverride: tempDir.path,
          keyringService: keyring,
        );

    const service = OtpService(
      id: 'service-1',
      name: 'GitHub',
      secret: 'JBSWY3DPEHPK3PXP',
      otp: OtpConfig(account: 'me@example.com', issuer: 'GitHub'),
      order: OrderInfo(position: 0),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('libreotp_autounlock_');
      keyring = FakeVaultKeyringService();
    });

    tearDown(() async {
      for (final state in states) {
        state.dispose();
      }
      states.clear();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<OtpState> encryptedState({bool enableAutoUnlock = false}) async {
      final repository = newRepository();
      await repository.writeAppDataJson(
        AppData(services: const [service], groups: const []),
      );
      final state = newState(repository);
      await state.initializeData();
      await state.migratePlaintextDataToEncryptedVault('vault-password');
      if (enableAutoUnlock) {
        await state.enableAutoUnlock();
      }
      return state;
    }

    Future<String?> vaultKeyringKekId() async {
      final repository = newRepository();
      final bytes = await repository.readEncryptedAppData();
      return LocalVaultEncryptionService.readKeyringKekId(bytes);
    }

    test('enableAutoUnlock writes the KEK and adds a keyring slot', () async {
      final state = await encryptedState();
      expect(state.autoUnlockEnabled, isFalse);
      expect(state.canConfigureAutoUnlock, isTrue);

      await state.enableAutoUnlock();

      expect(state.autoUnlockEnabled, isTrue);
      expect(keyring.record, isNotNull);
      expect(keyring.writeCount, equals(1));
      expect(await vaultKeyringKekId(), equals(keyring.record!.id));
    });

    test('a fresh session auto-unlocks without a password', () async {
      await encryptedState(enableAutoUnlock: true);

      final reopened = newState(newRepository());
      await reopened.initializeData();

      expect(reopened.requiresPassword, isFalse);
      expect(reopened.usesEncryptedLocalStorage, isTrue);
      expect(reopened.autoUnlockEnabled, isTrue);
      expect(reopened.services.single.id, equals('service-1'));
    });

    test('disableAutoUnlock removes the slot and deletes the KEK', () async {
      final state = await encryptedState(enableAutoUnlock: true);

      await state.disableAutoUnlock();

      expect(state.autoUnlockEnabled, isFalse);
      expect(keyring.record, isNull);
      expect(keyring.deleteCount, greaterThanOrEqualTo(1));
      expect(await vaultKeyringKekId(), isNull);

      final reopened = newState(newRepository());
      await reopened.initializeData();
      expect(reopened.requiresPassword, isTrue);
    });

    test('changing the password keeps auto-unlock working', () async {
      final state = await encryptedState(enableAutoUnlock: true);

      await state.changeLocalVaultPassword('a-new-password');

      expect(state.autoUnlockEnabled, isTrue);

      final reopened = newState(newRepository());
      await reopened.initializeData();
      expect(reopened.requiresPassword, isFalse);
      expect(reopened.autoUnlockEnabled, isTrue);
      expect(reopened.services.single.id, equals('service-1'));
    });

    test('a debounced save preserves both slots and the edit', () async {
      final state = await encryptedState(enableAutoUnlock: true);

      final updated = state.updateServiceDetails(
        serviceId: 'service-1',
        name: 'GitHub Renamed',
        account: 'me@example.com',
      );
      expect(updated, isTrue);

      // The debounced usage save fires after 2 seconds on the real clock.
      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(await vaultKeyringKekId(), isNotNull);

      final reopened = newState(newRepository());
      await reopened.initializeData();
      expect(reopened.requiresPassword, isFalse);
      expect(reopened.autoUnlockEnabled, isTrue);
      expect(reopened.services.single.name, equals('GitHub Renamed'));
    });

    test('a failed keyring write leaves auto-unlock disabled', () async {
      final state = await encryptedState();
      keyring.throwOnWrite = true;

      await expectLater(
        state.enableAutoUnlock(),
        throwsA(isA<StateError>()),
      );

      expect(state.autoUnlockEnabled, isFalse);
      expect(keyring.record, isNull);
      expect(await vaultKeyringKekId(), isNull);
    });
  });
}
