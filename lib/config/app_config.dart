import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'display_mode.dart';

class AppConfig {
  static const String appName = 'LibreOTP';
  static const String githubUrl = 'https://github.com/henricook/libreotp';

  // Preference keys
  static const String _themePreferenceKey = 'theme_mode';
  static const String _displayModePreferenceKey = 'display_mode';
  static const String _windowXKey = 'window_x';
  static const String _windowYKey = 'window_y';
  static const String _windowWidthKey = 'window_width';
  static const String _windowHeightKey = 'window_height';
  static const String _windowMaximizedKey = 'window_maximized';

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

  // Display mode configuration
  static Future<DisplayMode> getDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_displayModePreferenceKey);
    try {
      return DisplayMode.values.byName(name ?? 'grouped');
    } catch (_) {
      return DisplayMode.grouped;
    }
  }

  static Future<void> setDisplayMode(DisplayMode displayMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModePreferenceKey, displayMode.name);
  }

  // Window bounds persistence
  static Future<Rect?> getWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_windowXKey);
    final y = prefs.getDouble(_windowYKey);
    final width = prefs.getDouble(_windowWidthKey);
    final height = prefs.getDouble(_windowHeightKey);
    if (x != null && y != null && width != null && height != null) {
      return Rect.fromLTWH(x, y, width, height);
    }
    return null;
  }

  static Future<void> setWindowBounds(Rect bounds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowXKey, bounds.left);
    await prefs.setDouble(_windowYKey, bounds.top);
    await prefs.setDouble(_windowWidthKey, bounds.width);
    await prefs.setDouble(_windowHeightKey, bounds.height);
  }

  static Future<bool> getWindowMaximized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_windowMaximizedKey) ?? false;
  }

  static Future<void> setWindowMaximized(bool maximized) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_windowMaximizedKey, maximized);
  }

  // OTP configuration
  static const int defaultOtpDigits = 6;
  static const int defaultOtpPeriod = 30;
  static const String defaultOtpAlgorithm = 'SHA1';
}
