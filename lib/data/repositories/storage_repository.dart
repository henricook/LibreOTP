import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/otp_service.dart';
import '../models/group.dart';

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

  Future<AppData> loadData() async {
    try {
      final file = await getLocalFile();
      if (await file.exists()) {
        String contents = await file.readAsString();
        Map<String, dynamic> jsonData = jsonDecode(contents);
        
        // Parse services
        List<OtpService> services = (jsonData['services'] as List? ?? [])
            .map((item) => OtpService.fromJson(item))
            .toList();
        
        // Parse groups
        List<Group> groups = (jsonData['groups'] as List? ?? [])
            .map((item) => Group.fromJson(item))
            .toList();
        
        return AppData(services: services, groups: groups);
      } else {
        // Handle the case where the file does not exist
        debugPrint('Data file not found at: ${await getLocalFile()}');
        return AppData(services: [], groups: []);
      }
    } catch (e) {
      // Handle errors
      debugPrint('Error loading data: $e');
      return AppData(services: [], groups: []);
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