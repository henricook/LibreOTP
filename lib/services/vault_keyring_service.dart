import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A key-encryption key persisted in the system keyring so the local vault can
/// be unlocked without a password on a trusted device.
class VaultKeyringRecord {
  final String id;
  final Uint8List kek;

  const VaultKeyringRecord({required this.id, required this.kek});
}

/// Stores the vault auto-unlock KEK in the platform keyring (GNOME Keyring on
/// Linux, Keychain on macOS, Credential Manager on Windows) via
/// [FlutterSecureStorage]. Injectable so tests can supply a fake.
///
/// Every failure is catchable: reads that cannot be parsed return null and
/// writes that do not read back throw, so a locked or absent keyring degrades
/// to password unlock instead of crashing the app.
class VaultKeyringService {
  static const String _kekStorageKey = 'local_vault_kek';

  final FlutterSecureStorage _storage;

  VaultKeyringService({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage();

  static FlutterSecureStorage _defaultStorage() {
    return const FlutterSecureStorage(
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
  }

  Future<VaultKeyringRecord?> read() async {
    try {
      final raw = await _storage.read(key: _kekStorageKey);
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final id = decoded['id'];
      final kekB64 = decoded['kek'];
      if (id is! String || id.isEmpty || kekB64 is! String || kekB64.isEmpty) {
        return null;
      }
      final kek = base64.decode(kekB64);
      if (kek.length != 32) {
        return null;
      }
      return VaultKeyringRecord(id: id, kek: kek);
    } catch (e) {
      debugPrint('Could not read vault keyring entry: $e');
      return null;
    }
  }

  /// Persists [record] and reads it back to confirm the write took effect.
  /// A Linux keyring can be locked or absent and silently accept a write, so a
  /// value that does not read back identically is treated as a failure.
  Future<void> write(VaultKeyringRecord record) async {
    final payload = jsonEncode({
      'id': record.id,
      'kek': base64.encode(record.kek),
    });
    await _storage.write(key: _kekStorageKey, value: payload);

    final readBack = await read();
    if (readBack == null ||
        readBack.id != record.id ||
        !_bytesEqual(readBack.kek, record.kek)) {
      throw StateError('Vault keyring write could not be verified');
    }
  }

  Future<void> delete() async {
    await _storage.delete(key: _kekStorageKey);
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
