import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/otp_service.dart';
import '../models/group.dart';
import '../../services/local_vault_encryption_service.dart';
import '../../services/twofas_decryption_service.dart';
import '../../services/secure_storage_service.dart';

class AppData {
  final List<OtpService> services;
  final List<Group> groups;

  AppData({required this.services, required this.groups});

  Map<String, dynamic> toJson() {
    return {
      'services': services.map((service) => service.toJson()).toList(),
      'groups': groups.map((group) => group.toJson()).toList(),
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory AppData.fromJson(Map<String, dynamic> jsonData) {
    final services = (jsonData['services'] as List? ?? [])
        .map((item) => OtpService.fromJson(item))
        .toList();
    final groups = (jsonData['groups'] as List? ?? [])
        .map((item) => Group.fromJson(item))
        .toList();
    return AppData(services: services, groups: groups);
  }

  factory AppData.fromJsonString(String jsonString) {
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppData.fromJson(jsonData);
  }
}

enum StorageDataSource {
  none,
  plaintextJson,
  encryptedVault,
  encryptedBackupJson,
}

class LoadedAppData {
  final AppData data;
  final StorageDataSource source;

  const LoadedAppData({required this.data, required this.source});
}

class StoragePasswordRequiredException implements Exception {
  final StorageDataSource source;
  final String message;

  const StoragePasswordRequiredException(this.source, this.message);

  @override
  String toString() => message;
}

enum VaultLoadErrorKind { incorrectPassword, corruptedVault, unknown }

class StorageLoadException implements Exception {
  final StorageDataSource source;
  final String message;
  final VaultLoadErrorKind kind;

  const StorageLoadException(
    this.source,
    this.message, {
    this.kind = VaultLoadErrorKind.unknown,
  });

  @override
  String toString() => message;
}

class StorageRepository {
  static const String _dataFileName = 'data.json';
  static const String _encryptedDataFileName = 'data.bin';
  final String? _localPathOverride;

  StorageRepository({String? localPathOverride})
      : _localPathOverride = localPathOverride;

  Future<String> get _localPath async {
    if (_localPathOverride != null) {
      return _localPathOverride;
    }
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<Directory> _getLocalDirectory() async {
    final path = await _localPath;
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    debugPrint('Application Data Directory: $path');
    return directory;
  }

  Future<File> getLocalFile() async {
    final directory = await _getLocalDirectory();
    return File('${directory.path}/$_dataFileName');
  }

  Future<File> getEncryptedLocalFile() async {
    final directory = await _getLocalDirectory();
    return File('${directory.path}/$_encryptedDataFileName');
  }

  Future<String> readAppDataJson() async {
    final file = await getLocalFile();
    return file.readAsString();
  }

  Future<Uint8List> readEncryptedAppData() async {
    final file = await getEncryptedLocalFile();
    return file.readAsBytes();
  }

  Future<VaultKdfParameters> readVaultKdfParameters() async {
    final contents = await readEncryptedAppData();
    return LocalVaultEncryptionService.readKdfParameters(contents);
  }

  Future<void> writeAppDataJson(AppData data) async {
    final file = await getLocalFile();
    await file.writeAsString(data.toJsonString());
  }

  Future<void> saveEncryptedData(
    AppData data,
    String password, {
    bool verify = false,
  }) async {
    final encryptedFile = await getEncryptedLocalFile();
    final tempFile = File('${encryptedFile.path}.tmp');
    final plaintextJson = serializePlaintextAppData(data);

    try {
      final encryptedBytes = await LocalVaultEncryptionService.encrypt(
        plaintextJson,
        password,
      );
      await tempFile.writeAsBytes(encryptedBytes, flush: true);

      if (verify) {
        final verifiedJson = await LocalVaultEncryptionService.decrypt(
          await tempFile.readAsBytes(),
          password,
        );
        if (verifiedJson != plaintextJson) {
          throw const FileSystemException(
            'Encrypted vault verification failed after write',
          );
        }
      }

      await _replaceEncryptedFile(tempFile, encryptedFile);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> saveEncryptedDataWithKey(
    AppData data,
    Uint8List key, {
    required Uint8List salt,
    required int iterations,
  }) async {
    final encryptedFile = await getEncryptedLocalFile();
    final tempFile = File('${encryptedFile.path}.tmp');
    final plaintextJson = serializePlaintextAppData(data);

    try {
      final encryptedBytes = await LocalVaultEncryptionService.encryptWithKey(
        plaintextJson,
        key,
        salt: salt,
        iterations: iterations,
      );
      await tempFile.writeAsBytes(encryptedBytes, flush: true);

      await _replaceEncryptedFile(tempFile, encryptedFile);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Atomically replaces [encryptedFile] with [tempFile], keeping the previous
  /// vault as a .bak until the swap completes so an interrupted save can never
  /// leave the vault missing. Rolls the backup straight back if the final
  /// rename fails.
  Future<void> _replaceEncryptedFile(File tempFile, File encryptedFile) async {
    final backupFile = File('${encryptedFile.path}.bak');
    var movedToBackup = false;

    if (await encryptedFile.exists()) {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await encryptedFile.rename(backupFile.path);
      movedToBackup = true;
    }

    try {
      await tempFile.rename(encryptedFile.path);
    } catch (_) {
      if (movedToBackup && !await encryptedFile.exists()) {
        await backupFile.rename(encryptedFile.path);
      }
      rethrow;
    }

    if (movedToBackup && await backupFile.exists()) {
      await backupFile.delete();
    }
  }

  /// Restores the vault from the leftover .tmp or .bak file if a previous
  /// save was interrupted between the swap renames.
  Future<void> _recoverEncryptedDataIfNeeded() async {
    final encryptedFile = await getEncryptedLocalFile();
    if (await encryptedFile.exists()) {
      return;
    }

    final tempFile = File('${encryptedFile.path}.tmp');
    final backupFile = File('${encryptedFile.path}.bak');

    if (await tempFile.exists()) {
      try {
        LocalVaultEncryptionService.validateEnvelope(
          await tempFile.readAsBytes(),
        );
        await tempFile.rename(encryptedFile.path);
        debugPrint('Recovered encrypted vault from interrupted save');
      } catch (e) {
        debugPrint('Discarding invalid vault temp file: $e');
        await tempFile.delete();
      }
    }

    if (!await encryptedFile.exists() && await backupFile.exists()) {
      await backupFile.rename(encryptedFile.path);
      debugPrint('Recovered encrypted vault from backup copy');
    }
  }

  /// Removes leftover swap artifacts once the current vault has proven
  /// loadable. A .bak may hold the vault under a previous password, so it
  /// must not outlive a successful unlock.
  Future<void> _cleanupVaultArtifactsAfterUnlock() async {
    try {
      final encryptedFile = await getEncryptedLocalFile();
      for (final suffix in ['.tmp', '.bak']) {
        final artifact = File('${encryptedFile.path}$suffix');
        if (await artifact.exists()) {
          await artifact.delete();
        }
      }
    } catch (e) {
      debugPrint('Could not clean up vault artifacts: $e');
    }
  }

  Future<void> deletePlaintextData() async {
    final file = await getLocalFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> migratePlaintextDataToEncryptedVault(
    AppData data,
    String password,
  ) async {
    await saveEncryptedData(data, password, verify: true);
    await deletePlaintextData();
  }

  Future<bool> hasPlaintextData() async {
    final file = await getLocalFile();
    return file.exists();
  }

  Future<bool> hasEncryptedData() async {
    final file = await getEncryptedLocalFile();
    return file.exists();
  }

  Future<bool> hasAnyLocalData() async {
    final results = await Future.wait([hasEncryptedData(), hasPlaintextData()]);
    return results.any((exists) => exists);
  }

  AppData parsePlaintextAppData(String jsonString) {
    return AppData.fromJsonString(jsonString);
  }

  String serializePlaintextAppData(AppData data) {
    return data.toJsonString();
  }

  bool isEncryptedLocalSource(StorageDataSource source) {
    return source == StorageDataSource.encryptedVault;
  }

  Map<String, dynamic> decodeJsonObject(String jsonString) {
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Future<LoadedAppData> loadStoredData({String? password}) async {
    try {
      await _recoverEncryptedDataIfNeeded();
      if (await hasEncryptedData()) {
        return await _loadEncryptedVaultData(password: password);
      }
      if (await hasPlaintextData()) {
        return await _loadPlaintextJsonData(password: password);
      }
      return LoadedAppData(
        data: AppData(services: [], groups: []),
        source: StorageDataSource.none,
      );
    } on StoragePasswordRequiredException {
      rethrow;
    } on StorageLoadException {
      rethrow;
    } catch (e) {
      throw StorageLoadException(
        StorageDataSource.none,
        'Error loading data: $e',
      );
    }
  }

  Future<void> saveData(
    AppData data, {
    StorageDataSource source = StorageDataSource.plaintextJson,
    String? password,
    bool verify = false,
  }) async {
    try {
      if (isEncryptedLocalSource(source)) {
        if (password == null || password.isEmpty) {
          throw ArgumentError('Password required for encrypted vault');
        }
        await saveEncryptedData(data, password, verify: verify);
        await deletePlaintextData();
        return;
      }

      await writeAppDataJson(data);
    } catch (e) {
      debugPrint('Error saving data: $e');
      rethrow;
    }
  }

  /// Opens a file picker dialog for the user to select a 2FAS backup file
  Future<String?> pickBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', '2fas'],
        dialogTitle: 'Select 2FAS backup file',
      );

      if (result != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking backup file: $e');
      rethrow;
    }
  }

  /// Imports a 2FAS backup file from the given path and parses its data.
  Future<AppData> importBackupFile(String filePath, {String? password}) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw ArgumentError('Selected file does not exist');
      }

      // Read and validate the source file
      String contents = await sourceFile.readAsString();
      Map<String, dynamic> jsonData = jsonDecode(contents);

      // Validate it's a 2FAS backup file by checking for expected structure
      if (!_isValid2FasBackup(jsonData)) {
        throw ArgumentError('Selected file is not a valid 2FAS backup');
      }

      // Parse the backup data for merging into local storage
      AppData testData = await _parseBackupData(jsonData, password);

      debugPrint('Successfully imported backup from: $filePath');
      return testData;
    } catch (e) {
      debugPrint('Error importing backup file: $e');
      rethrow;
    }
  }

  /// Checks if the current app storage has a data file
  Future<bool> hasExistingData() async {
    try {
      return await hasAnyLocalData();
    } catch (e) {
      debugPrint('Error checking existing data: $e');
      return false;
    }
  }

  Future<LoadedAppData> _loadEncryptedVaultData({String? password}) async {
    if (password == null || password.isEmpty) {
      throw const StoragePasswordRequiredException(
        StorageDataSource.encryptedVault,
        'Password required for encrypted vault',
      );
    }

    try {
      final contents = await readEncryptedAppData();
      final decryptedJson = await LocalVaultEncryptionService.decrypt(
        contents,
        password,
      );
      await _cleanupVaultArtifactsAfterUnlock();
      return LoadedAppData(
        data: parsePlaintextAppData(decryptedJson),
        source: StorageDataSource.encryptedVault,
      );
    } catch (e) {
      final VaultLoadErrorKind kind;
      if (e is ArgumentError) {
        kind = VaultLoadErrorKind.incorrectPassword;
      } else if (e is FormatException || e is UnsupportedError) {
        kind = VaultLoadErrorKind.corruptedVault;
      } else {
        kind = VaultLoadErrorKind.unknown;
      }
      throw StorageLoadException(
        StorageDataSource.encryptedVault,
        'Failed to unlock encrypted vault: $e',
        kind: kind,
      );
    }
  }

  Future<LoadedAppData> _loadPlaintextJsonData({String? password}) async {
    final contents = await readAppDataJson();
    final jsonData = decodeJsonObject(contents);

    if (!TwoFasDecryptionService.isEncrypted(jsonData)) {
      return LoadedAppData(
        data: parsePlaintextAppData(contents),
        source: StorageDataSource.plaintextJson,
      );
    }

    final effectivePassword =
        password ?? await SecureStorageService.getStoredPassword(contents);
    if (effectivePassword == null || effectivePassword.isEmpty) {
      throw const StoragePasswordRequiredException(
        StorageDataSource.encryptedBackupJson,
        'Password required for encrypted backup',
      );
    }

    try {
      final decryptedServices = await TwoFasDecryptionService.decryptBackup(
        jsonData,
        effectivePassword,
      );
      final servicesData = jsonDecode(decryptedServices) as List;

      if (password != null) {
        try {
          await SecureStorageService.storePassword(password, contents);
        } catch (e) {
          debugPrint('Warning: Failed to store password securely: $e');
        }
      }

      final services =
          servicesData.map((item) => OtpService.fromJson(item)).toList();
      final groups = (jsonData['groups'] as List? ?? [])
          .map((item) => Group.fromJson(item))
          .toList();

      return LoadedAppData(
        data: AppData(services: services, groups: groups),
        source: StorageDataSource.encryptedBackupJson,
      );
    } catch (e) {
      throw StorageLoadException(
        StorageDataSource.encryptedBackupJson,
        'Failed to decrypt backup: $e',
      );
    }
  }

  bool _isValid2FasBackup(Map<String, dynamic> jsonData) {
    // Check for 2FAS backup structure
    return jsonData.containsKey('services') ||
        jsonData.containsKey('servicesEncrypted') ||
        (jsonData.containsKey('version') &&
            jsonData.containsKey('schemaVersion'));
  }

  Future<AppData> _parseBackupData(
    Map<String, dynamic> jsonData,
    String? password,
  ) async {
    // Check if backup is encrypted
    if (TwoFasDecryptionService.isEncrypted(jsonData)) {
      if (password == null) {
        throw const StoragePasswordRequiredException(
          StorageDataSource.encryptedBackupJson,
          'Password required for encrypted backup',
        );
      }

      // Decrypt the services
      final decryptedServices = await TwoFasDecryptionService.decryptBackup(
        jsonData,
        password,
      );
      final servicesData = jsonDecode(decryptedServices) as List;

      // Parse decrypted services
      List<OtpService> services =
          servicesData.map((item) => OtpService.fromJson(item)).toList();

      // Parse groups (these are not encrypted in 2FAS format)
      List<Group> groups = (jsonData['groups'] as List? ?? [])
          .map((item) => Group.fromJson(item))
          .toList();

      return AppData(services: services, groups: groups);
    } else {
      return AppData.fromJson(jsonData);
    }
  }
}
