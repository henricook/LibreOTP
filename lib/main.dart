import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'data/repositories/storage_repository.dart';
import 'domain/services/otp_service.dart';
import 'presentation/state/otp_state.dart';
import 'presentation/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload app title to avoid repeated async calls in UI
  await AppConfig.getAppTitle();

  final storageRepository = StorageRepository();
  final otpGenerator = OtpGenerator();

  runApp(
    ChangeNotifierProvider(
      create: (_) => OtpState(storageRepository, otpGenerator),
      child: const LibreOTPApp(),
    ),
  );
}

class LibreOTPApp extends StatefulWidget {
  const LibreOTPApp({super.key});

  @override
  State<LibreOTPApp> createState() => _LibreOTPAppState();
}

class _LibreOTPAppState extends State<LibreOTPApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final themeMode = await AppConfig.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
  }

  void _updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    AppConfig.setThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: DashboardPage(onThemeChanged: _updateThemeMode),
    );
  }
}
