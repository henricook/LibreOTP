import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/services/twofas_decryption_service.dart';

void main() {
  group('TwoFasDecryptionService', () {
    late Map<String, dynamic> testEncryptedBackup;
    late Map<String, dynamic> testUnencryptedBackup;
    const String testPassword = 'testPassword123';

    setUpAll(() async {
      // Load test encrypted backup
      final encryptedFile = File('test/fixtures/test_encrypted_backup.2fas');
      if (await encryptedFile.exists()) {
        final contents = await encryptedFile.readAsString();
        testEncryptedBackup = jsonDecode(contents) as Map<String, dynamic>;
      }

      // Create unencrypted backup for comparison
      testUnencryptedBackup = {
        'services': [
          {
            'name': 'TestService',
            'secret': 'JBSWY3DPEHPK3PXP',
            'otp': {'issuer': 'Test', 'digits': 6}
          }
        ],
        'groups': []
      };
    });

    test('should detect encrypted backup correctly', () {
      expect(TwoFasDecryptionService.isEncrypted(testEncryptedBackup), isTrue);
      expect(TwoFasDecryptionService.isEncrypted(testUnencryptedBackup), isFalse);
    });

    test('should detect unencrypted backup correctly', () {
      final emptyBackup = <String, dynamic>{};
      expect(TwoFasDecryptionService.isEncrypted(emptyBackup), isFalse);
      
      final backupWithEmptyServices = {'servicesEncrypted': ''};
      expect(TwoFasDecryptionService.isEncrypted(backupWithEmptyServices), isFalse);
    });

    test('should decrypt encrypted backup with correct password', () async {
      final decryptedServices = await TwoFasDecryptionService.decryptBackup(
        testEncryptedBackup, 
        testPassword
      );
      
      final servicesList = jsonDecode(decryptedServices) as List;
      expect(servicesList, isNotEmpty);
      expect(servicesList.length, equals(2));
      
      final firstService = servicesList[0] as Map<String, dynamic>;
      expect(firstService['name'], equals('TestService1'));
      expect(firstService['secret'], equals('JBSWY3DPEHPK3PXP'));
    });

    test('should throw error with wrong password', () async {
      expect(
        () => TwoFasDecryptionService.decryptBackup(testEncryptedBackup, 'wrongPassword'),
        throwsA(isA<ArgumentError>())
      );
    });

    test('should throw error for unencrypted backup', () async {
      expect(
        () => TwoFasDecryptionService.decryptBackup(testUnencryptedBackup, testPassword),
        throwsA(isA<ArgumentError>())
      );
    });

    test('should throw error for malformed encrypted data', () async {
      final malformedBackup = {
        'servicesEncrypted': 'invalid:format'
      };
      
      expect(
        () => TwoFasDecryptionService.decryptBackup(malformedBackup, testPassword),
        throwsA(isA<FormatException>())
      );
    });

    test('should throw error for corrupted base64 data', () async {
      final corruptedBackup = {
        'servicesEncrypted': 'invalid_base64:invalid_base64:invalid_base64'
      };
      
      expect(
        () => TwoFasDecryptionService.decryptBackup(corruptedBackup, testPassword),
        throwsA(isA<FormatException>())
      );
    });
  });
}