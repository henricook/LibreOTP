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

/// The material needed to rewrite a v2 vault during a session without
/// re-deriving any key: the data encryption key plus the exact key slots to
/// preserve. Slots are held as canonical maps (unknown slot types verbatim) so
/// every save reproduces a stable payload AAD and forwards-compatible slots.
class VaultSessionKeys {
  final Uint8List dek;
  final List<Map<String, dynamic>> keySlots;

  const VaultSessionKeys({required this.dek, required this.keySlots});

  bool get hasKeyringSlot => keySlots
      .any((slot) => slot['type'] == LocalVaultEncryptionService.slotKeyring);

  String? get keyringKekId {
    for (final slot in keySlots) {
      if (slot['type'] == LocalVaultEncryptionService.slotKeyring) {
        final id = slot['kekId'];
        if (id is String) {
          return id;
        }
      }
    }
    return null;
  }
}

/// A successfully decrypted vault payload plus, for v2, the session material to
/// keep it unlocked. [needsUpgrade] flags a v1 file that should be transparently
/// rewritten as v2 by the caller.
class UnlockedVault {
  final String plaintextJson;
  final VaultSessionKeys? sessionKeys;
  final bool needsUpgrade;

  const UnlockedVault({
    required this.plaintextJson,
    this.sessionKeys,
    this.needsUpgrade = false,
  });
}

/// A freshly built v2 vault: the bytes to persist and the session material that
/// unlocks them.
class VaultBuildResult {
  final Uint8List bytes;
  final VaultSessionKeys session;

  const VaultBuildResult({required this.bytes, required this.session});
}

class LocalVaultEncryptionService {
  static const String magic = 'LibreOTPVault';
  static const int version = 1;
  static const int version2 = 2;
  static const String kdfName = 'PBKDF2-HMAC-SHA256';
  static const String cipherName = 'AES-256-GCM';
  static const String slotPassword = 'password';
  static const String slotKeyring = 'keyring';
  static const int keyLength = 32;
  static const int saltLength = 32;
  static const int nonceLength = 12;
  static const int authTagLength = 16;
  static const int wrappedKeyLength = keyLength + authTagLength;
  static const int defaultIterations = 600000;
  static const int maxIterations = 10000000;

