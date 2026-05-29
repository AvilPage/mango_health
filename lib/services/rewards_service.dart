import '../models/daily_step.dart';

class RewardsService {
  const RewardsService();

  int calculatePoints(int steps) {
    if (steps < 5000) {
      return 0;
    }
    if (steps < 10000) {
      return 10;
    }
    return 25;
  }

  int getTotalPoints(List<DailyStep> history) {
    return history.fold<int>(0, (total, day) => total + day.rewardPoints);
  }
}
