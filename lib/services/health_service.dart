import 'dart:io';

import 'package:health/health.dart';
import 'package:intl/intl.dart';

enum PermissionStatus { granted, healthConnectUnavailable, denied }

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

  Future<PermissionStatus> requestPermissions() async {
    await _ensureConfigured();

    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _health.installHealthConnect();
        return PermissionStatus.healthConnectUnavailable;
      }
    }

    final hasPermissions = await _health.hasPermissions(_types);
    if (hasPermissions == true) {
      return PermissionStatus.granted;
    }

    final granted = await _health.requestAuthorization(_types);
    return granted ? PermissionStatus.granted : PermissionStatus.denied;
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

  /// Fetches step counts for the past [days] days (including today).
  /// Returns a map of ISO date string (yyyy-MM-dd) → step count.
  Future<Map<String, int>> getHistoricalSteps({int days = 30}) async {
    await _ensureConfigured();

    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day + 1);
    final start = DateTime(today.year, today.month, today.day - days + 1);

    final data = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: _types,
    );

    final totals = <String, int>{};
    for (final point in data) {
      final date = DateFormat('yyyy-MM-dd').format(point.dateFrom);
      final value = (point.value as NumericHealthValue).numericValue.round();
      totals[date] = (totals[date] ?? 0) + value;
    }

    return totals;
  }
}
