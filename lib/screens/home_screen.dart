import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_step.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../services/rewards_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService.instance;
  final HealthService _healthService = HealthService();
  final RewardsService _rewardsService = const RewardsService();

  bool _isLoading = true;
  bool _hasPermission = false;
  bool _healthConnectUnavailable = false;
  int _todaySteps = 0;
  int _weekSteps = 0;
  int _monthSteps = 0;
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
        // Backfill historical data from HealthKit (past 30 days)
        final historical = await _healthService.getHistoricalSteps(days: 30);
        for (final entry in historical.entries) {
          final pts = _rewardsService.calculatePoints(entry.value);
          await _databaseService.upsertSteps(entry.key, entry.value, pts);
        }

        // Today's steps (ensure fresh value)
        final todayKey = _todayKey;
        todaySteps = historical[todayKey] ?? await _healthService.getTodaySteps();
        final pts = _rewardsService.calculatePoints(todaySteps);
        await _databaseService.upsertSteps(todayKey, todaySteps, pts);
        history = await _databaseService.getStepsHistory();
      }

      if (!mounted) {
        return;
      }

      final periodStats = _computePeriodStats(history, todaySteps);

      setState(() {
        _hasPermission = hasPermission;
        _healthConnectUnavailable =
            status == PermissionStatus.healthConnectUnavailable;
        _todaySteps = todaySteps;
        _history = _lastSevenDays(history);
        _weekSteps = periodStats['weekSteps']!;
        _monthSteps = periodStats['monthSteps']!;
      });
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

  Map<String, int> _computePeriodStats(
    List<DailyStep> history,
    int todaySteps,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int weekSteps = 0;
    int monthSteps = 0;

    for (final item in history) {
      final date = DateTime.parse(item.date);
      if (!date.isBefore(weekStart)) weekSteps += item.steps;
      if (!date.isBefore(monthStart)) monthSteps += item.steps;
    }

    // Ensure today's live value is included if not yet in DB history
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final alreadyCounted = history.any((h) => h.date == todayKey);
    if (!alreadyCounted && todaySteps > 0) {
      weekSteps += todaySteps;
      monthSteps += todaySteps;
    }

    return {'weekSteps': weekSteps, 'monthSteps': monthSteps};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_todaySteps / 10000).clamp(0, 1).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mango Health'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
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
            _SummaryCard(
              todaySteps: _todaySteps,
              progress: progress,
              isLoading: _isLoading,
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
            _PeriodSummarySection(
              todaySteps: _todaySteps,
              weekSteps: _weekSteps,
              monthSteps: _monthSteps,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            Text(
              'Last 7 days',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ..._history.map(_HistoryTile.new),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.step);

  final DailyStep step;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(step.date);

    return Card(
      child: ListTile(
        title: Text(DateFormat.MMMd().format(date)),
        subtitle: Text('${NumberFormat.decimalPattern().format(step.steps)} steps'),
      ),
    );
  }
}

class _PeriodSummarySection extends StatelessWidget {
  const _PeriodSummarySection({
    required this.todaySteps,
    required this.weekSteps,
    required this.monthSteps,
    required this.isLoading,
  });

  final int todaySteps;
  final int weekSteps;
  final int monthSteps;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Period summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PeriodCard(
                label: 'Today',
                steps: todaySteps,
                goal: 10000,
                isLoading: isLoading,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeriodCard(
                label: 'This week',
                steps: weekSteps,
                goal: 70000,
                isLoading: isLoading,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PeriodCard(
                label: 'This month',
                steps: monthSteps,
                goal: null,
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.label,
    required this.steps,
    required this.goal,
    required this.isLoading,
  });

  final String label;
  final int steps;
  final int? goal;
  final bool isLoading;

  String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = goal != null ? (steps / goal!).clamp(0.0, 1.0) : null;
    final goalMet = goal != null && steps >= goal!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: goalMet ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(steps),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: goalMet ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          Text(
            'steps',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isLoading ? null : progress,
                minHeight: 5,
                backgroundColor: cs.surface,
                color: goalMet ? cs.primary : cs.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