  // ---------------------------------------------------------------------------
  // v1 envelope (password-derived key encrypts the payload directly)
  // ---------------------------------------------------------------------------

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
    return _buildEnvelopeV1(
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
      () => _buildEnvelopeV1(
        plaintextJson,
        key,
        salt: salt,
        iterations: iterations,
      ),
    );
  }

  static Uint8List _buildEnvelopeV1(
    String plaintextJson,
    Uint8List key, {
    required Uint8List salt,
    required int iterations,
  }) {
    final nonce = _randomBytes(nonceLength);
    final metadata = _metadataV1(
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

  // ---------------------------------------------------------------------------
  // v2 envelope (random DEK encrypts the payload, wrapped by one or more slots)
  // ---------------------------------------------------------------------------

  /// Builds a fresh v2 vault: a random DEK guarded by a single password slot.
  static Future<VaultBuildResult> createEncryptedVault(
    String plaintextJson,
    String password, {
    int iterations = defaultIterations,
  }) async {
    return Isolate.run(
      () => _createV2Sync(plaintextJson, password, iterations: iterations),
    );
  }

  static VaultBuildResult _createV2Sync(
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

    final dek = _randomBytes(keyLength);
    final slots = [_buildPasswordSlot(dek, password, iterations)];
    final bytes = _buildEnvelopeV2(plaintextJson, dek, slots);
    return VaultBuildResult(
      bytes: bytes,
      session: VaultSessionKeys(dek: dek, keySlots: slots),
    );
  }

  /// Rewrites a v2 vault's payload with the cached DEK, preserving every slot.
  static Future<Uint8List> buildEnvelopeFromSession(
    String plaintextJson,
    VaultSessionKeys session,
  ) async {
    final dek = session.dek;
    final slots = session.keySlots;
    return Isolate.run(() => _buildEnvelopeV2(plaintextJson, dek, slots));
  }

  /// Returns a session with a keyring slot wrapping the DEK, replacing any
  /// existing keyring slot.
  static Future<VaultSessionKeys> addKeyringSlotToSession(
    VaultSessionKeys session,
    String kekId,
    Uint8List kek,
  ) async {
    final dek = session.dek;
    final existing = session.keySlots;
    final newSlot = await Isolate.run(() => _buildKeyringSlot(dek, kekId, kek));
    final slots = [
      ...existing.where((slot) => slot['type'] != slotKeyring),
      newSlot,
    ];
    return VaultSessionKeys(dek: dek, keySlots: slots);
  }

  /// Returns a session without any keyring slot. No crypto is required.
  static VaultSessionKeys removeKeyringSlotFromSession(
    VaultSessionKeys session,
  ) {
    final slots =
        session.keySlots.where((slot) => slot['type'] != slotKeyring).toList();
    return VaultSessionKeys(dek: session.dek, keySlots: slots);
  }

  /// Returns a session whose password slot is re-wrapped under [password] with a
  /// fresh salt and nonce. All other slots are preserved so auto-unlock keeps
  /// working across a password change.
  static Future<VaultSessionKeys> rewrapPasswordSlot(
    VaultSessionKeys session,
    String password, {
    int iterations = defaultIterations,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError('Password required for encrypted vault');
    }
    final dek = session.dek;
    final existing = session.keySlots;
    final newSlot = await Isolate.run(
      () => _buildPasswordSlot(dek, password, iterations),
    );
    final slots = [
      newSlot,
      ...existing.where((slot) => slot['type'] != slotPassword),
    ];
    return VaultSessionKeys(dek: dek, keySlots: slots);
  }

  static Uint8List generateKeyEncryptionKey() => _randomBytes(keyLength);

  // ---------------------------------------------------------------------------
  // Unlock (version-aware)
  // ---------------------------------------------------------------------------

  /// Returns the plaintext payload for [password], for either envelope version.
  static Future<String> decrypt(
    Uint8List vaultBytes,
    String password,
  ) async {
    return Isolate.run(
      () => _unlockWithPasswordSync(vaultBytes, password).plaintextJson,
    );
  }

  static Future<UnlockedVault> unlockWithPassword(
    Uint8List vaultBytes,
    String password,
  ) async {
    return Isolate.run(() => _unlockWithPasswordSync(vaultBytes, password));
  }

  static UnlockedVault _unlockWithPasswordSync(
    Uint8List vaultBytes,
    String password,
  ) {
    if (password.isEmpty) {
      throw ArgumentError('Password required for encrypted vault');
    }
    final envelope = _decodeEnvelope(vaultBytes);
    final ver = envelope['version'];
    if (ver == version) {
      return UnlockedVault(
        plaintextJson: _decryptV1Sync(vaultBytes, envelope, password),
        needsUpgrade: true,
      );
    }
    if (ver == version2) {
      return _unlockV2WithPasswordSync(vaultBytes, envelope, password);
    }
    throw UnsupportedError('Unsupported encrypted vault version');
  }

  static Future<UnlockedVault> unlockWithKeyringKek(
    Uint8List vaultBytes,
    String kekId,
    Uint8List kek,
  ) async {
    return Isolate.run(
      () => _unlockV2WithKeyringSync(vaultBytes, kekId, kek),
    );
  }

  /// Decrypts a v2 payload with a known DEK. Used to verify a session save
  /// round-trips before the atomic swap replaces the good vault.
  static Future<String> decryptWithDek(
    Uint8List vaultBytes,
    Uint8List dek,
  ) async {
    return Isolate.run(() {
      final envelope = _decodeEnvelope(vaultBytes);
      if (envelope['version'] != version2) {
        throw UnsupportedError('DEK decrypt requires a v2 encrypted vault');
      }
      final parsed = _validateAndExtractV2(envelope);
      return _decryptPayloadV2(vaultBytes, parsed, dek);
    });
  }

  static UnlockedVault _unlockV2WithPasswordSync(
    Uint8List vaultBytes,
    Map<String, dynamic> envelope,
    String password,
  ) {
    final parsed = _validateAndExtractV2(envelope);
    final passwordSlot = parsed.slots.firstWhere(
      (slot) => slot['type'] == slotPassword,
      orElse: () =>
          throw const FormatException('Encrypted vault has no password slot'),
    );
    final dek = _unwrapDekFromPasswordSlot(passwordSlot, password);
    final plaintext = _decryptPayloadV2(vaultBytes, parsed, dek);
    return UnlockedVault(
      plaintextJson: plaintext,
      sessionKeys: VaultSessionKeys(dek: dek, keySlots: parsed.slots),
    );
  }

  static UnlockedVault _unlockV2WithKeyringSync(
    Uint8List vaultBytes,
    String kekId,
    Uint8List kek,
  ) {
    final envelope = _decodeEnvelope(vaultBytes);
    if (envelope['version'] != version2) {
      throw UnsupportedError('Keyring unlock requires a v2 encrypted vault');
    }
    final parsed = _validateAndExtractV2(envelope);
    final keyringSlot = parsed.slots.firstWhere(
      (slot) => slot['type'] == slotKeyring && slot['kekId'] == kekId,
      orElse: () =>
          throw const FormatException('No matching keyring slot in vault'),
    );
    final dek = _unwrapDekFromKeyringSlot(keyringSlot, kek);
    final plaintext = _decryptPayloadV2(vaultBytes, parsed, dek);
    return UnlockedVault(
      plaintextJson: plaintext,
      sessionKeys: VaultSessionKeys(dek: dek, keySlots: parsed.slots),
    );
  }

  // ---------------------------------------------------------------------------
  // Inspection helpers (no heavy crypto, safe on the main isolate)
  // ---------------------------------------------------------------------------

  static int readVersion(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    final ver = envelope['version'];
    if (ver is! int) {
      throw const FormatException('Invalid encrypted vault version');
    }
    return ver;
  }

  /// The kekId of the keyring slot if [vaultBytes] is a v2 vault carrying one,
  /// otherwise null.
  static String? readKeyringKekId(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    if (envelope['version'] != version2) {
      return null;
    }
    final slots = envelope['keySlots'];
    if (slots is! List) {
      return null;
    }
    for (final slot in slots) {
      if (slot is Map && slot['type'] == slotKeyring) {
        final id = slot['kekId'];
        if (id is String && id.isNotEmpty) {
          return id;
        }
      }
    }
    return null;
  }

  static VaultKdfParameters readKdfParameters(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    if (envelope['version'] == version2) {
      final parsed = _validateAndExtractV2(envelope);
      final passwordSlot = parsed.slots.firstWhere(
        (slot) => slot['type'] == slotPassword,
        orElse: () =>
            throw const FormatException('Encrypted vault has no password slot'),
      );
      final kdf = passwordSlot['kdf'] as Map<String, dynamic>;
      return VaultKdfParameters(
        salt: base64.decode(kdf['salt'] as String),
        iterations: kdf['iterations'] as int,
      );
    }

    final metadata = _validateAndExtractMetadataV1(envelope);
    final kdf = metadata['kdf'] as Map<String, dynamic>;
    return VaultKdfParameters(
      salt: base64.decode(kdf['salt'] as String),
      iterations: kdf['iterations'] as int,
    );
  }

  /// Validates the full envelope structure of either version, including the
  /// ciphertext field, without decrypting. Throws on any structural problem.
  /// Cannot prove the ciphertext decrypts - that requires a key.
  static void validateEnvelope(Uint8List vaultBytes) {
    final envelope = _decodeEnvelope(vaultBytes);
    if (envelope['version'] == version2) {
      _validateAndExtractV2(envelope);
    } else {
      _validateAndExtractMetadataV1(envelope);
    }
    final ciphertextWithTag = _readBase64String(
      envelope,
      'ciphertext',
      'Invalid encrypted vault ciphertext',
    );
    if (ciphertextWithTag.length < authTagLength) {
      throw const FormatException('Invalid encrypted vault ciphertext length');
    }
  }

  // ---------------------------------------------------------------------------
  // v1 decrypt internals
  // ---------------------------------------------------------------------------

  static String _decryptV1Sync(
    Uint8List vaultBytes,
    Map<String, dynamic> envelope,
    String password,
  ) {
    final metadata = _validateAndExtractMetadataV1(envelope);
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

  static Map<String, dynamic> _metadataV1({
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

  static Map<String, dynamic> _validateAndExtractMetadataV1(
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
    _validateKdfBounds(kdf);
    _validateCipherTag(cipher);

    final salt = _readBase64String(kdf, 'salt', 'Invalid encrypted vault salt');
    final nonce =
        _readBase64String(cipher, 'nonce', 'Invalid encrypted vault nonce');
    if (salt.length != saltLength) {
      throw const FormatException('Invalid encrypted vault salt length');
    }
    if (nonce.length != nonceLength) {
      throw const FormatException('Invalid encrypted vault nonce length');
    }

    return _metadataV1(
      salt: salt,
      nonce: nonce,
      iterations: kdf['iterations'] as int,
    );
  }

  // ---------------------------------------------------------------------------
  // v2 build internals
  // ---------------------------------------------------------------------------

  static Uint8List _buildEnvelopeV2(
    String plaintextJson,
    Uint8List dek,
    List<Map<String, dynamic>> slots,
  ) {
    final canonicalSlots = slots
        .map((slot) => _canonicalSlot(slot, includeWrappedKey: true))
        .toList();
    if (!canonicalSlots.any((slot) => slot['type'] == slotPassword)) {
      throw StateError('A v2 encrypted vault must contain a password slot');
    }

    final cipherNonce = _randomBytes(nonceLength);
    final metadata = _metadataV2(
      keySlots: canonicalSlots,
      cipherNonce: cipherNonce,
    );
    final ciphertextWithTag = _encryptAesGcm(
      utf8.encode(plaintextJson),
      dek,
      cipherNonce,
      _authenticatedData(metadata),
    );

    final envelope = {
      ...metadata,
      'ciphertext': base64.encode(ciphertextWithTag),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  static Map<String, dynamic> _buildPasswordSlot(
    Uint8List dek,
    String password,
    int iterations,
  ) {
    if (iterations <= 0) {
      throw ArgumentError('KDF iterations must be greater than zero');
    }
    final salt = _randomBytes(saltLength);
    final nonce = _randomBytes(nonceLength);
    final kek = _deriveKey(password, salt, iterations);
    final wrappedKey = _wrapKey(
      dek,
      kek,
      nonce,
      _passwordSlotAad(salt: salt, iterations: iterations, nonce: nonce),
    );
    return {
      'type': slotPassword,
      'kdf': {
        'name': kdfName,
        'salt': base64.encode(salt),
        'iterations': iterations,
        'keyLength': keyLength,
      },
      'wrap': {
        'name': cipherName,
        'nonce': base64.encode(nonce),
        'tagLength': authTagLength,
        'wrappedKey': base64.encode(wrappedKey),
      },
    };
  }

  static Map<String, dynamic> _buildKeyringSlot(
    Uint8List dek,
    String kekId,
    Uint8List kek,
  ) {
    if (kekId.isEmpty) {
      throw ArgumentError('Keyring slot requires a kekId');
    }
    if (kek.length != keyLength) {
      throw ArgumentError('Keyring KEK must be $keyLength bytes');
    }
    final nonce = _randomBytes(nonceLength);
    final wrappedKey = _wrapKey(
      dek,
      kek,
      nonce,
      _keyringSlotAad(kekId: kekId, nonce: nonce),
    );
    return {
      'type': slotKeyring,
      'kekId': kekId,
      'wrap': {
        'name': cipherName,
        'nonce': base64.encode(nonce),
        'tagLength': authTagLength,
        'wrappedKey': base64.encode(wrappedKey),
      },
    };
  }

  static Uint8List _unwrapDekFromPasswordSlot(
    Map<String, dynamic> slot,
    String password,
  ) {
    if (password.isEmpty) {
      throw ArgumentError('Password required for encrypted vault');
    }
    final kdf = slot['kdf'] as Map<String, dynamic>;
    final wrap = slot['wrap'] as Map<String, dynamic>;
    final salt = base64.decode(kdf['salt'] as String);
    final iterations = kdf['iterations'] as int;
    final nonce = base64.decode(wrap['nonce'] as String);
    final wrappedKey = base64.decode(wrap['wrappedKey'] as String);
    final kek = _deriveKey(password, salt, iterations);
    final dek = _unwrapKey(
      wrappedKey,
      kek,
      nonce,
      _passwordSlotAad(salt: salt, iterations: iterations, nonce: nonce),
    );
    if (dek.length != keyLength) {
      throw const FormatException('Invalid unwrapped data key length');
    }
    return dek;
  }

  static Uint8List _unwrapDekFromKeyringSlot(
    Map<String, dynamic> slot,
    Uint8List kek,
  ) {
    if (kek.length != keyLength) {
      throw ArgumentError('Keyring KEK must be $keyLength bytes');
    }
    final wrap = slot['wrap'] as Map<String, dynamic>;
    final kekId = slot['kekId'] as String;
    final nonce = base64.decode(wrap['nonce'] as String);
    final wrappedKey = base64.decode(wrap['wrappedKey'] as String);
    final dek = _unwrapKey(
      wrappedKey,
      kek,
      nonce,
      _keyringSlotAad(kekId: kekId, nonce: nonce),
    );
    if (dek.length != keyLength) {
      throw const FormatException('Invalid unwrapped data key length');
    }
    return dek;
  }

  static String _decryptPayloadV2(
    Uint8List vaultBytes,
    _ParsedV2 parsed,
    Uint8List dek,
  ) {
    final envelope = _decodeEnvelope(vaultBytes);
    final ciphertextWithTag = _readBase64String(
      envelope,
      'ciphertext',
      'Invalid encrypted vault ciphertext',
    );
    final plaintext = _decryptAesGcm(
      ciphertextWithTag,
      dek,
      parsed.cipherNonce,
      _authenticatedData(parsed.metadata),
    );
    return utf8.decode(plaintext);
  }

  static Uint8List _passwordSlotAad({
    required Uint8List salt,
    required int iterations,
    required Uint8List nonce,
  }) {
    final slot = {
      'type': slotPassword,
      'kdf': {
        'name': kdfName,
        'salt': base64.encode(salt),
        'iterations': iterations,
        'keyLength': keyLength,
      },
      'wrap': {
        'name': cipherName,
        'nonce': base64.encode(nonce),
        'tagLength': authTagLength,
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(slot)));
  }

  static Uint8List _keyringSlotAad({
    required String kekId,
    required Uint8List nonce,
  }) {
    final slot = {
      'type': slotKeyring,
      'kekId': kekId,
      'wrap': {
        'name': cipherName,
        'nonce': base64.encode(nonce),
        'tagLength': authTagLength,
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(slot)));
  }

  static Map<String, dynamic> _metadataV2({
    required List<Map<String, dynamic>> keySlots,
    required Uint8List cipherNonce,
  }) {
    return {
      'magic': magic,
      'version': version2,
      'keySlots': keySlots
          .map((slot) => _canonicalSlot(slot, includeWrappedKey: true))
          .toList(),
      'cipher': {
        'name': cipherName,
        'nonce': base64.encode(cipherNonce),
        'tagLength': authTagLength,
      },
    };
  }

  /// Rebuilds a slot map in fixed key order so the AAD is stable across saves.
  /// Unknown slot types are preserved verbatim for forward compatibility.
  static Map<String, dynamic> _canonicalSlot(
    Map<String, dynamic> slot, {
    required bool includeWrappedKey,
  }) {
    final type = slot['type'];
    if (type == slotPassword) {
      final kdf = slot['kdf'] as Map<String, dynamic>;
      final wrap = slot['wrap'] as Map<String, dynamic>;
      return {
        'type': slotPassword,
        'kdf': {
          'name': kdf['name'],
          'salt': kdf['salt'],
          'iterations': kdf['iterations'],
          'keyLength': kdf['keyLength'],
        },
        'wrap': _canonicalWrap(wrap, includeWrappedKey: includeWrappedKey),
      };
    }
    if (type == slotKeyring) {
      final wrap = slot['wrap'] as Map<String, dynamic>;
      return {
        'type': slotKeyring,
        'kekId': slot['kekId'],
        'wrap': _canonicalWrap(wrap, includeWrappedKey: includeWrappedKey),
      };
    }
    return slot;
  }

  static Map<String, dynamic> _canonicalWrap(
    Map<String, dynamic> wrap, {
    required bool includeWrappedKey,
  }) {
    final result = <String, dynamic>{
      'name': wrap['name'],
      'nonce': wrap['nonce'],
      'tagLength': wrap['tagLength'],
    };
    if (includeWrappedKey) {
      result['wrappedKey'] = wrap['wrappedKey'];
    }
    return result;
  }

  static _ParsedV2 _validateAndExtractV2(Map<String, dynamic> envelope) {
    if (envelope['magic'] != magic) {
      throw const FormatException('Invalid encrypted vault file');
    }
    if (envelope['version'] != version2) {
      throw UnsupportedError('Unsupported encrypted vault version');
    }

    final rawSlots = envelope['keySlots'];
    if (rawSlots is! List || rawSlots.isEmpty) {
      throw const FormatException('Invalid encrypted vault key slots');
    }
    final slots = <Map<String, dynamic>>[];
    for (final raw in rawSlots) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid encrypted vault key slot');
      }
      _validateSlot(raw);
      slots.add(_canonicalSlot(raw, includeWrappedKey: true));
    }

    final cipher = envelope['cipher'];
    if (cipher is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted vault metadata');
    }
    if (cipher['name'] != cipherName) {
      throw UnsupportedError('Unsupported encrypted vault cipher');
    }
    _validateCipherTag(cipher);
    final cipherNonce =
        _readBase64String(cipher, 'nonce', 'Invalid encrypted vault nonce');
    if (cipherNonce.length != nonceLength) {
      throw const FormatException('Invalid encrypted vault nonce length');
    }

    return _ParsedV2(
      slots: slots,
      cipherNonce: cipherNonce,
      metadata: _metadataV2(keySlots: slots, cipherNonce: cipherNonce),
    );
  }

  static void _validateSlot(Map<String, dynamic> slot) {
    final type = slot['type'];
    if (type == slotPassword) {
      final kdf = slot['kdf'];
      if (kdf is! Map<String, dynamic>) {
        throw const FormatException('Invalid encrypted vault key slot');
      }
      if (kdf['name'] != kdfName) {
        throw UnsupportedError('Unsupported encrypted vault KDF');
      }
      _validateKdfBounds(kdf);
      final salt =
          _readBase64String(kdf, 'salt', 'Invalid encrypted vault salt');
      if (salt.length != saltLength) {
        throw const FormatException('Invalid encrypted vault salt length');
      }
      _validateWrap(slot);
      return;
    }
    if (type == slotKeyring) {
      final kekId = slot['kekId'];
      if (kekId is! String || kekId.isEmpty) {
        throw const FormatException('Invalid encrypted vault keyring slot');
      }
      _validateWrap(slot);
      return;
    }
    // Unknown slot types are tolerated and preserved verbatim.
  }

  static void _validateWrap(Map<String, dynamic> slot) {
    final wrap = slot['wrap'];
    if (wrap is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted vault key slot wrap');
    }
    if (wrap['name'] != cipherName) {
      throw UnsupportedError('Unsupported encrypted vault key wrap cipher');
    }
    _validateCipherTag(wrap);
    final nonce =
        _readBase64String(wrap, 'nonce', 'Invalid encrypted vault key nonce');
    if (nonce.length != nonceLength) {
      throw const FormatException('Invalid encrypted vault key nonce length');
    }
    final wrappedKey = _readBase64String(
      wrap,
      'wrappedKey',
      'Invalid encrypted vault wrapped key',
    );
    if (wrappedKey.length != wrappedKeyLength) {
      throw const FormatException('Invalid encrypted vault wrapped key length');
    }
  }

  static void _validateKdfBounds(Map<String, dynamic> kdf) {
    final iterations = kdf['iterations'];
    if (iterations is! int || iterations <= 0 || iterations > maxIterations) {
      throw const FormatException('Invalid encrypted vault KDF iterations');
    }
    if (kdf['keyLength'] != keyLength) {
      throw const FormatException('Invalid encrypted vault key length');
    }
  }

  static void _validateCipherTag(Map<String, dynamic> cipher) {
    if (cipher['tagLength'] != authTagLength) {
      throw const FormatException('Invalid encrypted vault auth tag length');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

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

  static Uint8List _wrapKey(
    Uint8List dek,
    Uint8List kek,
    Uint8List nonce,
    Uint8List authenticatedData,
  ) {
    return aesGcmEncrypt(kek, nonce, dek, authenticatedData, authTagLength);
  }

  static Uint8List _unwrapKey(
    Uint8List wrappedKey,
    Uint8List kek,
    Uint8List nonce,
    Uint8List authenticatedData,
  ) {
    if (wrappedKey.length < authTagLength) {
      throw const FormatException('Invalid encrypted vault wrapped key length');
    }
    try {
      return aesGcmDecrypt(
        kek,
        nonce,
        wrappedKey,
        authenticatedData,
        authTagLength,
      );
    } catch (_) {
      throw ArgumentError('Invalid password or corrupted encrypted vault');
    }
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

class _ParsedV2 {
  final List<Map<String, dynamic>> slots;
  final Uint8List cipherNonce;
  final Map<String, dynamic> metadata;

  const _ParsedV2({
    required this.slots,
    required this.cipherNonce,
    required this.metadata,
  });
}
