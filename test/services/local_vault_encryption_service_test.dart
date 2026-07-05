import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/services/local_vault_encryption_service.dart';

void main() {
  group('LocalVaultEncryptionService', () {
    const password = 'correct horse battery staple';
    const plaintextJson =
        '{"services":[{"name":"GitHub","secret":"JBSWY3DPEHPK3PXP"}],"groups":[]}';

    test('should encrypt and decrypt the exact app data JSON payload',
        () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );

      final decrypted = await LocalVaultEncryptionService.decrypt(
        vaultBytes,
        password,
      );

      expect(decrypted, equals(plaintextJson));
    });

    test('should write a versioned encrypted vault envelope', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );
      final envelope =
          jsonDecode(utf8.decode(vaultBytes)) as Map<String, dynamic>;

      expect(envelope['magic'], equals(LocalVaultEncryptionService.magic));
      expect(envelope['version'], equals(LocalVaultEncryptionService.version));
      expect(
          envelope['kdf']['name'], equals(LocalVaultEncryptionService.kdfName));
      expect(envelope['kdf']['iterations'], equals(1000));
      expect(envelope['cipher']['name'],
          equals(LocalVaultEncryptionService.cipherName));
      expect(envelope['ciphertext'], isA<String>());
      expect(envelope.containsKey('services'), isFalse);
      expect(envelope.containsKey('groups'), isFalse);
    });

    test('should reject an incorrect password', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );

      expect(
        () => LocalVaultEncryptionService.decrypt(vaultBytes, 'wrong password'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject corrupted ciphertext', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );
      final envelope =
          jsonDecode(utf8.decode(vaultBytes)) as Map<String, dynamic>;
      final ciphertext = base64.decode(envelope['ciphertext'] as String);
      ciphertext[0] = ciphertext[0] ^ 0x01;
      envelope['ciphertext'] = base64.encode(ciphertext);
      final corruptedBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      expect(
        () => LocalVaultEncryptionService.decrypt(corruptedBytes, password),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should reject unsupported vault versions', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );
      final envelope =
          jsonDecode(utf8.decode(vaultBytes)) as Map<String, dynamic>;
      envelope['version'] = LocalVaultEncryptionService.version2 + 1;
      final unsupportedBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      expect(
        () => LocalVaultEncryptionService.decrypt(unsupportedBytes, password),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should reject malformed vault data', () async {
      final malformedBytes = Uint8List.fromList(utf8.encode('not json'));

      expect(
        () => LocalVaultEncryptionService.decrypt(malformedBytes, password),
        throwsA(isA<FormatException>()),
      );
    });

    test('should reject iterations above the maximum bound', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );
      final envelope =
          jsonDecode(utf8.decode(vaultBytes)) as Map<String, dynamic>;
      envelope['kdf']['iterations'] =
          LocalVaultEncryptionService.maxIterations + 1;
      final tamperedBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      expect(
        () => LocalVaultEncryptionService.decrypt(tamperedBytes, password),
        throwsA(isA<FormatException>()),
      );
    });

    test('should round trip unicode password and emoji plaintext', () async {
      const unicodePassword = 'pâsswörd-ǔnicode-🔐';
      const unicodePlaintext = '{"note":"héllo wörld 🚀🔑 日本語"}';

      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        unicodePlaintext,
        unicodePassword,
        iterations: 1000,
      );

      final decrypted = await LocalVaultEncryptionService.decrypt(
        vaultBytes,
        unicodePassword,
      );

      expect(decrypted, equals(unicodePlaintext));
    });

    test('should throw when encrypting with an empty password', () async {
      expect(
        () => LocalVaultEncryptionService.encrypt('', '', iterations: 1000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw when decrypting with an empty password', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );

      expect(
        () => LocalVaultEncryptionService.decrypt(vaultBytes, ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should round-trip empty plaintext', () async {
      final vault = await LocalVaultEncryptionService.encrypt(
        '',
        'pw',
        iterations: 1000,
      );
      expect(
          await LocalVaultEncryptionService.decrypt(vault, 'pw'), equals(''));
    });

    test('should reject tampered KDF iterations bound by AAD', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 5000,
      );
      final envelope =
          jsonDecode(utf8.decode(vaultBytes)) as Map<String, dynamic>;
      final kdf = envelope['kdf'] as Map<String, dynamic>;
      expect(kdf['iterations'], equals(5000));
      kdf['iterations'] = 6000;
      final tamperedBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      expect(
        () => LocalVaultEncryptionService.decrypt(tamperedBytes, password),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('unlockWithPassword flags a v1 vault for upgrade', () async {
      final vaultBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
        iterations: 1000,
      );

      final unlocked = await LocalVaultEncryptionService.unlockWithPassword(
        vaultBytes,
        password,
      );

      expect(unlocked.plaintextJson, equals(plaintextJson));
      expect(unlocked.needsUpgrade, isTrue);
      expect(unlocked.sessionKeys, isNull);
    });
  });

  group('LocalVaultEncryptionService v2', () {
    const password = 'correct horse battery staple';
    const plaintextJson =
        '{"services":[{"name":"GitHub","secret":"JBSWY3DPEHPK3PXP"}],"groups":[]}';

    Future<VaultBuildResult> buildVault({int iterations = 1000}) {
      return LocalVaultEncryptionService.createEncryptedVault(
        plaintextJson,
        password,
        iterations: iterations,
      );
    }

    Map<String, dynamic> decodeEnvelope(Uint8List bytes) =>
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    Uint8List encodeEnvelope(Map<String, dynamic> envelope) =>
        Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

    test('writes a versioned v2 envelope with a password slot', () async {
      final built = await buildVault();
      final envelope = decodeEnvelope(built.bytes);

      expect(envelope['magic'], equals(LocalVaultEncryptionService.magic));
      expect(envelope['version'], equals(LocalVaultEncryptionService.version2));
      final slots = envelope['keySlots'] as List;
      expect(slots, hasLength(1));
      expect(slots.first['type'], equals('password'));
      expect(envelope.containsKey('ciphertext'), isTrue);
      expect(envelope.containsKey('services'), isFalse);
    });

    test('round-trips the payload through the password slot', () async {
      final built = await buildVault();

      final unlocked = await LocalVaultEncryptionService.unlockWithPassword(
        built.bytes,
        password,
      );

      expect(unlocked.plaintextJson, equals(plaintextJson));
      expect(unlocked.needsUpgrade, isFalse);
      expect(unlocked.sessionKeys, isNotNull);
      expect(unlocked.sessionKeys!.hasKeyringSlot, isFalse);
    });

    test('rejects an incorrect password', () async {
      final built = await buildVault();

      expect(
        () => LocalVaultEncryptionService.unlockWithPassword(
          built.bytes,
          'wrong password',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tampered payload ciphertext', () async {
      final built = await buildVault();
      final envelope = decodeEnvelope(built.bytes);
      final ciphertext = base64.decode(envelope['ciphertext'] as String);
      ciphertext[0] = ciphertext[0] ^ 0x01;
      envelope['ciphertext'] = base64.encode(ciphertext);

      expect(
        () => LocalVaultEncryptionService.unlockWithPassword(
          encodeEnvelope(envelope),
          password,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trips the payload through a keyring KEK', () async {
      final built = await buildVault();
      final kek = LocalVaultEncryptionService.generateKeyEncryptionKey();
      const kekId = 'keyring-slot-1';
      final session = await LocalVaultEncryptionService.addKeyringSlotToSession(
        built.session,
        kekId,
        kek,
      );
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        session,
      );

      expect(
          LocalVaultEncryptionService.readKeyringKekId(bytes), equals(kekId));

      final unlocked = await LocalVaultEncryptionService.unlockWithKeyringKek(
        bytes,
        kekId,
        kek,
      );

      expect(unlocked.plaintextJson, equals(plaintextJson));
      expect(unlocked.sessionKeys!.hasKeyringSlot, isTrue);
      expect(unlocked.sessionKeys!.keyringKekId, equals(kekId));
    });

    test('rejects a tampered keyring slot wrapped key', () async {
      final built = await buildVault();
      final kek = LocalVaultEncryptionService.generateKeyEncryptionKey();
      const kekId = 'keyring-slot-1';
      final session = await LocalVaultEncryptionService.addKeyringSlotToSession(
        built.session,
        kekId,
        kek,
      );
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        session,
      );

      final envelope = decodeEnvelope(bytes);
      final slots = envelope['keySlots'] as List;
      final keyringSlot = slots.firstWhere((s) => s['type'] == 'keyring')
          as Map<String, dynamic>;
      final wrap = keyringSlot['wrap'] as Map<String, dynamic>;
      final wrapped = base64.decode(wrap['wrappedKey'] as String);
      wrapped[0] = wrapped[0] ^ 0x01;
      wrap['wrappedKey'] = base64.encode(wrapped);

      expect(
        () => LocalVaultEncryptionService.unlockWithKeyringKek(
          encodeEnvelope(envelope),
          kekId,
          kek,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('binds every key slot into the payload AAD', () async {
      final built = await buildVault();
      final kek = LocalVaultEncryptionService.generateKeyEncryptionKey();
      const kekId = 'keyring-slot-1';
      final session = await LocalVaultEncryptionService.addKeyringSlotToSession(
        built.session,
        kekId,
        kek,
      );
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        session,
      );

      // Mutating the keyring slot leaves the password unwrap intact but must
      // break the payload decrypt, proving the slots are bound into its AAD.
      final envelope = decodeEnvelope(bytes);
      final slots = envelope['keySlots'] as List;
      final keyringSlot = slots.firstWhere((s) => s['type'] == 'keyring')
          as Map<String, dynamic>;
      keyringSlot['kekId'] = 'tampered-id';

      expect(
        () => LocalVaultEncryptionService.unlockWithPassword(
          encodeEnvelope(envelope),
          password,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('skips an unknown slot on unlock and preserves it on save', () async {
      final built = await buildVault();
      final sessionWithUnknown = VaultSessionKeys(
        dek: built.session.dek,
        keySlots: [
          ...built.session.keySlots,
          const {'type': 'future-slot', 'blob': 'AAAA'},
        ],
      );
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        sessionWithUnknown,
      );

      final unlocked = await LocalVaultEncryptionService.unlockWithPassword(
        bytes,
        password,
      );

      expect(unlocked.plaintextJson, equals(plaintextJson));
      expect(
        unlocked.sessionKeys!.keySlots.any((s) => s['type'] == 'future-slot'),
        isTrue,
      );

      // A subsequent save keeps the unknown slot intact.
      final resaved =
          await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        unlocked.sessionKeys!,
      );
      final reloaded = await LocalVaultEncryptionService.unlockWithPassword(
        resaved,
        password,
      );
      expect(
        reloaded.sessionKeys!.keySlots.any((s) => s['type'] == 'future-slot'),
        isTrue,
      );
    });

    test('rejects building an envelope with no password slot', () async {
      final session = VaultSessionKeys(
        dek: LocalVaultEncryptionService.generateKeyEncryptionKey(),
        keySlots: const [
          {'type': 'future-slot', 'blob': 'AAAA'},
        ],
      );

      expect(
        () => LocalVaultEncryptionService.buildEnvelopeFromSession(
          plaintextJson,
          session,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('change of password re-wraps only the password slot', () async {
      final built = await buildVault();
      final kek = LocalVaultEncryptionService.generateKeyEncryptionKey();
      const kekId = 'keyring-slot-1';
      final withKeyring =
          await LocalVaultEncryptionService.addKeyringSlotToSession(
        built.session,
        kekId,
        kek,
      );

      final rewrapped = await LocalVaultEncryptionService.rewrapPasswordSlot(
        withKeyring,
        'a brand new passphrase',
        iterations: 1000,
      );
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        rewrapped,
      );

      // Keyring slot survives the password change.
      final viaKeyring = await LocalVaultEncryptionService.unlockWithKeyringKek(
        bytes,
        kekId,
        kek,
      );
      expect(viaKeyring.plaintextJson, equals(plaintextJson));

      // New password works, old password no longer does.
      final viaNewPassword =
          await LocalVaultEncryptionService.unlockWithPassword(
        bytes,
        'a brand new passphrase',
      );
      expect(viaNewPassword.plaintextJson, equals(plaintextJson));
      expect(
        () => LocalVaultEncryptionService.unlockWithPassword(bytes, password),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('removeKeyringSlotFromSession drops the keyring slot', () async {
      final built = await buildVault();
      final kek = LocalVaultEncryptionService.generateKeyEncryptionKey();
      final withKeyring =
          await LocalVaultEncryptionService.addKeyringSlotToSession(
        built.session,
        'keyring-slot-1',
        kek,
      );
      expect(withKeyring.hasKeyringSlot, isTrue);

      final without =
          LocalVaultEncryptionService.removeKeyringSlotFromSession(withKeyring);

      expect(without.hasKeyringSlot, isFalse);
      final bytes = await LocalVaultEncryptionService.buildEnvelopeFromSession(
        plaintextJson,
        without,
      );
      expect(LocalVaultEncryptionService.readKeyringKekId(bytes), isNull);
    });
  });
}
