import 'dart:io';

import 'package:health/health.dart';

class HealthService {
  HealthService({Health? health}) : _health = health ?? Health();

  final Health _health;
  final List<HealthDataType> _types = const [HealthDataType.STEPS];
  bool _isConfigured = false;

  Future<void> _ensureConfigured() async {
    if (_isConfigured) {
      return;
    }

    await _health.configure();
    _isConfigured = true;
  }

  Future<bool> requestPermissions() async {
    await _ensureConfigured();

    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return false;
      }
    }

    final hasPermissions = await _health.hasPermissions(_types);
    if (hasPermissions == true) {
      return true;
    }

    return _health.requestAuthorization(_types);
  }

  Future<int> getTodaySteps() async {
    return getStepsForDate(DateTime.now());
  }

  Future<int> getStepsForDate(DateTime date) async {
    await _ensureConfigured();

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final steps = await _health.getTotalStepsInInterval(start, end);

    return steps ?? 0;
  }
}
