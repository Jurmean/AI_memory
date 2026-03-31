import 'dart:math';
import '../../data/models/review_state.dart';
import '../../shared/constants.dart';

class SM2Engine {
  const SM2Engine();

  ReviewState processAnswer(ReviewState current, double qs) {
    final newEF = _updateEF(current.easinessFactor, qs);
    final newCount = current.reviewCount + 1;
    final newInterval = _calculateInterval(newCount, newEF, current.intervalDays);
    final nextDate = DateTime.now().add(Duration(days: newInterval));

    return current.copyWith(
      easinessFactor: newEF,
      intervalDays: newInterval,
      reviewCount: newCount,
      nextReviewDate: nextDate,
      lastQS: qs,
    );
  }

  double _updateEF(double ef, double qs) {
    final newEF = ef + (0.1 - (5 - qs) * (0.08 + (5 - qs) * 0.02));
    return max(AppConstants.minEF, newEF);
  }

  int _calculateInterval(int n, double ef, int prevInterval) {
    if (n <= 1) return 1;
    if (n == 2) return 6;
    return max(1, (prevInterval * ef).round());
  }
}
