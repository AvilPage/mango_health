class DailyStep {
  const DailyStep({
    required this.date,
    required this.steps,
    required this.rewardPoints,
    required this.synced,
  });

  final String date;
  final int steps;
  final int rewardPoints;
  final bool synced;

  factory DailyStep.fromMap(Map<String, Object?> map) {
    return DailyStep(
      date: map['date']! as String,
      steps: map['steps']! as int,
      rewardPoints: map['reward_points']! as int,
      synced: (map['synced']! as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'steps': steps,
      'reward_points': rewardPoints,
      'synced': synced ? 1 : 0,
    };
  }
}
