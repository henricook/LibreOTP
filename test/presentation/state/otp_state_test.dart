import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libreotp/data/models/group.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';
import 'package:libreotp/domain/services/otp_service.dart';
import 'package:libreotp/config/app_config.dart';
import 'package:libreotp/config/display_mode.dart';
import 'package:libreotp/presentation/state/otp_display_state.dart';
import 'package:libreotp/presentation/state/otp_state.dart';
import 'package:libreotp/services/local_vault_encryption_service.dart';

// Mock classes
class MockStorageRepository extends StorageRepository {
  List<Group> _groups = [];
  List<OtpService> _services = [];
  Object? loadStoredDataException;
  Object? passwordLoadException;
  LoadedAppData? storedDataResult;
  LoadedAppData? passwordLoadResult;
  StorageDataSource? savedSource;
  String? encryptedSavePassword;
  AppData? savedData;
  VaultKdfParameters kdfParameters = VaultKdfParameters(
    salt: Uint8List(32),
    iterations: 1000,
  );
  late File _testFile;

  MockStorageRepository() {
    final tempDir = Directory.systemTemp;
    _testFile = File('${tempDir.path}/test_data.json');
    _testFile.writeAsStringSync('{"groups":[],"services":[]}');
  }

  @override
  Future<VaultKdfParameters> readVaultKdfParameters() async => kdfParameters;

  @override
  Future<LoadedAppData> loadStoredData({String? password}) async {
    if (password != null) {
      if (passwordLoadException != null) {
        throw passwordLoadException!;
      }
      if (passwordLoadResult != null) {
        return passwordLoadResult!;
      }
    }
    if (loadStoredDataException != null) {
      throw loadStoredDataException!;
    }
    return storedDataResult ??
        LoadedAppData(
          data: AppData(groups: _groups, services: _services),
          source: StorageDataSource.plaintextJson,
        );
  }

  @override
  Future<void> saveData(
    AppData data, {
    StorageDataSource source = StorageDataSource.plaintextJson,
    String? password,
    bool verify = false,
  }) async {
    savedData = data;
    savedSource = source;
    encryptedSavePassword = password;
  }

  @override
  Future<void> migratePlaintextDataToEncryptedVault(
    AppData data,
    String password,
  ) async {
    await saveData(
      data,
      source: StorageDataSource.encryptedVault,
      password: password,
    );
  }

  @override
  Future<File> getLocalFile() async => _testFile;

  @override
  Future<bool> hasExistingData() async => _testFile.existsSync();

  void setTestData(List<Group> groups, List<OtpService> services) {
    _groups = groups;
    _services = services;
    storedDataResult = LoadedAppData(
      data: AppData(groups: groups, services: services),
      source: StorageDataSource.plaintextJson,
    );
  }
}

class MockOtpGenerator extends OtpGenerator {
  String _nextCode = '123456';
  int _nextRemainingSeconds = 25;

  @override
  String generateOtp(OtpService service) => _nextCode;

  @override
  int getRemainingSeconds(OtpService service) => _nextRemainingSeconds;

  void setNextCode(String code) => _nextCode = code;
  void setNextRemainingSeconds(int seconds) => _nextRemainingSeconds = seconds;
}

