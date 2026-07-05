import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/services/vault_keyring_service.dart';

/// A secure storage whose writes silently vanish, mimicking a locked or absent
/// Linux keyring so the read-back verification can be exercised.
class _DropWritesSecureStorage extends FlutterSecureStorage {
  const _DropWritesSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List key(int fill) => Uint8List.fromList(List.filled(32, fill));

  group('VaultKeyringService', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('writes and reads back a record', () async {
      final service = VaultKeyringService();
      await service.write(VaultKeyringRecord(id: 'kek-1', kek: key(7)));

      final record = await service.read();

      expect(record, isNotNull);
      expect(record!.id, equals('kek-1'));
      expect(record.kek, equals(key(7)));
    });

    test('read returns null when nothing is stored', () async {
      final service = VaultKeyringService();
      expect(await service.read(), isNull);
    });

    test('read returns null for a corrupt entry', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'local_vault_kek', value: 'not-json');

      final service = VaultKeyringService(storage: storage);
      expect(await service.read(), isNull);
    });

    test('read returns null for the wrong key length', () async {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'local_vault_kek',
        value: jsonEncode({
          'id': 'kek-1',
          'kek': base64.encode([1, 2, 3])
        }),
      );

      final service = VaultKeyringService(storage: storage);
      expect(await service.read(), isNull);
    });

    test('delete removes the stored record', () async {
      final service = VaultKeyringService();
      await service.write(VaultKeyringRecord(id: 'kek-1', kek: key(9)));
      expect(await service.read(), isNotNull);

      await service.delete();

      expect(await service.read(), isNull);
    });

    test('write throws when the value does not read back', () async {
      final service = VaultKeyringService(
        storage: const _DropWritesSecureStorage(),
      );

      expect(
        () => service.write(VaultKeyringRecord(id: 'kek-1', kek: key(3))),
        throwsA(isA<StateError>()),
      );
    });
  });
}
