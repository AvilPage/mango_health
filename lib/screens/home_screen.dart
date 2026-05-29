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
  int _todaySteps = 0;
  int _todayPoints = 0;
  int _totalPoints = 0;
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
    });

    try {
      final hasPermission = requestPermissions
          ? await _healthService.requestPermissions()
          : _hasPermission;

      List<DailyStep> history = await _databaseService.getStepsHistory();
      int todaySteps = 0;
      int todayPoints = 0;

      if (hasPermission) {
        todaySteps = await _healthService.getTodaySteps();
        todayPoints = _rewardsService.calculatePoints(todaySteps);
        await _databaseService.upsertSteps(_todayKey, todaySteps, todayPoints);
        history = await _databaseService.getStepsHistory();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPermission = hasPermission;
        _todaySteps = todaySteps;
        _todayPoints = todayPoints;
        _history = _lastSevenDays(history);
        _totalPoints = _rewardsService.getTotalPoints(history);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_todaySteps / 10000).clamp(0, 1).toDouble();

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
            _SummaryCard(
              todaySteps: _todaySteps,
              progress: progress,
              todayPoints: _todayPoints,
              totalPoints: _totalPoints,
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
                        'Health access needed',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Grant step access to load your daily progress and rewards.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () => _loadData(requestPermissions: true),
                        child: const Text('Grant permission'),
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
    required this.todayPoints,
    required this.totalPoints,
    required this.isLoading,
  });

  final int todaySteps;
  final double progress;
  final int todayPoints;
  final int totalPoints;
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Today\'s reward',
                    value: '$todayPoints pts',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Total rewards',
                    value: '$totalPoints pts',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.step);

  final DailyStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.parse(step.date);

    return Card(
      child: ListTile(
        title: Text(DateFormat.MMMd().format(date)),
        subtitle: Text('${NumberFormat.decimalPattern().format(step.steps)} steps'),
        trailing: Text(
          '${step.rewardPoints} pts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
