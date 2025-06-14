import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  static const String _folderName = 'LibreOTP';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_folderName';
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
}
