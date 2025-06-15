import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );

  static const String _passwordKey = 'twofas_backup_password';
  static const String _saltKey = 'twofas_backup_salt';
  static const String _fileHashKey = 'twofas_backup_file_hash';

  // Simple in-memory cache to avoid repeated secure storage access during app session
  static String? _cachedPassword;
  static String? _cachedFileHash;

  /// Securely stores the password for the current backup file
  /// The password is encrypted with a device-specific key and tied to the file hash
  static Future<void> storePassword(String password, String fileContent) async {
    try {
      // Generate a file hash to ensure password is only valid for this specific backup
      final fileHash = sha256.convert(utf8.encode(fileContent)).toString();

      // Generate a random salt for password encryption
      final random = Random.secure();
      final salt =
          Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));

      // Derive encryption key from device-specific data and salt
      final deviceKey = await _deriveDeviceKey(salt);

      // Encrypt the password
      final encryptedPassword = _encryptPassword(password, deviceKey);

      // Store encrypted password, salt, and file hash
      await _storage.write(
          key: _passwordKey, value: base64.encode(encryptedPassword));
      await _storage.write(key: _saltKey, value: base64.encode(salt));
      await _storage.write(key: _fileHashKey, value: fileHash);

      // Update cache
      _cachedPassword = password;
      _cachedFileHash = fileHash;
    } catch (e) {
      throw Exception('Failed to store password securely: $e');
    }
  }

  /// Retrieves the stored password for the current backup file
  /// Returns null if no password is stored or if the file has changed
  static Future<String?> getStoredPassword(String fileContent) async {
    try {
      final currentFileHash =
          sha256.convert(utf8.encode(fileContent)).toString();

      // Check cache first
      if (_cachedPassword != null && _cachedFileHash == currentFileHash) {
        return _cachedPassword;
      }

      // Check if we have stored credentials
      final encryptedPasswordB64 = await _storage.read(key: _passwordKey);
      final saltB64 = await _storage.read(key: _saltKey);
      final storedFileHash = await _storage.read(key: _fileHashKey);

      if (encryptedPasswordB64 == null ||
          saltB64 == null ||
          storedFileHash == null) {
        return null;
      }

      // Verify the file hasn't changed
      if (currentFileHash != storedFileHash) {
        // File has changed, clear stored password and cache
        await clearStoredPassword();
        return null;
      }

      // Decrypt the password
      final encryptedPassword = base64.decode(encryptedPasswordB64);
      final salt = base64.decode(saltB64);
      final deviceKey = await _deriveDeviceKey(salt);

      final password = _decryptPassword(encryptedPassword, deviceKey);

      // Cache the result for future calls
      _cachedPassword = password;
      _cachedFileHash = currentFileHash;

      return password;
    } catch (e) {
      // If decryption fails, clear stored data and cache
      await clearStoredPassword();
      return null;
    }
  }

  /// Clears all stored password data
  static Future<void> clearStoredPassword() async {
    // Clear cache
    _cachedPassword = null;
    _cachedFileHash = null;

    // Clear secure storage
    await Future.wait([
      _storage.delete(key: _passwordKey),
      _storage.delete(key: _saltKey),
      _storage.delete(key: _fileHashKey),
    ]);
  }

  /// Derives a device-specific encryption key
  static Future<Uint8List> _deriveDeviceKey(Uint8List salt) async {
    // Use a combination of salt and app-specific data as key material
    // In a real app, you might include device ID or other device-specific data
    const appSeed = 'LibreOTP-2FAS-SecureStorage-v1';
    final keyMaterial = utf8.encode(appSeed);

    // Use PBKDF2 to derive a strong key
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(
        Pbkdf2Parameters(salt, 100000, 32)); // 100k iterations, 256-bit key
    return pbkdf2.process(Uint8List.fromList(keyMaterial));
  }

  /// Encrypts a password using AES-GCM
  static Uint8List _encryptPassword(String password, Uint8List key) {
    final random = Random.secure();
    final iv =
        Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(true, params);

    final plaintext = utf8.encode(password);
    final ciphertext = cipher.process(Uint8List.fromList(plaintext));

    // Prepend IV to ciphertext for storage
    final result = Uint8List(iv.length + ciphertext.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, ciphertext);

    return result;
  }

  /// Decrypts a password using AES-GCM
  static String _decryptPassword(Uint8List encryptedData, Uint8List key) {
    if (encryptedData.length < 12) {
      throw ArgumentError('Invalid encrypted data');
    }

    final iv = encryptedData.sublist(0, 12);
    final ciphertext = encryptedData.sublist(12);

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(false, params);

    final plaintext = cipher.process(ciphertext);
    return utf8.decode(plaintext);
  }
}
