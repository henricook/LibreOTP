import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'crypto_primitives.dart';

class VaultKdfParameters {
  final Uint8List salt;
  final int iterations;

  const VaultKdfParameters({required this.salt, required this.iterations});
}

class LocalVaultEncryptionService {
  static const String magic = 'LibreOTPVault';
  static const int version = 1;
  static const String kdfName = 'PBKDF2-HMAC-SHA256';
  static const String cipherName = 'AES-256-GCM';
  static const int keyLength = 32;
  static const int saltLength = 32;
  static const int nonceLength = 12;
  static const int authTagLength = 16;
  static const int defaultIterations = 600000;
  static const int maxIterations = 10000000;

  static Future<Uint8List> encrypt(
    String plaintextJson,
    String password, {
    int iterations = defaultIterations,
  }) async {
    return Isolate.run(
      () => _encryptSync(
        plaintextJson,
        password,
        iterations: iterations,
      ),
    );
  }

  static Uint8List _encryptSync(
    String plaintextJson,
    String password, {
    required int iterations,
  }) {
    if (password.isEmpty) {
      throw ArgumentError('Password required for encrypted vault');
    }
    if (iterations <= 0) {
      throw ArgumentError('KDF iterations must be greater than zero');
    }

    final salt = _randomBytes(saltLength);
    final key = _deriveKey(password, salt, iterations);
    return _buildEnvelope(
      plaintextJson,
      key,
      salt: salt,
      iterations: iterations,
    );
  }

  static Future<Uint8List> deriveKey(
    String password,
    Uint8List salt,
    int iterations,
  ) async {
    return Isolate.run(() {
      if (password.isEmpty) {
        throw ArgumentError('Password required for encrypted vault');
      }
      if (iterations <= 0) {
        throw ArgumentError('KDF iterations must be greater than zero');
      }
      return _deriveKey(password, salt, iterations);
    });
  }

  static Future<Uint8List> encryptWithKey(
    String plaintextJson,
    Uint8List key, {
    required Uint8List salt,
    required int iterations,
  }) async {
    return Isolate.run(
      () => _buildEnvelope(
        plaintextJson,
        key,
        salt: salt,
        iterations: iterations,
      ),
    );
  }

