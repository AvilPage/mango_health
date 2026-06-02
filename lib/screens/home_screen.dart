import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_step.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../services/rewards_service.dart';

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

      setState(() {
        _hasPermission = hasPermission;
        _healthConnectUnavailable =
            status == PermissionStatus.healthConnectUnavailable;
        _todaySteps = todaySteps;
        _history = _lastThirtyFiveDays(history);
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

  List<DailyStep> _lastThirtyFiveDays(List<DailyStep> history) {
    final byDate = {for (final item in history) item.date: item};
    final now = DateTime.now();

    return List<DailyStep>.generate(35, (index) {
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
                      points: _rewardsService.calculatePoints(_todaySteps),
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
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.25,
              child: _StepsHeatmap(history: _history, isLoading: _isLoading),
            ),
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
                    '₹$points',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: earned ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              points == 0
                  ? 'Walk 5,000+ steps to earn'
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

class _StepsHeatmap extends StatelessWidget {
  const _StepsHeatmap({required this.history, required this.isLoading});

  final List<DailyStep> history;
  final bool isLoading;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Color _tileColor(int steps, ColorScheme cs) {
    if (steps <= 0) return cs.surfaceContainerHighest;
    if (steps < 3000) return cs.primary.withValues(alpha: 0.25);
    if (steps < 6000) return cs.primary.withValues(alpha: 0.50);
    if (steps < 9000) return cs.primary.withValues(alpha: 0.75);
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final byDate = {for (final s in history) s.date: s.steps};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Align to Monday of current week
    final weekday = today.weekday; // 1=Mon, 7=Sun
    final currentWeekMonday = today.subtract(Duration(days: weekday - 1));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Transposed: rows=weeks(5), cols=days(7)
        // chrome: title(20) + gap(3) + day-headers(14) + gap(4) + legend(6+10) = ~57
        const chromeHeight = 72.0;
        const weeks = 5;
        const labelWidth = 36.0; // week date label on left
        const gapBetween = 4.0;
        const tileGap = 3.0;

        final availableHeight = constraints.maxHeight - chromeHeight;
        // 5 rows + 4 gaps
        final tileSizeByHeight = (availableHeight - 4 * tileGap) / weeks;
        // 7 cols + 6 gaps
        final tileSizeByWidth =
            (constraints.maxWidth - labelWidth - gapBetween - 6 * tileGap) / 7;
        final tileSize = tileSizeByHeight.clamp(8.0, tileSizeByWidth);

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Activity', style: theme.textTheme.titleSmall),
            const SizedBox(height: 3),
            // Day-of-week column headers
            Row(
              children: [
                SizedBox(width: labelWidth + gapBetween),
                ...List.generate(7, (di) => Padding(
                      padding: EdgeInsets.only(right: di < 6 ? tileGap : 0),
                      child: SizedBox(
                        width: tileSize,
                        child: Center(
                          child: Text(
                            _dayLabels[di],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 4),
            // Grid: 5 week rows
            ...List.generate(weeks, (wi) {
              final weekMonday = currentWeekMonday
                  .subtract(Duration(days: (weeks - 1 - wi) * 7));
              return Padding(
                padding: EdgeInsets.only(bottom: wi < weeks - 1 ? tileGap : 0),
                child: Row(
                  children: [
                    // Week label
                    SizedBox(
                      width: labelWidth,
                      height: tileSize,
                      child: Center(
                        child: Text(
                          DateFormat('MMM d').format(weekMonday),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: gapBetween),
                    // 7 day tiles
                    ...List.generate(7, (di) {
                      final date = weekMonday.add(Duration(days: di));
                      final isFuture = date.isAfter(today);
                      final key = DateFormat('yyyy-MM-dd').format(date);
                      final steps = byDate[key] ?? 0;
                      return Padding(
                        padding: EdgeInsets.only(right: di < 6 ? tileGap : 0),
                        child: Tooltip(
                          message: isFuture
                              ? ''
                              : '${DateFormat('MMM d').format(date)}: ${NumberFormat.decimalPattern().format(steps)} steps',
                          child: Container(
                            width: tileSize,
                            height: tileSize,
                            decoration: BoxDecoration(
                              color: isFuture
                                  ? Colors.transparent
                                  : _tileColor(steps, cs),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Less',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9)),
                const SizedBox(width: 4),
                ...[0, 2999, 5999, 8999, 10000].map((s) => Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _tileColor(s, cs),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                const SizedBox(width: 4),
                Text('More',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9)),
              ],
            ),
          ],
        );
      },
    );
  }
}
