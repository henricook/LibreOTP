import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/otp_service.dart';
import '../models/group.dart';
import '../../services/twofas_decryption_service.dart';
import '../../services/secure_storage_service.dart';

class AppData {
  final List<OtpService> services;
  final List<Group> groups;

  AppData({required this.services, required this.groups});
}

class StorageRepository {
  static const String _dataFileName = 'data.json';

  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<File> getLocalFile() async {
    final path = await _localPath;
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    debugPrint('Application Data Directory: $path');
    return File('$path/$_dataFileName');
  }

  Future<AppData> loadData({String? password}) async {
    try {
      final file = await getLocalFile();
      if (await file.exists()) {
        String contents = await file.readAsString();
        Map<String, dynamic> jsonData = jsonDecode(contents);

        // Check if backup is encrypted
        if (TwoFasDecryptionService.isEncrypted(jsonData)) {
          // Try provided password first, then stored password
          String? effectivePassword = password ?? await SecureStorageService.getStoredPassword(contents);
          
          if (effectivePassword == null) {
            throw ArgumentError('Password required for encrypted backup');
          }
          
          // Decrypt the services
          final decryptedServices = await TwoFasDecryptionService.decryptBackup(jsonData, effectivePassword);
          final servicesData = jsonDecode(decryptedServices) as List;
          
          // If decryption succeeded and password was provided manually, store it securely
          if (password != null) {
            try {
              await SecureStorageService.storePassword(password, contents);
            } catch (e) {
              debugPrint('Warning: Failed to store password securely: $e');
              // Don't fail the whole operation if password storage fails
            }
          }
          
          // Parse decrypted services
          List<OtpService> services = servicesData
              .map((item) => OtpService.fromJson(item))
              .toList();

          // Parse groups (these are not encrypted in 2FAS format)
          List<Group> groups = (jsonData['groups'] as List? ?? [])
              .map((item) => Group.fromJson(item))
              .toList();

          return AppData(services: services, groups: groups);
        } else {
          // Handle unencrypted backup
          List<OtpService> services = (jsonData['services'] as List? ?? [])
              .map((item) => OtpService.fromJson(item))
              .toList();

          List<Group> groups = (jsonData['groups'] as List? ?? [])
              .map((item) => Group.fromJson(item))
              .toList();

          return AppData(services: services, groups: groups);
        }
      } else {
        debugPrint('Data file not found at: ${await getLocalFile()}');
        return AppData(services: [], groups: []);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      rethrow; // Re-throw to allow proper error handling upstream
    }
  }

  Future<void> saveData(AppData data) async {
    try {
      final file = await getLocalFile();
      Map<String, dynamic> jsonData = {
        'services': data.services.map((s) => s.toJson()).toList(),
        'groups': data.groups.map((g) => g.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(jsonData));
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
        allowedExtensions: ['json','2fas'],
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

  /// Imports a 2FAS backup file from the given path and copies it to app storage
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

      // Test loading the data first before copying
      AppData testData = await _parseBackupData(jsonData, contents, password);

      // If parsing succeeded, copy the file to app storage
      await _copyToAppStorage(sourceFile);
      
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
      final file = await getLocalFile();
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking existing data: $e');
      return false;
    }
  }

  bool _isValid2FasBackup(Map<String, dynamic> jsonData) {
    // Check for 2FAS backup structure
    return jsonData.containsKey('services') || 
           jsonData.containsKey('servicesEncrypted') ||
           (jsonData.containsKey('version') && jsonData.containsKey('schemaVersion'));
  }

  Future<AppData> _parseBackupData(Map<String, dynamic> jsonData, String contents, String? password) async {
    // Check if backup is encrypted
    if (TwoFasDecryptionService.isEncrypted(jsonData)) {
      if (password == null) {
        throw ArgumentError('Password required for encrypted backup');
      }
      
      // Decrypt the services
      final decryptedServices = await TwoFasDecryptionService.decryptBackup(jsonData, password);
      final servicesData = jsonDecode(decryptedServices) as List;
      
      // Parse decrypted services
      List<OtpService> services = servicesData
          .map((item) => OtpService.fromJson(item))
          .toList();

      // Parse groups (these are not encrypted in 2FAS format)
      List<Group> groups = (jsonData['groups'] as List? ?? [])
          .map((item) => Group.fromJson(item))
          .toList();

      return AppData(services: services, groups: groups);
    } else {
      // Handle unencrypted backup
      List<OtpService> services = (jsonData['services'] as List? ?? [])
          .map((item) => OtpService.fromJson(item))
          .toList();

      List<Group> groups = (jsonData['groups'] as List? ?? [])
          .map((item) => Group.fromJson(item))
          .toList();

      return AppData(services: services, groups: groups);
    }
  }

  Future<void> _copyToAppStorage(File sourceFile) async {
    final destinationFile = await getLocalFile();
    await sourceFile.copy(destinationFile.path);
    debugPrint('Copied backup to app storage: ${destinationFile.path}');
  }
}
