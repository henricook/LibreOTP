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
      envelope['version'] = LocalVaultEncryptionService.version + 1;
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
  });
}
