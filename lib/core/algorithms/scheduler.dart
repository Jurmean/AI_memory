import 'dart:math';
import '../../data/models/review_state.dart';
import '../../shared/constants.dart';
import 'sm2_engine.dart';
import 'irt_engine.dart';
import 'quality_score.dart';

class ScheduledItem {
  final String questionId;
  final double priority;
  final ReviewState state;
  final double? difficultyB;

  const ScheduledItem({
    required this.questionId,
    required this.priority,
    required this.state,
    this.difficultyB,
  });
}

class ReviewScheduler {
  final SM2Engine sm2;
  final IRTEngine irt;
  final QualityScoreCalculator qsCalc;
  final double alpha;
  final double beta;
  final double gamma;

  const ReviewScheduler({
    this.sm2 = const SM2Engine(),
    this.irt = const IRTEngine(),
    this.qsCalc = const QualityScoreCalculator(),
    this.alpha = AppConstants.schedulerAlpha,
    this.beta = AppConstants.schedulerBeta,
    this.gamma = AppConstants.schedulerGamma,
  });

  double intervalAdjustmentFactor(double theta, double b) {
    return 1.0 + AppConstants.irtAdjustScale * _tanh(theta - b);
  }

  int adjustedInterval(int baseInterval, double theta, double b) {
    final factor = intervalAdjustmentFactor(theta, b);
    return max(1, (baseInterval * factor).round());
  }

  double calculatePriority(ReviewState state, double theta, double difficultyB,
      {double synergy = 0.0}) {
    final urgency = _urgencyScore(state);
    final infoGain = _infoGainScore(theta, difficultyB);
    return alpha * urgency + beta * infoGain + gamma * synergy;
  }

  double _urgencyScore(ReviewState state) {
    final overdueDays =
        DateTime.now().difference(state.nextReviewDate).inDays.toDouble();
    if (overdueDays <= 0) return 0.0;
    return 1.0 - 1.0 / (1.0 + overdueDays / 3.0);
  }

  double _infoGainScore(double theta, double b) {
    return irt.informationFunction(theta, b);
  }

  double _tanh(double x) => (exp(2 * x) - 1) / (exp(2 * x) + 1);
}
