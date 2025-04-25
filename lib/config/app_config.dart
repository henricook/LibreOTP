class AppConfig {
  static const String appName = 'LibreOTP';
  static const String appVersion = 'v0.1';
  static const String appTitle = 'LibreOTP $appVersion';
  static const String githubUrl = 'https://github.com/henricook/libreotp';
  
  // OTP configuration
  static const int defaultOtpDigits = 6;
  static const int defaultOtpPeriod = 30;
  static const String defaultOtpAlgorithm = 'SHA1';
}