import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:libreotp/data/models/group.dart';
import 'package:libreotp/data/models/otp_service.dart';
import 'package:libreotp/data/repositories/storage_repository.dart';

// Test version of the repository that uses a temp directory
// and completely overrides file operations to avoid path_provider dependency
class TestStorageRepository extends StorageRepository {
  final Directory tempDir;
  final File _testFile;
  
  TestStorageRepository(this.tempDir) : 
    _testFile = File('${tempDir.path}/data.json');
  
  @override
  Future<String> get _localPath async {
    return tempDir.path;
  }
  
  @override
  Future<File> getLocalFile() async {
    final directory = tempDir;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return _testFile;
  }
}

void main() {
  // Initialize Flutter binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StorageRepository', () {
    late TestStorageRepository repository;
    late Directory tempDir;
    
    setUp(() async {
      // Create a real temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('storage_test_');
      
      // Use our test repository that overrides the path
      repository = TestStorageRepository(tempDir);
    });
    
    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('loadData returns empty lists when file does not exist', () async {
      // Test the behavior when file doesn't exist
      // We don't create any test file, so it should return empty data
      
      final appData = await repository.loadData();
      
      expect(appData.services, isEmpty);
      expect(appData.groups, isEmpty);
    });
    
    test('saveData writes data to file and loadData reads it back', () async {
      // Create test data
      final testService = OtpService(
        id: 'test-id',
        name: 'Test Service',
        groupId: 'group1',
        secret: 'TESTSECRET',
        otp: OtpConfig(
          account: 'test@example.com',
          issuer: 'Test',
          digits: 6,
          period: 30,
          algorithm: 'SHA1',
        ),
        order: OrderInfo(position: 0),
      );
      
      final testGroup = Group(
        id: 'group1',
        name: 'Test Group',
      );
      
      // Save data using the repository
      final appData = AppData(
        services: [testService],
        groups: [testGroup],
      );
      
      await repository.saveData(appData);
      
      // Now read it back
      final loadedData = await repository.loadData();
      
      // Verify the loaded data matches what we saved
      expect(loadedData.services.length, 1);
      expect(loadedData.services[0].id, 'test-id');
      expect(loadedData.services[0].name, 'Test Service');
      expect(loadedData.groups.length, 1);
      expect(loadedData.groups[0].id, 'group1');
      expect(loadedData.groups[0].name, 'Test Group');
    });
    
    test('getLocalFile returns path in the temp directory', () async {
      // Get file path
      final file = await repository.getLocalFile();
      
      // Verify path is in the temp directory
      expect(file.path, startsWith(tempDir.path));
      expect(file.path, endsWith('data.json'));
    });
  });
}