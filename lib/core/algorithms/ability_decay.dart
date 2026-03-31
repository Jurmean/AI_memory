import 'dart:math';
import '../../shared/constants.dart';

class AbilityDecay {
  const AbilityDecay._();

  static double retrievability(double daysSinceLastStudy, double stability) {
    if (daysSinceLastStudy <= 0) return 1.0;
    return pow(1 + AppConstants.fsrsF * daysSinceLastStudy / stability,
            AppConstants.fsrsC)
        .toDouble();
  }

  static double effectiveTheta(
      double theta, double daysSinceLastStudy, double stability) {
    return theta * retrievability(daysSinceLastStudy, stability);
  }

  static double estimateStability(double correctRate, int totalReviews) {
    return (AppConstants.defaultStability *
            (0.5 + correctRate) *
            (1 + log(1 + totalReviews) / 5))
        .clamp(7.0, 365.0);
  }

  static double halfLife(double stability) {
    return stability * (pow(0.5, 1.0 / AppConstants.fsrsC) - 1) / AppConstants.fsrsF;
  }

  static List<Map<String, double>> predictedCurve(
      double theta, double stability,
      {int futureDays = 30}) {
    final points = <Map<String, double>>[];
    for (var d = 0; d <= futureDays; d++) {
      final r = retrievability(d.toDouble(), stability);
      points.add({'day': d.toDouble(), 'theta': theta * r, 'retrievability': r});
    }
    return points;
  }
}
