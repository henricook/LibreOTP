import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/services/crypto_primitives.dart';

void main() {
  group('crypto primitives', () {
    test('derive key, encrypt and decrypt round trip', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final aad = Uint8List.fromList(utf8.encode('metadata'));
      final plaintext = Uint8List.fromList(utf8.encode('hello primitives'));

      final key = derivePbkdf2HmacSha256Key('password', salt, 1000, 32);
      expect(key.length, 32);

      final ciphertextWithTag = aesGcmEncrypt(key, nonce, plaintext, aad, 16);
      final decrypted = aesGcmDecrypt(key, nonce, ciphertextWithTag, aad, 16);

      expect(decrypted, plaintext);
    });

    test('encrypt and decrypt round trip empty plaintext', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final aad = Uint8List.fromList(utf8.encode('metadata'));
      final plaintext = Uint8List(0);

      final key = derivePbkdf2HmacSha256Key('password', salt, 1000, 32);
      final ciphertextWithTag = aesGcmEncrypt(key, nonce, plaintext, aad, 16);
      expect(ciphertextWithTag.length, 16);
      final decrypted = aesGcmDecrypt(key, nonce, ciphertextWithTag, aad, 16);

      expect(decrypted, plaintext);
    });

    test('decrypt throws on wrong key', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final aad = Uint8List(0);
      final plaintext = Uint8List.fromList(utf8.encode('secret'));

      final key = derivePbkdf2HmacSha256Key('password', salt, 1000, 32);
      final wrongKey = derivePbkdf2HmacSha256Key('other', salt, 1000, 32);
      final ciphertextWithTag = aesGcmEncrypt(key, nonce, plaintext, aad, 16);

      expect(
        () => aesGcmDecrypt(wrongKey, nonce, ciphertextWithTag, aad, 16),
        throwsA(anything),
      );
    });
  });
}
