import 'dart:math';
import '../../data/models/answer_log.dart';
import '../../shared/constants.dart';

class QualityScoreCalculator {
  final double w1;
  final double w2;
  final double w3;
  final double w4;
  final double medianTimeMs;

  const QualityScoreCalculator({
    this.w1 = AppConstants.qsWeightConfidence,
    this.w2 = AppConstants.qsWeightTime,
    this.w3 = AppConstants.qsWeightCorrectness,
    this.w4 = AppConstants.qsWeightHesitation,
    this.medianTimeMs = 15000,
  });

  double calculate(AnswerLog log) {
    final conf = _confidenceNormalized(log.confidenceRating);
    final time = _timeScore(log.responseTimeMs);
    final correct = _correctnessBonus(log.isCorrect);
    final hesit = _hesitationPenalty(log.hesitationCount);

    final raw = w1 * conf + w2 * time + w3 * correct + w4 * hesit;
    return mapToSM2Range(raw);
  }

  double _confidenceNormalized(int rating) => rating.clamp(1, 5) / 5.0;

  double _timeScore(int ms) {
    final ratio = ms / medianTimeMs;
    return 1.0 / (1.0 + exp(2.0 * (ratio - 1.0)));
  }

  double _correctnessBonus(bool correct) => correct ? 0.7 : 0.0;

  double _hesitationPenalty(int count) => (1.0 - 0.15 * count).clamp(0.0, 1.0);

  double mapToSM2Range(double raw) => (raw * 5.0).clamp(0.0, 5.0);
}
