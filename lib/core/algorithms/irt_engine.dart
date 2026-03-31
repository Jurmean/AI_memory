import 'dart:math';

class AnswerRecord {
  final bool isCorrect;
  final double difficultyB;

  const AnswerRecord({required this.isCorrect, required this.difficultyB});
}

class IRTEngine {
  static const int _maxIterations = 30;
  static const double _convergenceThreshold = 0.001;

  const IRTEngine();

  double probability(double theta, double b) {
    return 1.0 / (1.0 + exp(-(theta - b)));
  }

  double informationFunction(double theta, double b) {
    final p = probability(theta, b);
    return p * (1 - p);
  }

  double estimateTheta(List<AnswerRecord> history, {double initialTheta = 0.0}) {
    if (history.isEmpty) return initialTheta;

    var theta = initialTheta;
    for (var i = 0; i < _maxIterations; i++) {
      final step = _newtonRaphsonStep(theta, history);
      theta += step;
      theta = theta.clamp(-4.0, 4.0);
      if (step.abs() < _convergenceThreshold) break;
    }
    return theta;
  }

  double _newtonRaphsonStep(double theta, List<AnswerRecord> history) {
    var firstDerivative = 0.0;
    var secondDerivative = 0.0;

    for (final record in history) {
      final p = probability(theta, record.difficultyB);
      final x = record.isCorrect ? 1.0 : 0.0;
      firstDerivative += (x - p);
      secondDerivative -= p * (1 - p);
    }

    if (secondDerivative.abs() < 1e-10) return 0.0;
    return -firstDerivative / secondDerivative;
  }

  double updateDifficultyB(double currentB, List<AnswerRecord> logs) {
    if (logs.length < 3) return currentB;
    final correctRate = logs.where((l) => l.isCorrect).length / logs.length;
    final adjustment = (0.5 - correctRate) * 0.5;
    return (currentB + adjustment).clamp(-3.0, 3.0);
  }
}
