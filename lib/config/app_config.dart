import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String appName = 'LibreOTP';
  static const String githubUrl = 'https://github.com/henricook/libreotp';

  // Theme preference key
  static const String _themePreferenceKey = 'theme_mode';

  // Cached app title to avoid repeated async calls
  static String? _cachedAppTitle;

  // Dynamic version info - call getAppTitle() instead of using appTitle directly
  static Future<String> getAppTitle() async {
    if (_cachedAppTitle != null) {
      return _cachedAppTitle!;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final version = _formatVersion(packageInfo.version, packageInfo.buildNumber);
    _cachedAppTitle = 'LibreOTP $version';
    return _cachedAppTitle!;
  }

  // Synchronous access to cached title (returns fallback if not yet loaded)
  static String getAppTitleSync() {
    return _cachedAppTitle ?? appName;
  }
  
  static Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return _formatVersion(packageInfo.version, packageInfo.buildNumber);
  }
  
  static String _formatVersion(String version, String buildNumber) {
    // For local development (flutter run), show a dev indicator
    if (version.startsWith('0.0.0-snapshot')) {
      // CI-generated snapshot version - use as-is
      return 'v$version';
    } else if (buildNumber == '1' && !version.contains('-')) {
      // Local development build - add dev indicator
      return 'v$version-dev';
    } else {
      // Regular release version
      return 'v$version';
    }
  }

  // Theme configuration
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themePreferenceKey);

    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeModeString;

    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
        themeModeString = 'system';
        break;
    }

    await prefs.setString(_themePreferenceKey, themeModeString);
  }

  // OTP configuration
  static const int defaultOtpDigits = 6;
  static const int defaultOtpPeriod = 30;
  static const String defaultOtpAlgorithm = 'SHA1';
}
