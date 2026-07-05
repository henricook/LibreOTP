import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

Uint8List derivePbkdf2HmacSha256Key(
  String password,
  Uint8List salt,
  int iterations,
  int keyLength,
) {
  final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));
  return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
}

Uint8List aesGcmEncrypt(
  Uint8List key,
  Uint8List nonce,
  Uint8List plaintext,
  Uint8List aad,
  int tagLengthBytes,
) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(KeyParameter(key), tagLengthBytes * 8, nonce, aad),
  );
  return cipher.process(plaintext);
}

Uint8List aesGcmDecrypt(
  Uint8List key,
  Uint8List nonce,
  Uint8List ciphertextWithTag,
  Uint8List aad,
  int tagLengthBytes,
) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    false,
    AEADParameters(KeyParameter(key), tagLengthBytes * 8, nonce, aad),
  );
  return cipher.process(ciphertextWithTag);
}
