import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static const String appName = 'LibreOTP';
  static const String githubUrl = 'https://github.com/henricook/libreotp';
  
  // Dynamic version info - call getAppTitle() instead of using appTitle directly
  static Future<String> getAppTitle() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = _formatVersion(packageInfo.version, packageInfo.buildNumber);
    return 'LibreOTP $version';
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

  // OTP configuration
  static const int defaultOtpDigits = 6;
  static const int defaultOtpPeriod = 30;
  static const String defaultOtpAlgorithm = 'SHA1';
}
