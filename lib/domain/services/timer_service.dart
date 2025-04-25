import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/otp_service.dart';

class TimerService {
  final Map<String, Timer?> _timers = {};
  final Function(OtpService) onTimerTick;
  final Function(OtpService) onTimerComplete;

  TimerService({
    required this.onTimerTick,
    required this.onTimerComplete,
  });

  void startTimer(String id, OtpService service, int timeRemaining) {
    // Cancel existing timer if any
    _timers[id]?.cancel();
    
    // Start a new timer
    _timers[id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final secondsLeft = int.tryParse(service.validity?.replaceAll('s', '') ?? '0') ?? 0;
      if (secondsLeft > 1) {
        service.validity = '${secondsLeft - 1}s';
        onTimerTick(service);
      } else {
        service.otpCode = '';
        service.validity = '';
        timer.cancel();
        _timers.remove(id);
        onTimerComplete(service);
      }
    });
  }

  void cancelTimer(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  void cancelAllTimers() {
    _timers.forEach((_, timer) => timer?.cancel());
    _timers.clear();
  }

  @override
  void dispose() {
    cancelAllTimers();
  }
}