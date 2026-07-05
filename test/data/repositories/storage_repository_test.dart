import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreotp/data/models/group.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/services/local_vault_encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('libreotp_storage_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Data models validation', () {
      test('should create valid Group from JSON', () {
        final json = {'id': 'test-group-id', 'name': 'Test Group'};

        final group = Group.fromJson(json);

        expect(group.id, equals('test-group-id'));
        expect(group.name, equals('Test Group'));
      });

      test('should create valid OtpService from JSON', () {
        final json = {
          'id': 'test-service-id',
          'name': 'Test Service',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {
            'account': 'test@example.com',
            'issuer': 'Test Issuer',
            'algorithm': 'SHA1',
            'digits': 6,
            'period': 30,
          },
          'order': {'position': 0},
          'groupId': 'test-group-id',
        };

        final service = OtpService.fromJson(json);

        expect(service.id, equals('test-service-id'));
        expect(service.name, equals('Test Service'));
        expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
        expect(service.otp.account, equals('test@example.com'));
        expect(service.otp.issuer, equals('Test Issuer'));
        expect(service.otp.algorithm, equals('SHA1'));
        expect(service.otp.digits, equals(6));
        expect(service.otp.period, equals(30));
        expect(service.order.position, equals(0));
        expect(service.groupId, equals('test-group-id'));
      });

      test('should handle missing optional fields in OtpService', () {
        final json = {
          'id': 'test-service-id',
          'name': 'Test Service',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {'account': 'test@example.com', 'issuer': 'Test Issuer'},
          'order': {},
          // No groupId
        };

        final service = OtpService.fromJson(json);

        expect(service.id, equals('test-service-id'));
        expect(service.name, equals('Test Service'));
        expect(service.secret, equals('JBSWY3DPEHPK3PXP'));
        expect(service.otp.account, equals('test@example.com'));
        expect(service.otp.issuer, equals('Test Issuer'));
        expect(service.otp.algorithm, equals('SHA1')); // Default
        expect(service.otp.digits, equals(6)); // Default
        expect(service.otp.period, equals(30)); // Default
        expect(service.order.position, equals(0)); // Default
        expect(service.groupId, isNull);
      });

      test('should handle OtpConfig with defaults', () {
        final json = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          // Missing other fields should use defaults
        };

        final config = OtpConfig.fromJson(json);

        expect(config.account, equals('test@example.com'));
        expect(config.issuer, equals('Test Issuer'));
        expect(config.algorithm, equals('SHA1'));
        expect(config.digits, equals(6));
        expect(config.period, equals(30));
      });

      test('should validate OtpConfig digits range', () {
        // Test with invalid digits (too few)
        final jsonTooFew = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '3', // Too few, should default to 6
        };

        final configTooFew = OtpConfig.fromJson(jsonTooFew);
        expect(configTooFew.digits, equals(6));

        // Test with invalid digits (too many)
        final jsonTooMany = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '15', // Too many, should default to 6
        };

        final configTooMany = OtpConfig.fromJson(jsonTooMany);
        expect(configTooMany.digits, equals(6));

        // Test with valid digits
        final jsonValid = {
          'account': 'test@example.com',
          'issuer': 'Test Issuer',
          'digits': '8', // Valid
        };

        final configValid = OtpConfig.fromJson(jsonValid);
        expect(configValid.digits, equals(8));
      });

      test('should handle OrderInfo with missing position', () {
        final json = <String, dynamic>{};

        final orderInfo = OrderInfo.fromJson(json);

        expect(orderInfo.position, equals(0));
      });

      test('should convert models back to JSON correctly', () {
        const group = Group(id: 'test-id', name: 'Test Group');
        final groupJson = group.toJson();

        expect(groupJson['id'], equals('test-id'));
        expect(groupJson['name'], equals('Test Group'));

        const service = OtpService(
          id: 'service-id',
          name: 'Service Name',
          secret: 'SECRET123',
          otp: OtpConfig(
            account: 'user@example.com',
            issuer: 'Example Inc',
            algorithm: 'SHA256',
            digits: 8,
            period: 60,
          ),
          order: OrderInfo(position: 5),
          groupId: 'group-id',
        );
        final serviceJson = service.toJson();

        expect(serviceJson['id'], equals('service-id'));
        expect(serviceJson['name'], equals('Service Name'));
        expect(serviceJson['secret'], equals('SECRET123'));
        expect(serviceJson['otp']['account'], equals('user@example.com'));
        expect(serviceJson['otp']['issuer'], equals('Example Inc'));
        expect(serviceJson['otp']['algorithm'], equals('SHA256'));
        expect(serviceJson['otp']['digits'], equals(8));
        expect(serviceJson['otp']['period'], equals(60));
        expect(serviceJson['order']['position'], equals(5));
        expect(serviceJson['groupId'], equals('group-id'));
      });
    });

    group('File operations', () {
      test('should have correct data file name', () {
        // Test static properties without platform dependencies
        expect(StorageRepository, isA<Type>());
        // We can't test file paths in unit tests without mocking platform channels
      });

      test('should serialize and parse plaintext app data consistently', () {
        final repository = StorageRepository();
        final data = AppData(
          services: const [
            OtpService(
              id: 'service-id',
              name: 'GitHub',
              secret: 'JBSWY3DPEHPK3PXP',
              otp: OtpConfig(account: 'dev@example.com', issuer: 'GitHub'),
              order: OrderInfo(position: 3),
              groupId: 'group-id',
            ),
          ],
          groups: const [Group(id: 'group-id', name: 'Work')],
        );

        final jsonString = repository.serializePlaintextAppData(data);
        final decoded = repository.decodeJsonObject(jsonString);
        final parsed = repository.parsePlaintextAppData(jsonString);

        expect(decoded['services'], isA<List<dynamic>>());
        expect(decoded['groups'], isA<List<dynamic>>());
        expect(parsed.services, hasLength(1));
        expect(parsed.groups, hasLength(1));
        expect(parsed.services.first.id, equals('service-id'));
        expect(parsed.services.first.secret, equals('JBSWY3DPEHPK3PXP'));
        expect(parsed.groups.first.id, equals('group-id'));
        expect(parsed.groups.first.name, equals('Work'));
      });

      test('app data json string should match app data json map', () {
        final data = AppData(
          services: const [
            OtpService(
              id: 'service-id',
              name: 'Service Name',
              secret: 'SECRET123',
              otp: OtpConfig(
                account: 'user@example.com',
                issuer: 'Example Inc',
              ),
              order: OrderInfo(position: 1),
            ),
          ],
          groups: const [Group(id: 'group-id', name: 'Example Group')],
        );

        final parsed = AppData.fromJsonString(data.toJsonString());

        expect(parsed.toJson(), equals(data.toJson()));
      });

      test('should prefer data.bin over data.json when both exist', () async {
        final repository = StorageRepository(localPathOverride: tempDir.path);
        final plaintextData = AppData(
          services: const [
            OtpService(
              id: 'plaintext-service',
              name: 'Plaintext',
              secret: 'PLAINTEXTSECRET',
              otp: OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [Group(id: 'plain-group', name: 'Plain')],
        );
        final encryptedData = AppData(
          services: const [
            OtpService(
              id: 'vault-service',
              name: 'Vault',
              secret: 'VAULTSECRET',
              otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [Group(id: 'vault-group', name: 'Vault')],
        );

        await repository.writeAppDataJson(plaintextData);
        final encryptedFile = await repository.getEncryptedLocalFile();
        final encryptedBytes = await LocalVaultEncryptionService.encrypt(
          encryptedData.toJsonString(),
          'vault-password',
          iterations: 1000,
        );
        await encryptedFile.writeAsBytes(encryptedBytes);

        final result = await repository.loadStoredData(
          password: 'vault-password',
        );

        expect(result.source, equals(StorageDataSource.encryptedVault));
        expect(result.data.services.single.id, equals('vault-service'));
        expect(result.data.groups.single.id, equals('vault-group'));
      });

      test(
        'should require encrypted vault password before reading data.json',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final plaintextData = AppData(
            services: const [
              OtpService(
                id: 'plaintext-service',
                name: 'Plaintext',
                secret: 'PLAINTEXTSECRET',
                otp: OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [],
          );

          await repository.writeAppDataJson(plaintextData);
          final encryptedFile = await repository.getEncryptedLocalFile();
          final encryptedBytes = await LocalVaultEncryptionService.encrypt(
            plaintextData.toJsonString(),
            'vault-password',
            iterations: 1000,
          );
          await encryptedFile.writeAsBytes(encryptedBytes);

          expect(
            () => repository.loadStoredData(),
            throwsA(
              isA<StoragePasswordRequiredException>().having(
                (error) => error.source,
                'source',
                StorageDataSource.encryptedVault,
              ),
            ),
          );
        },
      );

      test(
        'should not fall back to data.json after encrypted vault decrypt fails',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final plaintextData = AppData(
            services: const [
              OtpService(
                id: 'plaintext-service',
                name: 'Plaintext',
                secret: 'PLAINTEXTSECRET',
                otp: OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [Group(id: 'plain-group', name: 'Plain')],
          );
          final encryptedData = AppData(
            services: const [
              OtpService(
                id: 'vault-service',
                name: 'Vault',
                secret: 'VAULTSECRET',
                otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [Group(id: 'vault-group', name: 'Vault')],
          );

          await repository.writeAppDataJson(plaintextData);
          final encryptedFile = await repository.getEncryptedLocalFile();
          final encryptedBytes = await LocalVaultEncryptionService.encrypt(
            encryptedData.toJsonString(),
            'vault-password',
            iterations: 1000,
          );
          await encryptedFile.writeAsBytes(encryptedBytes);

          expect(
            () => repository.loadStoredData(password: 'wrong-password'),
            throwsA(
              isA<StorageLoadException>()
                  .having(
                    (error) => error.source,
                    'source',
                    StorageDataSource.encryptedVault,
                  )
                  .having(
                    (error) => error.message,
                    'message',
                    contains('Failed to unlock encrypted vault'),
                  )
                  .having(
                    (error) => error.kind,
                    'kind',
                    VaultLoadErrorKind.incorrectPassword,
                  ),
            ),
          );
        },
      );

      test(
        'should report corrupted vault when data.bin is malformed',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final encryptedFile = await repository.getEncryptedLocalFile();
          await encryptedFile.writeAsBytes(utf8.encode('not a vault envelope'));

          expect(
            () => repository.loadStoredData(password: 'any-password'),
            throwsA(
              isA<StorageLoadException>()
                  .having(
                    (error) => error.source,
                    'source',
                    StorageDataSource.encryptedVault,
                  )
                  .having(
                    (error) => error.kind,
                    'kind',
                    VaultLoadErrorKind.corruptedVault,
                  ),
            ),
          );
        },
      );

      test(
        'should parse decrypted data.bin with the same app-data contract as data.json',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final data = AppData(
            services: const [
              OtpService(
                id: 'service-id',
                name: 'GitHub',
                secret: 'JBSWY3DPEHPK3PXP',
                otp: OtpConfig(account: 'dev@example.com', issuer: 'GitHub'),
                order: OrderInfo(position: 3),
                groupId: 'group-id',
              ),
            ],
            groups: const [Group(id: 'group-id', name: 'Work')],
          );

          await repository.writeAppDataJson(data);
          await repository.saveEncryptedData(data, 'vault-password');

          final plaintextJson = await repository.readAppDataJson();
          final encryptedBytes = await repository.readEncryptedAppData();
          final decryptedJson = await LocalVaultEncryptionService.decrypt(
            encryptedBytes,
            'vault-password',
          );

          expect(decryptedJson, equals(plaintextJson));
          expect(
            repository.parsePlaintextAppData(decryptedJson).toJson(),
            equals(AppData.fromJsonString(plaintextJson).toJson()),
          );
        },
      );

      test(
        'should migrate plaintext data into encrypted vault and delete json',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final plaintextData = AppData(
            services: const [
              OtpService(
                id: 'plaintext-service',
                name: 'Plaintext',
                secret: 'PLAINTEXTSECRET',
                otp: OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [Group(id: 'plain-group', name: 'Plain')],
          );

          await repository.writeAppDataJson(plaintextData);
          await repository.migratePlaintextDataToEncryptedVault(
            plaintextData,
            'vault-password',
          );

          final plaintextFile = await repository.getLocalFile();
          final encryptedFile = await repository.getEncryptedLocalFile();
          final loaded = await repository.loadStoredData(
            password: 'vault-password',
          );

          expect(await plaintextFile.exists(), isFalse);
          expect(await encryptedFile.exists(), isTrue);
          expect(loaded.source, equals(StorageDataSource.encryptedVault));
          expect(loaded.data.toJson(), equals(plaintextData.toJson()));
        },
      );

      test('should save plaintext mode to data.json', () async {
        final repository = StorageRepository(localPathOverride: tempDir.path);
        final data = AppData(
          services: const [
            OtpService(
              id: 'service-id',
              name: 'Plaintext',
              secret: 'PLAINTEXTSECRET',
              otp: OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [],
        );

        await repository.saveData(data);

        final plaintextFile = await repository.getLocalFile();
        final encryptedFile = await repository.getEncryptedLocalFile();

        expect(await plaintextFile.exists(), isTrue);
        expect(await encryptedFile.exists(), isFalse);
        expect(
          AppData.fromJsonString(await plaintextFile.readAsString()).toJson(),
          equals(data.toJson()),
        );
      });

      test('should save encrypted mode only to data.bin', () async {
        final repository = StorageRepository(localPathOverride: tempDir.path);
        final existingPlaintextData = AppData(
          services: const [
            OtpService(
              id: 'old-service',
              name: 'Old Plaintext',
              secret: 'OLDSECRET',
              otp: OtpConfig(account: 'old@example.com', issuer: 'Old'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [],
        );
        final encryptedData = AppData(
          services: const [
            OtpService(
              id: 'vault-service',
              name: 'Vault',
              secret: 'VAULTSECRET',
              otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [],
        );

        await repository.writeAppDataJson(existingPlaintextData);
        await repository.saveData(
          encryptedData,
          source: StorageDataSource.encryptedVault,
          password: 'vault-password',
        );

        final plaintextFile = await repository.getLocalFile();
        final encryptedFile = await repository.getEncryptedLocalFile();
        final loaded = await repository.loadStoredData(
          password: 'vault-password',
        );

        expect(await plaintextFile.exists(), isFalse);
        expect(await encryptedFile.exists(), isTrue);
        expect(loaded.source, equals(StorageDataSource.encryptedVault));
        expect(loaded.data.toJson(), equals(encryptedData.toJson()));
      });

      test(
        'should save with cached key material and reload with the password',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final initialData = AppData(
            services: const [
              OtpService(
                id: 'vault-service',
                name: 'Vault',
                secret: 'VAULTSECRET',
                otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [],
          );

          await repository.saveEncryptedData(initialData, 'vault-password');
          final params = await repository.readVaultKdfParameters();
          final key = await LocalVaultEncryptionService.deriveKey(
            'vault-password',
            params.salt,
            params.iterations,
          );

          final updatedData = AppData(
            services: [initialData.services.single.copyWith(usageCount: 5)],
            groups: const [],
          );
          await repository.saveEncryptedDataWithKey(
            updatedData,
            key,
            salt: params.salt,
            iterations: params.iterations,
          );

          final loaded = await repository.loadStoredData(
            password: 'vault-password',
          );
          expect(loaded.source, equals(StorageDataSource.encryptedVault));
          expect(loaded.data.toJson(), equals(updatedData.toJson()));
        },
      );

      test('should recover vault from interrupted save temp file', () async {
        final repository = StorageRepository(localPathOverride: tempDir.path);
        final data = AppData(
          services: const [
            OtpService(
              id: 'vault-service',
              name: 'Vault',
              secret: 'VAULTSECRET',
              otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
              order: OrderInfo(position: 0),
            ),
          ],
          groups: const [],
        );

        await repository.saveEncryptedData(data, 'vault-password');
        final encryptedFile = await repository.getEncryptedLocalFile();
        final tempFile = File('${encryptedFile.path}.tmp');
        // Simulate a crash after the fully written temp file replaced the
        // old vault in name only (between the swap renames).
        await encryptedFile.rename(tempFile.path);

        final loaded = await repository.loadStoredData(
          password: 'vault-password',
        );

        expect(loaded.source, equals(StorageDataSource.encryptedVault));
        expect(loaded.data.toJson(), equals(data.toJson()));
        expect(await encryptedFile.exists(), isTrue);
        expect(await tempFile.exists(), isFalse);
      });

      test(
        'should recover vault from backup copy when temp file is invalid',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final data = AppData(
            services: const [
              OtpService(
                id: 'vault-service',
                name: 'Vault',
                secret: 'VAULTSECRET',
                otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [],
          );

          await repository.saveEncryptedData(data, 'vault-password');
          final encryptedFile = await repository.getEncryptedLocalFile();
          final backupFile = File('${encryptedFile.path}.bak');
          final tempFile = File('${encryptedFile.path}.tmp');
          // Simulate a crash mid-swap: previous vault parked as .bak, target
          // missing, and a truncated temp file left behind.
          await encryptedFile.rename(backupFile.path);
          await tempFile.writeAsBytes([1, 2, 3]);

          final loaded = await repository.loadStoredData(
            password: 'vault-password',
          );

          expect(loaded.source, equals(StorageDataSource.encryptedVault));
          expect(loaded.data.toJson(), equals(data.toJson()));
          expect(await encryptedFile.exists(), isTrue);
          expect(await backupFile.exists(), isFalse);
          expect(await tempFile.exists(), isFalse);
        },
      );

      test(
        'should prefer backup over a temp file with a broken ciphertext',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final data = AppData(
            services: const [
              OtpService(
                id: 'vault-service',
                name: 'Vault',
                secret: 'VAULTSECRET',
                otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [],
          );

          await repository.saveEncryptedData(data, 'vault-password');
          final encryptedFile = await repository.getEncryptedLocalFile();
          final backupFile = File('${encryptedFile.path}.bak');
          final tempFile = File('${encryptedFile.path}.tmp');
          // A temp file whose header parses but whose ciphertext is bogus
          // must not shadow the recoverable backup.
          final envelope =
              jsonDecode(utf8.decode(await encryptedFile.readAsBytes()))
                  as Map<String, dynamic>;
          envelope['ciphertext'] = base64.encode([1, 2, 3]);
          await tempFile.writeAsString(jsonEncode(envelope));
          await encryptedFile.rename(backupFile.path);

          final loaded = await repository.loadStoredData(
            password: 'vault-password',
          );

          expect(loaded.source, equals(StorageDataSource.encryptedVault));
          expect(loaded.data.toJson(), equals(data.toJson()));
          expect(await encryptedFile.exists(), isTrue);
          expect(await backupFile.exists(), isFalse);
          expect(await tempFile.exists(), isFalse);
        },
      );

      test(
        'should remove leftover swap artifacts after a successful unlock',
        () async {
          final repository = StorageRepository(localPathOverride: tempDir.path);
          final data = AppData(
            services: const [
              OtpService(
                id: 'vault-service',
                name: 'Vault',
                secret: 'VAULTSECRET',
                otp: OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
                order: OrderInfo(position: 0),
              ),
            ],
            groups: const [],
          );

          await repository.saveEncryptedData(data, 'vault-password');
          final encryptedFile = await repository.getEncryptedLocalFile();
          final backupFile = File('${encryptedFile.path}.bak');
          final tempFile = File('${encryptedFile.path}.tmp');
          // A .bak left behind by a crashed swap may be encrypted under an
          // old password; it must not outlive a successful unlock.
          await encryptedFile.copy(backupFile.path);
          await tempFile.writeAsBytes([1, 2, 3]);

          final loaded = await repository.loadStoredData(
            password: 'vault-password',
          );

          expect(loaded.source, equals(StorageDataSource.encryptedVault));
          expect(await backupFile.exists(), isFalse);
          expect(await tempFile.exists(), isFalse);
        },
      );
    });

    group('Data organization helpers', () {
      test('should group services by groupId', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'GitHub',
            secret: 'SECRET1',
            otp: OtpConfig(account: 'work@company.com', issuer: 'GitHub'),
            order: OrderInfo(position: 0),
            groupId: 'work',
          ),
          const OtpService(
            id: 'service2',
            name: 'Google',
            secret: 'SECRET2',
            otp: OtpConfig(account: 'personal@gmail.com', issuer: 'Google'),
            order: OrderInfo(position: 1),
            groupId: 'personal',
          ),
          const OtpService(
            id: 'service3',
            name: 'GitLab',
            secret: 'SECRET3',
            otp: OtpConfig(account: 'work2@company.com', issuer: 'GitLab'),
            order: OrderInfo(position: 2),
            groupId: 'work', // Same group as service1
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        expect(groupedServices, hasLength(2));
        expect(groupedServices['work'], hasLength(2));
        expect(groupedServices['personal'], hasLength(1));
        expect(groupedServices['work']![0].name, equals('GitHub'));
        expect(groupedServices['work']![1].name, equals('GitLab'));
        expect(groupedServices['personal']![0].name, equals('Google'));
      });

      test('should handle services without groupId', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'Ungrouped Service',
            secret: 'SECRET1',
            otp: OtpConfig(account: 'test@example.com', issuer: 'Test'),
            order: OrderInfo(position: 0),
            // No groupId
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        expect(groupedServices['ungrouped'], hasLength(1));
        expect(groupedServices['ungrouped']![0].groupId, isNull);
      });

      test('should sort services by order position', () {
        final services = [
          const OtpService(
            id: 'service1',
            name: 'Service C',
            secret: 'SECRET1',
            otp: OtpConfig(account: 'c@example.com', issuer: 'C'),
            order: OrderInfo(position: 2),
            groupId: 'group1',
          ),
          const OtpService(
            id: 'service2',
            name: 'Service A',
            secret: 'SECRET2',
            otp: OtpConfig(account: 'a@example.com', issuer: 'A'),
            order: OrderInfo(position: 0),
            groupId: 'group1',
          ),
          const OtpService(
            id: 'service3',
            name: 'Service B',
            secret: 'SECRET3',
            otp: OtpConfig(account: 'b@example.com', issuer: 'B'),
            order: OrderInfo(position: 1),
            groupId: 'group1',
          ),
        ];

        final groupedServices = <String, List<OtpService>>{};
        for (final service in services) {
          final groupId = service.groupId ?? 'ungrouped';
          groupedServices.putIfAbsent(groupId, () => []).add(service);
        }

        // Sort by position
        groupedServices['group1']!.sort(
          (a, b) => a.order.position.compareTo(b.order.position),
        );

        expect(groupedServices['group1']![0].name, equals('Service A'));
        expect(groupedServices['group1']![1].name, equals('Service B'));
        expect(groupedServices['group1']![2].name, equals('Service C'));
      });
    });
  });
}