  static Uint8List _buildEnvelope(
    String plaintextJson,
    Uint8List key, {
    required Uint8List salt,
    required int iterations,
  }) {
    final nonce = _randomBytes(nonceLength);
    final metadata = _metadata(
      salt: salt,
      nonce: nonce,
      iterations: iterations,
    );
    final ciphertextWithTag = _encryptAesGcm(
      utf8.encode(plaintextJson),
      key,
      nonce,
      _authenticatedData(metadata),
    );

    final envelope = {
      ...metadata,
      'ciphertext': base64.encode(ciphertextWithTag),
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  static Future<String> decrypt(
    Uint8List vaultBytes,
    String password,
  ) async {
    return Isolate.run(() => _decryptSync(vaultBytes, password));
  }

  static VaultKdfParameters readKdfParameters(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    final metadata = _validateAndExtractMetadata(envelope);
    final kdf = metadata['kdf'] as Map<String, dynamic>;
    return VaultKdfParameters(
      salt: base64.decode(kdf['salt'] as String),
      iterations: kdf['iterations'] as int,
    );
  }

  /// Validates the full envelope structure, including the ciphertext field,
  /// without decrypting. Throws on any structural problem. Cannot prove the
  /// ciphertext decrypts - that requires the password.
  static void validateEnvelope(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    _validateAndExtractMetadata(envelope);
    final ciphertextWithTag = _readBase64String(
      envelope,
      'ciphertext',
      'Invalid encrypted vault ciphertext',
    );
    if (ciphertextWithTag.length < authTagLength) {
      throw const FormatException('Invalid encrypted vault ciphertext length');
    }
  }

  static String _decryptSync(
    Uint8List vaultBytes,
    String password,
  ) {
    if (password.isEmpty) {
      throw ArgumentError('Password required for encrypted vault');
    }

    final envelope = _decodeEnvelope(vaultBytes);
    final metadata = _validateAndExtractMetadata(envelope);
    final kdf = metadata['kdf'] as Map<String, dynamic>;
    final cipher = metadata['cipher'] as Map<String, dynamic>;
    final salt = base64.decode(kdf['salt'] as String);
    final nonce = base64.decode(cipher['nonce'] as String);
    final iterations = kdf['iterations'] as int;
    final ciphertextWithTag = _readBase64String(
      envelope,
      'ciphertext',
      'Invalid encrypted vault ciphertext',
    );

    final key = _deriveKey(password, salt, iterations);
    final plaintext = _decryptAesGcm(
      ciphertextWithTag,
      key,
      nonce,
      _authenticatedData(metadata),
    );

    return utf8.decode(plaintext);
  }

  static Map<String, dynamic> _metadata({
    required Uint8List salt,
    required Uint8List nonce,
    required int iterations,
  }) {
    return {
      'magic': magic,
      'version': version,
      'kdf': {
        'name': kdfName,
        'salt': base64.encode(salt),
        'iterations': iterations,
        'keyLength': keyLength,
      },
      'cipher': {
        'name': cipherName,
        'nonce': base64.encode(nonce),
        'tagLength': authTagLength,
      },
    };
  }

  static Map<String, dynamic> _decodeEnvelope(Uint8List vaultBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(vaultBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid encrypted vault format');
      }
      return decoded;
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw const FormatException('Invalid encrypted vault format');
    }
  }

  static Map<String, dynamic> _validateAndExtractMetadata(
    Map<String, dynamic> envelope,
  ) {
    if (envelope['magic'] != magic) {
      throw const FormatException('Invalid encrypted vault file');
    }
    if (envelope['version'] != version) {
      throw UnsupportedError('Unsupported encrypted vault version');
    }

    final kdf = envelope['kdf'];
    final cipher = envelope['cipher'];
    if (kdf is! Map<String, dynamic> || cipher is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted vault metadata');
    }
    if (kdf['name'] != kdfName) {
      throw UnsupportedError('Unsupported encrypted vault KDF');
    }
    if (cipher['name'] != cipherName) {
      throw UnsupportedError('Unsupported encrypted vault cipher');
    }
    if (kdf['iterations'] is! int ||
        (kdf['iterations'] as int) <= 0 ||
        (kdf['iterations'] as int) > maxIterations) {
      throw const FormatException('Invalid encrypted vault KDF iterations');
    }
    if (kdf['keyLength'] != keyLength) {
      throw const FormatException('Invalid encrypted vault key length');
    }
    if (cipher['tagLength'] != authTagLength) {
      throw const FormatException('Invalid encrypted vault auth tag length');
    }

    final salt = _readBase64String(kdf, 'salt', 'Invalid encrypted vault salt');
    final nonce =
        _readBase64String(cipher, 'nonce', 'Invalid encrypted vault nonce');
    if (salt.length != saltLength) {
      throw const FormatException('Invalid encrypted vault salt length');
    }
    if (nonce.length != nonceLength) {
      throw const FormatException('Invalid encrypted vault nonce length');
    }

    return _metadata(
      salt: salt,
      nonce: nonce,
      iterations: kdf['iterations'] as int,
    );
  }

  static Uint8List _readBase64String(
    Map<String, dynamic> source,
    String key,
    String errorMessage,
  ) {
    final value = source[key];
    if (value is! String || value.isEmpty) {
      throw FormatException(errorMessage);
    }
    try {
      return base64.decode(value);
    } catch (_) {
      throw FormatException(errorMessage);
    }
  }

  static Uint8List _authenticatedData(Map<String, dynamic> metadata) {
    return Uint8List.fromList(utf8.encode(jsonEncode(metadata)));
  }

  static Uint8List _deriveKey(
    String password,
    Uint8List salt,
    int iterations,
  ) {
    return derivePbkdf2HmacSha256Key(password, salt, iterations, keyLength);
  }

  static Uint8List _encryptAesGcm(
    List<int> plaintext,
    Uint8List key,
    Uint8List nonce,
    Uint8List authenticatedData,
  ) {
    return aesGcmEncrypt(
      key,
      nonce,
      Uint8List.fromList(plaintext),
      authenticatedData,
      authTagLength,
    );
  }

  static Uint8List _decryptAesGcm(
    Uint8List ciphertextWithTag,
    Uint8List key,
    Uint8List nonce,
    Uint8List authenticatedData,
  ) {
    if (ciphertextWithTag.length < authTagLength) {
      throw const FormatException('Invalid encrypted vault ciphertext length');
    }

    try {
      return aesGcmDecrypt(
        key,
        nonce,
        ciphertextWithTag,
        authenticatedData,
        authTagLength,
      );
    } catch (_) {
      throw ArgumentError('Invalid password or corrupted encrypted vault');
    }
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}