void main() {
  group('OtpState', () {
    late MockStorageRepository mockRepository;
    late MockOtpGenerator mockGenerator;
    late OtpState otpState;
    bool disposed = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockStorageRepository();
      mockGenerator = MockOtpGenerator();
      disposed = false;
      otpState = OtpState(mockRepository, mockGenerator);
      await otpState.initializeData();
    });

    void disposeState() {
      if (!disposed) {
        otpState.dispose();
        disposed = true;
      }
    }

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 10));
      disposeState();
      await Future.delayed(const Duration(milliseconds: 10));
    });

    group('Initialization', () {
      test('should eventually finish loading', () {
        expect(otpState.isLoading, isFalse);
      });

      test('should create OtpState instance', () {
        expect(otpState, isA<OtpState>());
        expect(otpState.services, isA<List<OtpService>>());
        expect(otpState.groups, isA<List<Group>>());
      });
    });

    group('Search functionality', () {
      test('should have setSearchQuery method', () {
        expect(() => otpState.setSearchQuery('test'), returnsNormally);
      });

      test('should access groupedServices without error', () {
        expect(() => otpState.groupedServices, returnsNormally);
        expect(otpState.groupedServices, isA<Map<String, List<OtpService>>>());
      });

      test('should update service name and account details', () async {
        final testService = OtpService(
          id: 'service-1',
          name: 'Old Name',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'old@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
        );

        mockRepository.setTestData([], [testService]);
        await otpState.initializeData();

        final didUpdate = otpState.updateServiceDetails(
          serviceId: 'service-1',
          name: 'New Name',
          account: 'new@example.com',
        );

        expect(didUpdate, isTrue);
        expect(otpState.services.first.name, equals('New Name'));
        expect(otpState.services.first.otp.account, equals('new@example.com'));
      });
    });

    group('OTP generation', () {
      test('should return empty display state for non-existent service', () {
        final displayState = otpState.getOtpDisplayState('non-existent');
        expect(displayState, equals(OtpDisplayState.empty));
      });

      testWidgets('should handle generateOtp method calls', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        expect(
          () => otpState.generateOtp('invalid-group', 0, context),
          returnsNormally,
        );

        disposeState();
      });
    });

    group('Group names', () {
      test('should have getGroupNames method', () {
        expect(() => otpState.getGroupNames(), returnsNormally);
        expect(otpState.getGroupNames(), isA<Map<String, String>>());
      });
    });

    group('State notifications', () {
      test('should be a ChangeNotifier', () {
        expect(otpState, isA<ChangeNotifier>());
        expect(() => otpState.addListener(() {}), returnsNormally);
        expect(() => otpState.removeListener(() {}), returnsNormally);
      });
    });

    group('Local vault encryption', () {
      test(
        'should require local vault password when encrypted vault exists',
        () async {
          mockRepository.loadStoredDataException =
              const StoragePasswordRequiredException(
            StorageDataSource.encryptedVault,
            'Password required for encrypted vault',
          );

          await otpState.initializeData();

          expect(otpState.requiresPassword, isTrue);
          expect(otpState.requiresLocalVaultPassword, isTrue);
          expect(otpState.requiresBackupPassword, isFalse);
        },
      );

      test(
        'should require backup password for encrypted backup json',
        () async {
          mockRepository.loadStoredDataException =
              const StoragePasswordRequiredException(
            StorageDataSource.encryptedBackupJson,
            'Password required for encrypted backup',
          );

          await otpState.initializeData();

          expect(otpState.requiresPassword, isTrue);
          expect(otpState.requiresBackupPassword, isTrue);
          expect(otpState.requiresLocalVaultPassword, isFalse);
        },
      );

      test(
        'should surface unknown load errors without prompting for password',
        () async {
          mockRepository.loadStoredDataException = const StorageLoadException(
            StorageDataSource.none,
            'Error loading data: FormatException: Unexpected character',
          );

          await otpState.initializeData();

          expect(otpState.requiresPassword, isFalse);
          expect(otpState.requiresLocalVaultPassword, isFalse);
          expect(otpState.requiresBackupPassword, isFalse);
          expect(otpState.encryptionError, isNotNull);
        },
      );

      test(
        'should offer encryption migration after plaintext startup',
        () async {
          final service = OtpService(
            id: 'service-1',
            name: 'Plaintext',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.storedDataResult = LoadedAppData(
            data: AppData(groups: const [], services: [service]),
            source: StorageDataSource.plaintextJson,
          );

          await otpState.initializeData();

          expect(otpState.shouldPromptForEncryptionMigration, isTrue);
          expect(otpState.canEncryptLocalData, isTrue);
        },
      );

      test(
        'should not offer encryption migration once it has been dismissed',
        () async {
          SharedPreferences.setMockInitialValues({
            'encryption_migration_dismissed': true,
          });
          final service = OtpService(
            id: 'service-1',
            name: 'Plaintext',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.storedDataResult = LoadedAppData(
            data: AppData(groups: const [], services: [service]),
            source: StorageDataSource.plaintextJson,
          );

          await otpState.initializeData();

          expect(otpState.shouldPromptForEncryptionMigration, isFalse);
          expect(otpState.canEncryptLocalData, isTrue);
        },
      );

      test(
        'should not re-offer encryption migration after dismissal on relaunch',
        () async {
          final service = OtpService(
            id: 'service-1',
            name: 'Plaintext',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.storedDataResult = LoadedAppData(
            data: AppData(groups: const [], services: [service]),
            source: StorageDataSource.plaintextJson,
          );
          await otpState.initializeData();
          expect(otpState.shouldPromptForEncryptionMigration, isTrue);

          otpState.dismissEncryptionMigrationPrompt();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(await AppConfig.getEncryptionMigrationDismissed(), isTrue);

          final relaunched = OtpState(mockRepository, mockGenerator);
          await relaunched.initializeData();
          expect(relaunched.shouldPromptForEncryptionMigration, isFalse);
          relaunched.dispose();
        },
      );

      test('should migrate plaintext data to encrypted vault', () async {
        final service = OtpService(
          id: 'service-1',
          name: 'Plaintext',
          secret: 'SECRET',
          otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
          order: const OrderInfo(position: 0),
        );
        mockRepository.setTestData(const [], [service]);
        await otpState.initializeData();

        await otpState.migratePlaintextDataToEncryptedVault('vault-password');

        expect(otpState.usesEncryptedLocalStorage, isTrue);
        expect(otpState.shouldPromptForEncryptionMigration, isFalse);
        expect(
          mockRepository.savedSource,
          equals(StorageDataSource.encryptedVault),
        );
        expect(mockRepository.encryptedSavePassword, equals('vault-password'));
      });

      test(
        'should change local vault password when encrypted storage is active',
        () async {
          final service = OtpService(
            id: 'service-1',
            name: 'Vault',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.storedDataResult = LoadedAppData(
            data: AppData(groups: const [], services: [service]),
            source: StorageDataSource.encryptedVault,
          );
          await otpState.loadDataWithPassword('old-password');

          await otpState.changeLocalVaultPassword('new-password');

          expect(
            mockRepository.savedSource,
            equals(StorageDataSource.encryptedVault),
          );
          expect(mockRepository.encryptedSavePassword, equals('new-password'));
        },
      );

      test('should expose busy state while migrating plaintext data', () async {
        final service = OtpService(
          id: 'service-1',
          name: 'Plaintext',
          secret: 'SECRET',
          otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
          order: const OrderInfo(position: 0),
        );
        mockRepository.setTestData(const [], [service]);
        await otpState.initializeData();

        final future = otpState.migratePlaintextDataToEncryptedVault(
          'vault-password',
        );
        await Future<void>.delayed(Duration.zero);

        expect(otpState.isBusy, isTrue);
        expect(otpState.busyMessage, equals('Encrypting local data...'));

        await future;
        expect(otpState.isBusy, isFalse);
        expect(otpState.busyMessage, isNull);
      });

      test(
        'wrong vault password keeps prompt and sets incorrect password kind',
        () async {
          mockRepository.loadStoredDataException =
              const StoragePasswordRequiredException(
            StorageDataSource.encryptedVault,
            'Password required for encrypted vault',
          );
          mockRepository.passwordLoadException = const StorageLoadException(
            StorageDataSource.encryptedVault,
            'Failed to unlock encrypted vault',
            kind: VaultLoadErrorKind.incorrectPassword,
          );

          await otpState.initializeData();
          expect(otpState.requiresLocalVaultPassword, isTrue);

          await otpState.loadDataWithPassword('wrong-password');

          expect(otpState.requiresPassword, isTrue);
          expect(otpState.requiresLocalVaultPassword, isTrue);
          expect(
            otpState.encryptionErrorKind,
            equals(VaultLoadErrorKind.incorrectPassword),
          );
          expect(otpState.usesEncryptedLocalStorage, isFalse);
          expect(otpState.services, isEmpty);
        },
      );

      test(
        'successful vault unlock populates services and clears prompt',
        () async {
          final service = OtpService(
            id: 'service-1',
            name: 'Vault',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'vault@example.com', issuer: 'Vault'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.loadStoredDataException =
              const StoragePasswordRequiredException(
            StorageDataSource.encryptedVault,
            'Password required for encrypted vault',
          );
          mockRepository.passwordLoadResult = LoadedAppData(
            data: AppData(groups: const [], services: [service]),
            source: StorageDataSource.encryptedVault,
          );

          await otpState.initializeData();
          expect(otpState.requiresLocalVaultPassword, isTrue);

          await otpState.loadDataWithPassword('correct-password');

          expect(otpState.usesEncryptedLocalStorage, isTrue);
          expect(otpState.requiresPassword, isFalse);
          expect(otpState.encryptionErrorKind, isNull);
          expect(otpState.services.length, equals(1));
        },
      );

      test(
        'changeLocalVaultPassword throws when vault is not active',
        () async {
          final service = OtpService(
            id: 'service-1',
            name: 'Plaintext',
            secret: 'SECRET',
            otp: const OtpConfig(account: 'plain@example.com', issuer: 'Plain'),
            order: const OrderInfo(position: 0),
          );
          mockRepository.setTestData(const [], [service]);
          await otpState.initializeData();

          expect(otpState.usesEncryptedLocalStorage, isFalse);
          expect(
            () => otpState.changeLocalVaultPassword('new-password'),
            throwsA(isA<StateError>()),
          );
        },
      );
    });

    group('Display Mode', () {
      test('should default to grouped mode', () {
        expect(otpState.displayMode, equals(DisplayMode.grouped));
      });

      test('should switch to usage-based mode', () {
        otpState.setDisplayMode(DisplayMode.usageBased);
        expect(otpState.displayMode, equals(DisplayMode.usageBased));
      });

      test('should switch back to grouped mode', () {
        otpState.setDisplayMode(DisplayMode.usageBased);
        otpState.setDisplayMode(DisplayMode.grouped);
        expect(otpState.displayMode, equals(DisplayMode.grouped));
      });

      test('should organize services by groups in grouped mode', () async {
        final testGroup = Group(id: 'test-group', name: 'Test Group');
        final testService = OtpService(
          id: 'service-1',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          groupId: 'test-group',
        );

        mockRepository.setTestData([testGroup], [testService]);
        await otpState.initializeData();

        otpState.setDisplayMode(DisplayMode.grouped);
        final grouped = otpState.groupedServices;

        expect(grouped.containsKey('test-group'), isTrue);
        expect(grouped['test-group'], contains(testService));
      });

      test(
        'should show all services in "Most Used" group for usage-based mode',
        () async {
          final testService1 = OtpService(
            id: 'service-1',
            name: 'Service 1',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 0),
            usageCount: 5,
          );
          final testService2 = OtpService(
            id: 'service-2',
            name: 'Service 2',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 1),
            usageCount: 3,
          );

          mockRepository.setTestData([], [testService1, testService2]);
          await otpState.initializeData();

          otpState.setDisplayMode(DisplayMode.usageBased);
          final grouped = otpState.groupedServices;

          expect(grouped.keys.length, equals(1));
          expect(grouped.containsKey('Most Used'), isTrue);
          expect(grouped['Most Used']?.length, equals(2));
        },
      );
    });

    group('Usage Tracking', () {
      testWidgets('should increment usage count when generating OTP', (
        WidgetTester tester,
      ) async {
        final testService = OtpService(
          id: 'service-1',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 0,
        );

        await tester.runAsync(() async {
          mockRepository.setTestData([], [testService]);
          await otpState.initializeData();
        });

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        expect(otpState.services.first.usageCount, equals(0));

        otpState.setDisplayMode(DisplayMode.usageBased);
        otpState.generateOtp('Most Used', 0, context);
        await tester.pump();

        expect(otpState.services.first.usageCount, equals(1));

        disposeState();
      });

      testWidgets('should update lastUsedAt timestamp when generating OTP', (
        WidgetTester tester,
      ) async {
        final testService = OtpService(
          id: 'service-1',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          lastUsedAt: null,
        );

        await tester.runAsync(() async {
          mockRepository.setTestData([], [testService]);
          await otpState.initializeData();
        });

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        expect(otpState.services.first.lastUsedAt, isNull);

        otpState.setDisplayMode(DisplayMode.usageBased);
        final beforeTime = DateTime.now().toUtc();
        otpState.generateOtp('Most Used', 0, context);
        await tester.pump();
        final afterTime = DateTime.now().toUtc();

        final updatedService = otpState.services.first;
        expect(updatedService.lastUsedAt, isNotNull);
        expect(
          updatedService.lastUsedAt!.isAfter(
            beforeTime.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          updatedService.lastUsedAt!.isBefore(
            afterTime.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );

        disposeState();
      });

      testWidgets(
        'should not increment count on repeated clicks with same code',
        (WidgetTester tester) async {
          final testService = OtpService(
            id: 'service-1',
            name: 'Test Service',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 0),
            usageCount: 0,
          );

          await tester.runAsync(() async {
            mockRepository.setTestData([], [testService]);
            await otpState.initializeData();
          });

          await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: Container())),
          );
          final context = tester.element(find.byType(Container));

          otpState.setDisplayMode(DisplayMode.usageBased);

          // First click increments
          otpState.generateOtp('Most Used', 0, context);
          await tester.pump();
          expect(otpState.services.first.usageCount, equals(1));

          // Same code - should NOT increment
          otpState.generateOtp('Most Used', 0, context);
          await tester.pump();
          expect(otpState.services.first.usageCount, equals(1));

          // Same code again - still should NOT increment
          otpState.generateOtp('Most Used', 0, context);
          await tester.pump();
          expect(otpState.services.first.usageCount, equals(1));

          disposeState();
        },
      );

      testWidgets('should increment count when code changes between clicks', (
        WidgetTester tester,
      ) async {
        final testService = OtpService(
          id: 'service-1',
          name: 'Test Service',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 0,
        );

        await tester.runAsync(() async {
          mockRepository.setTestData([], [testService]);
          await otpState.initializeData();
        });

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        otpState.setDisplayMode(DisplayMode.usageBased);

        // First click increments
        mockGenerator.setNextCode('111111');
        otpState.generateOtp('Most Used', 0, context);
        await tester.pump();
        expect(otpState.services.first.usageCount, equals(1));

        // Different code - should increment
        mockGenerator.setNextCode('222222');
        otpState.generateOtp('Most Used', 0, context);
        await tester.pump();
        expect(otpState.services.first.usageCount, equals(2));

        // Different code again - should increment
        mockGenerator.setNextCode('333333');
        otpState.generateOtp('Most Used', 0, context);
        await tester.pump();
        expect(otpState.services.first.usageCount, equals(3));

        disposeState();
      });
    });

    group('Sort Order', () {
      test('should sort services by usage count descending', () async {
        final service1 = OtpService(
          id: 'service-1',
          name: 'Low Usage',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 2,
        );
        final service2 = OtpService(
          id: 'service-2',
          name: 'High Usage',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 1),
          usageCount: 10,
        );
        final service3 = OtpService(
          id: 'service-3',
          name: 'Medium Usage',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test3@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 2),
          usageCount: 5,
        );

        mockRepository.setTestData([], [service1, service2, service3]);
        await otpState.initializeData();

        otpState.setDisplayMode(DisplayMode.usageBased);
        final grouped = otpState.groupedServices;
        final sortedServices = grouped['Most Used']!;

        expect(sortedServices[0].id, equals('service-2')); // 10 uses
        expect(sortedServices[1].id, equals('service-3')); // 5 uses
        expect(sortedServices[2].id, equals('service-1')); // 2 uses
      });

      test(
        'should use timestamp as tie-breaker for equal usage counts',
        () async {
          final now = DateTime.now().toUtc();
          final service1 = OtpService(
            id: 'service-1',
            name: 'Older',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 0),
            usageCount: 5,
            lastUsedAt: now.subtract(const Duration(hours: 2)),
          );
          final service2 = OtpService(
            id: 'service-2',
            name: 'Newer',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 1),
            usageCount: 5,
            lastUsedAt: now.subtract(const Duration(minutes: 30)),
          );
          final service3 = OtpService(
            id: 'service-3',
            name: 'Newest',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test3@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 2),
            usageCount: 5,
            lastUsedAt: now.subtract(const Duration(minutes: 5)),
          );

          mockRepository.setTestData([], [service1, service2, service3]);
          await otpState.initializeData();

          otpState.setDisplayMode(DisplayMode.usageBased);
          final grouped = otpState.groupedServices;
          final sortedServices = grouped['Most Used']!;

          expect(sortedServices[0].id, equals('service-3')); // Most recent
          expect(sortedServices[1].id, equals('service-2')); // Middle
          expect(sortedServices[2].id, equals('service-1')); // Oldest
        },
      );

      test(
        'should place never-used items (null lastUsedAt) at bottom',
        () async {
          final now = DateTime.now().toUtc();
          final service1 = OtpService(
            id: 'service-1',
            name: 'Never Used 1',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 0),
            usageCount: 0,
            lastUsedAt: null,
          );
          final service2 = OtpService(
            id: 'service-2',
            name: 'Used Once',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 1),
            usageCount: 1,
            lastUsedAt: now,
          );
          final service3 = OtpService(
            id: 'service-3',
            name: 'Never Used 2',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'test3@example.com', issuer: 'Test'),
            order: const OrderInfo(position: 2),
            usageCount: 0,
            lastUsedAt: null,
          );

          mockRepository.setTestData([], [service1, service2, service3]);
          await otpState.initializeData();

          otpState.setDisplayMode(DisplayMode.usageBased);
          final grouped = otpState.groupedServices;
          final sortedServices = grouped['Most Used']!;

          expect(sortedServices[0].id, equals('service-2')); // Used once
          // Never-used items go to bottom (order among them is stable)
          expect(sortedServices[1].lastUsedAt, isNull);
          expect(sortedServices[2].lastUsedAt, isNull);
        },
      );
    });

    group('Cache Behavior', () {
      testWidgets('should prevent immediate re-sort after clicking item', (
        WidgetTester tester,
      ) async {
        final service1 = OtpService(
          id: 'service-1',
          name: 'Low Usage',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 2,
        );
        final service2 = OtpService(
          id: 'service-2',
          name: 'High Usage',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 1),
          usageCount: 10,
        );

        await tester.runAsync(() async {
          mockRepository.setTestData([], [service1, service2]);
          await otpState.initializeData();
        });

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        otpState.setDisplayMode(DisplayMode.usageBased);
        await tester.pump();

        final beforeClick = otpState.groupedServices['Most Used']!;
        expect(beforeClick[0].id, equals('service-2')); // High usage first
        expect(beforeClick[1].id, equals('service-1')); // Low usage second

        // Click the second item (low usage)
        otpState.generateOtp('Most Used', 1, context);
        await tester.pump();

        // Should still be in same position despite count increment
        final afterClick = otpState.groupedServices['Most Used']!;
        expect(afterClick[0].id, equals('service-2')); // Still first
        expect(afterClick[1].id, equals('service-1')); // Still second
        expect(
          afterClick[1].usageCount,
          equals(3),
        ); // Count updated (first click = new code)

        disposeState();
      });

      testWidgets('should re-sort after 60 seconds', (
        WidgetTester tester,
      ) async {
        final service1 = OtpService(
          id: 'service-1',
          name: 'Initially Low',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 2,
        );
        final service2 = OtpService(
          id: 'service-2',
          name: 'Initially High',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test2@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 1),
          usageCount: 5,
        );

        await tester.runAsync(() async {
          mockRepository.setTestData([], [service1, service2]);
          await otpState.initializeData();
        });

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
        final context = tester.element(find.byType(Container));

        otpState.setDisplayMode(DisplayMode.usageBased);
        await tester.pump();

        // Click service1 multiple times with different codes to make it higher usage
        for (int i = 0; i < 4; i++) {
          mockGenerator.setNextCode('code-$i');
          otpState.generateOtp('Most Used', 1, context);
          await tester.pump();
        }

        // Should still be in original position (cache active)
        var services = otpState.groupedServices['Most Used']!;
        expect(services[0].id, equals('service-2'));
        expect(services[1].id, equals('service-1'));
        expect(
          services[1].usageCount,
          equals(6),
        ); // 2 + 4 clicks (each with different code)

        // Advance time by 60 seconds to trigger resort
        await tester.pump(const Duration(seconds: 60));

        // Should now be re-sorted
        services = otpState.groupedServices['Most Used']!;
        expect(services[0].id, equals('service-1')); // Now first (6 uses)
        expect(services[1].id, equals('service-2')); // Now second (5 uses)

        disposeState();
      });

      test('should clear cache when search query changes', () async {
        final service1 = OtpService(
          id: 'service-1',
          name: 'Service 1',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 5,
        );

        mockRepository.setTestData([], [service1]);
        await otpState.initializeData();

        otpState.setDisplayMode(DisplayMode.usageBased);

        // Trigger cache by getting grouped services
        final _ = otpState.groupedServices;

        // Change search should clear cache
        expect(() => otpState.setSearchQuery('test'), returnsNormally);
        expect(() => otpState.groupedServices, returnsNormally);
      });

      test('should clear cache when display mode changes', () async {
        final service1 = OtpService(
          id: 'service-1',
          name: 'Service 1',
          secret: 'JBSWY3DPEHPK3PXP',
          otp: const OtpConfig(account: 'test1@example.com', issuer: 'Test'),
          order: const OrderInfo(position: 0),
          usageCount: 5,
        );

        mockRepository.setTestData([], [service1]);
        await otpState.initializeData();

        otpState.setDisplayMode(DisplayMode.usageBased);
        final _ = otpState.groupedServices;

        // Change mode should clear cache
        expect(
          () => otpState.setDisplayMode(DisplayMode.grouped),
          returnsNormally,
        );
        expect(() => otpState.groupedServices, returnsNormally);
      });
    });

    group('Integration Tests', () {
      testWidgets(
        'full usage-based flow: click, stay in place, resort after 60s',
        (WidgetTester tester) async {
          final service1 = OtpService(
            id: 'service-1',
            name: 'GitHub',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'user@example.com', issuer: 'GitHub'),
            order: const OrderInfo(position: 0),
            usageCount: 1,
          );
          final service2 = OtpService(
            id: 'service-2',
            name: 'Google',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'user@example.com', issuer: 'Google'),
            order: const OrderInfo(position: 1),
            usageCount: 5,
          );
          final service3 = OtpService(
            id: 'service-3',
            name: 'AWS',
            secret: 'JBSWY3DPEHPK3PXP',
            otp: const OtpConfig(account: 'user@example.com', issuer: 'AWS'),
            order: const OrderInfo(position: 2),
            usageCount: 3,
          );

          await tester.runAsync(() async {
            mockRepository.setTestData([], [service1, service2, service3]);
            await otpState.initializeData();
          });

          await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: Container())),
          );
          final context = tester.element(find.byType(Container));

          // Switch to usage-based mode
          otpState.setDisplayMode(DisplayMode.usageBased);
          await tester.pump();

          // Initial order: Google (5), AWS (3), GitHub (1)
          var services = otpState.groupedServices['Most Used']!;
          expect(services[0].name, equals('Google'));
          expect(services[1].name, equals('AWS'));
          expect(services[2].name, equals('GitHub'));

          // Click GitHub (at position 2) to increase its usage
          mockGenerator.setNextCode('code-1');
          otpState.generateOtp('Most Used', 2, context);
          await tester.pump();

          // Should stay at position 2 (cache active)
          services = otpState.groupedServices['Most Used']!;
          expect(services[0].name, equals('Google'));
          expect(services[1].name, equals('AWS'));
          expect(services[2].name, equals('GitHub')); // Still here
          expect(services[2].usageCount, equals(2)); // Count updated

          // Click it again with a different code (new TOTP period)
          mockGenerator.setNextCode('code-2');
          otpState.generateOtp('Most Used', 2, context);
          await tester.pump();
          expect(
            otpState.groupedServices['Most Used']![2].usageCount,
            equals(3),
          ); // Now tied with AWS

          // Still at position 2 (cache still active)
          services = otpState.groupedServices['Most Used']!;
          expect(services[2].name, equals('GitHub'));

          // Advance time by 60 seconds
          await tester.pump(const Duration(seconds: 60));

          // Should now be re-sorted by count and timestamp
          services = otpState.groupedServices['Most Used']!;
          expect(services[0].name, equals('Google')); // Still highest (5)
          // GitHub and AWS both have 3, but GitHub was used more recently
          expect(
            services[1].name,
            equals('GitHub'),
          ); // Moved up due to recent use
          expect(services[2].name, equals('AWS'));

          disposeState();
        },
      );
    });
  });
}
