import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_step.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../services/pocketbase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService.instance;
  final HealthService _healthService = HealthService();

  bool _isLoading = true;
  bool _hasPermission = false;
  bool _healthConnectUnavailable = false;
  int _todaySteps = 0;
  List<DailyStep> _history = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData(requestPermissions: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData({bool requestPermissions = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _healthConnectUnavailable = false;
    });

    try {
      PermissionStatus status;
      if (requestPermissions) {
        status = await _healthService.requestPermissions();
      } else {
        status = _hasPermission
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      }

      final hasPermission = status == PermissionStatus.granted;

      List<DailyStep> history = await _databaseService.getStepsHistory();
      int todaySteps = 0;

      if (hasPermission) {
        // Backfill historical data from HealthKit (past 35 days)
        final historical = await _healthService.getHistoricalSteps(days: 35);
        for (final entry in historical.entries) {
          await _databaseService.upsertSteps(entry.key, entry.value, 0);
        }

        // Today's steps (ensure fresh value)
        final todayKey = _todayKey;
        todaySteps = historical[todayKey] ?? await _healthService.getTodaySteps();
        await _databaseService.upsertSteps(todayKey, todaySteps, 0);
        history = await _databaseService.getStepsHistory();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPermission = hasPermission;
        _healthConnectUnavailable =
            status == PermissionStatus.healthConnectUnavailable;
        _todaySteps = todaySteps;
        _history = _lastSevenDays(history);
      });

      // Sync steps then pull server-assigned cashback, both in the background
      PocketBaseService.instance.syncDailySteps().then((_) async {
        await PocketBaseService.instance.fetchCashback();
        if (!mounted) return;
        final updated = await _databaseService.getStepsHistory();
        setState(() => _history = _lastSevenDays(updated));
      }).catchError((_) {});
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load step data.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<DailyStep> _lastSevenDays(List<DailyStep> history) {
    final byDate = {for (final item in history) item.date: item};
    final now = DateTime.now();

    return List<DailyStep>.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: index),
      );
      final key = DateFormat('yyyy-MM-dd').format(date);
      return byDate[key] ??
          DailyStep(date: key, steps: 0, rewardPoints: 0, synced: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_todaySteps / 5000).clamp(0, 1).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mango Health'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _loadData(),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              DateFormat.yMMMMEEEEd().format(DateTime.now()),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      todaySteps: _todaySteps,
                      progress: progress,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CashCard(
                      points: _history.isNotEmpty ? _history.first.rewardPoints : 0,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),
            if (!_hasPermission) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _healthConnectUnavailable
                            ? 'Health Connect required'
                            : 'Health access needed',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _healthConnectUnavailable
                            ? 'Please install Health Connect from the Play Store to track your steps.'
                            : 'Grant step access to load your daily progress.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () => _loadData(requestPermissions: true),
                        child: Text(
                          _healthConnectUnavailable
                              ? 'Install Health Connect'
                              : 'Grant permission',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Last7DaysList(history: _history, isLoading: _isLoading),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.todaySteps,
    required this.progress,
    required this.isLoading,
  });

  final int todaySteps;
  final double progress;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s steps', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              NumberFormat.decimalPattern().format(todaySteps),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: isLoading ? null : progress),
            const SizedBox(height: 8),
            Text(
              '${NumberFormat.decimalPattern().format(todaySteps)} / 10,000 goal',
            ),
          ],
        ),
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.points, required this.isLoading});

  final int points;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final earned = points > 0;

    return Card(
      color: earned ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cash earned', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            isLoading
                ? const CircularProgressIndicator()
                : Text(
                    points > 0 ? '₹$points' : '—',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: earned ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              points == 0
                  ? 'Cashback processed daily'
                  : points == 10
                      ? '5k–10k steps reached'
                      : '10k steps goal met! 🎉',
              style: theme.textTheme.bodySmall?.copyWith(
                color: earned ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Last7DaysList extends StatelessWidget {
  const _Last7DaysList({required this.history, required this.isLoading});

  final List<DailyStep> history;
  final bool isLoading;

  static const _goal = 10000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 7 days', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        // Column headers
        Row(
          children: [
            const SizedBox(width: 40 + 4 + 42 + 8), // day + date
            const Expanded(child: SizedBox()),
            SizedBox(
              width: 56,
              child: Text('Steps',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text('Cash',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ...history.map((step) {
            final date = DateTime.parse(step.date);
            final isToday = step.date ==
                DateFormat('yyyy-MM-dd').format(DateTime.now());
            final progress = (step.steps / _goal).clamp(0.0, 1.0);
            final goalMet = step.steps >= _goal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Day label
                  SizedBox(
                    width: 40,
                    child: Text(
                      isToday ? 'Today' : DateFormat('EEE').format(date),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : null,
                        color: isToday ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Date
                  SizedBox(
                    width: 42,
                    child: Text(
                      DateFormat('MMM d').format(date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Progress bar
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: goalMet ? cs.primary : cs.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Steps count
                  SizedBox(
                    width: 56,
                    child: Text(
                      NumberFormat.compact().format(step.steps),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: goalMet ? FontWeight.bold : null,
                        color: goalMet ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cashback
                  SizedBox(
                    width: 40,
                    child: Text(
                      step.rewardPoints > 0 ? '₹${step.rewardPoints}' : '—',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: step.rewardPoints > 0 ? FontWeight.bold : null,
                        color: step.rewardPoints > 0
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
