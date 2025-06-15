import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'data/repositories/storage_repository.dart';
import 'domain/services/otp_service.dart';
import 'presentation/state/otp_state.dart';
import 'presentation/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageRepository = StorageRepository();
  final otpGenerator = OtpGenerator();

  runApp(
    ChangeNotifierProvider(
      create: (_) => OtpState(storageRepository, otpGenerator),
      child: const LibreOTPApp(),
    ),
  );
}

class LibreOTPApp extends StatelessWidget {
  const LibreOTPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}
