import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'config/app_config.dart';
import 'data/repositories/storage_repository.dart';
import 'domain/services/otp_service.dart';
import 'presentation/state/otp_state.dart';
import 'presentation/pages/dashboard_page.dart';

Future<bool> _isBoundsOnScreen(Rect bounds) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final pos = display.visiblePosition;
      final size = display.visibleSize;
      if (pos == null || size == null) continue;
      final displayRect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        size.width,
        size.height,
      );
      if (bounds.overlaps(displayRect)) {
        return true;
      }
    }
  } catch (_) {
    return true;
  }
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  final savedBounds = await AppConfig.getWindowBounds();
  final wasMaximized = await AppConfig.getWindowMaximized();

  final boundsOnScreen =
      savedBounds != null ? await _isBoundsOnScreen(savedBounds) : false;

  final windowOptions = WindowOptions(
    size: (savedBounds != null && boundsOnScreen)
        ? Size(savedBounds.width, savedBounds.height)
        : const Size(900, 700),
    minimumSize: const Size(400, 300),
    center: savedBounds == null || !boundsOnScreen,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (savedBounds != null && boundsOnScreen && !wasMaximized) {
      await windowManager.setPosition(
        Offset(savedBounds.left, savedBounds.top),
      );
    }
    await windowManager.show();
    await windowManager.focus();
    if (wasMaximized) {
      await windowManager.maximize();
    }
  });

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

class _LibreOTPAppState extends State<LibreOTPApp> with WindowListener {
  ThemeMode _themeMode = ThemeMode.system;
  Timer? _saveTimer;
  bool _isMaximized = false;
  Rect? _lastWindowBounds;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _loadThemeMode();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _saveTimer?.cancel();
    super.dispose();
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

  void _debounceSaveWindowBounds() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isMaximized) return;
      final bounds =
          await _captureCurrentWindowBounds(reason: 'debounced-save');
      if (bounds == null) {
        return;
      }
      await AppConfig.setWindowBounds(bounds);
    });
  }

  Future<Rect?> _captureCurrentWindowBounds({required String reason}) async {
    if (_isMaximized) {
      return _lastWindowBounds;
    }

    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final bounds =
          Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
      _lastWindowBounds = bounds;
      return bounds;
    } catch (_) {
      return _lastWindowBounds;
    }
  }

  Future<void> _saveWindowStateOnClose() async {
    Rect? boundsToPersist = _lastWindowBounds;

    if (!_isMaximized && boundsToPersist == null) {
      boundsToPersist =
          await _captureCurrentWindowBounds(reason: 'close-fallback')
              .timeout(const Duration(milliseconds: 150), onTimeout: () {
        return _lastWindowBounds;
      });
    }

    await AppConfig.persistWindowState(
      maximized: _isMaximized,
      bounds: _isMaximized ? null : boundsToPersist,
    ).timeout(const Duration(milliseconds: 150), onTimeout: () {});
  }

  @override
  void onWindowResized() {
    unawaited(_captureCurrentWindowBounds(reason: 'resize'));
    _debounceSaveWindowBounds();
  }

  @override
  void onWindowMoved() {
    unawaited(_captureCurrentWindowBounds(reason: 'move'));
    _debounceSaveWindowBounds();
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    AppConfig.setWindowMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    AppConfig.setWindowMaximized(false);
    unawaited(_captureCurrentWindowBounds(reason: 'unmaximize'));
  }

  @override
  void onWindowClose() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    _saveTimer?.cancel();
    try {
      await _saveWindowStateOnClose();
    } catch (e) {
      debugPrint('Could not persist window state on close: $e');
    }
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (e) {
      // Let the user retry closing instead of latching the window open.
      _isClosing = false;
      debugPrint('Window close failed: $e');
    }
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
