import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class TwoFasDecryptionService {
  static const int _iterations = 10000;
  static const int _keyLength = 32; // 256 bits / 8
  static const int _authTagLength = 16;
  static const String _reference =
      'tRViSsLKzd86Hprh4ceC2OP7xazn4rrt4xhfEUbOjxLX8Rc3mkISXE0lWbmnWfggogbBJhtYgpK6fMl1D6m'
      'tsy92R3HkdGfwuXbzLebqVFJsR7IZ2w58t938iymwG4824igYy1wi6n2WDpO1Q1P69zwJGs2F5a1qP4MyIiDSD7NCV2OvidX'
      'QCBnDlGfmz0f1BQySRkkt4ryiJeCjD2o4QsveJ9uDBUn8ELyOrESv5R5DMDkD4iAF8TXU7KyoJujd';

  static bool isEncrypted(Map<String, dynamic> backupData) {
    return backupData.containsKey('servicesEncrypted') &&
        backupData['servicesEncrypted'] is String &&
        (backupData['servicesEncrypted'] as String).isNotEmpty;
  }

  static Future<String> decryptBackup(
      Map<String, dynamic> backupData, String password) async {
    if (!isEncrypted(backupData)) {
      throw ArgumentError('Backup file is not encrypted');
    }

    final servicesEncrypted = backupData['servicesEncrypted'] as String;
    final parts = servicesEncrypted.split(':');

    if (parts.length != 3) {
      throw FormatException('Invalid encrypted backup format');
    }

    final cipherWithTag = base64.decode(parts[0]);
    final salt = base64.decode(parts[1]);
    final iv = base64.decode(parts[2]);

    if (cipherWithTag.length <= _authTagLength) {
      throw FormatException('Invalid cipher data length');
    }

    final cipherText =
        cipherWithTag.sublist(0, cipherWithTag.length - _authTagLength);
    final authTag =
        cipherWithTag.sublist(cipherWithTag.length - _authTagLength);

    // Verify password using reference field if available
    if (backupData.containsKey('reference')) {
      if (!await _verifyPassword(
          backupData['reference'] as String, password, salt)) {
        throw ArgumentError('Invalid password');
      }
    }

    final key = _deriveKey(password, salt);
    final plainText = _decryptAesGcm(cipherText, key, iv, authTag);

    return utf8.decode(plainText);
  }

  static Future<bool> _verifyPassword(
      String reference, String password, Uint8List salt) async {
    try {
      final referenceParts = reference.split(':');
      if (referenceParts.length != 3) return false;

      final refCipherWithTag = base64.decode(referenceParts[0]);
      final refIv = base64.decode(referenceParts[2]);

      if (refCipherWithTag.length <= _authTagLength) return false;

      final refCipherText =
          refCipherWithTag.sublist(0, refCipherWithTag.length - _authTagLength);
      final refAuthTag =
          refCipherWithTag.sublist(refCipherWithTag.length - _authTagLength);

      final key = _deriveKey(password, salt);
      final decryptedRef =
          _decryptAesGcm(refCipherText, key, refIv, refAuthTag);

      return utf8.decode(decryptedRef) == _reference;
    } catch (e) {
      return false;
    }
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, _iterations, _keyLength));
    return pbkdf2.process(utf8.encode(password));
  }

  static Uint8List _decryptAesGcm(
      Uint8List cipherText, Uint8List key, Uint8List iv, Uint8List authTag) {
    final cipher = GCMBlockCipher(AESEngine());
    final params =
        AEADParameters(KeyParameter(key), authTag.length * 8, iv, Uint8List(0));

    cipher.init(false, params);

    final input = Uint8List(cipherText.length + authTag.length);
    input.setRange(0, cipherText.length, cipherText);
    input.setRange(cipherText.length, input.length, authTag);

    try {
      return cipher.process(input);
    } catch (e) {
      throw ArgumentError(
          'Decryption failed: Invalid password or corrupted data');
    }
  }
}
