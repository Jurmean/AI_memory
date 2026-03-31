class AppConstants {
  AppConstants._();

  static const String appName = '智能记忆助手';
  static const String appVersion = '1.0.0';

  // LLM defaults
  static const String defaultBaseUrl =
      'https://api.minimaxi.com/v1/chat/completions';
  static const String defaultModel = 'MiniMax-M2.7';
  static const String defaultApiKey =
      'sk-cp-2M2JzdyM3Vq9slS2_vN-oLaQ345NlXNK-1eHMzDMjs3sX_-DrMax3zmCh-nRsXvbq48sgvWaSrB27uINjg8IuUwN4iP_tCHPQESoYaUNU-s--PdMowupV6g';

  // Algorithm parameters
  static const double qsWeightConfidence = 0.35;
  static const double qsWeightTime = 0.25;
  static const double qsWeightCorrectness = 0.30;
  static const double qsWeightHesitation = 0.10;
  static const double defaultEF = 2.5;
  static const double minEF = 1.3;
  static const double defaultTheta = 0.0;
  static const double defaultStability = 30.0;
  static const double irtAdjustScale = 0.3;

  // FSRS constants
  static const double fsrsF = 19.0 / 81.0;
  static const double fsrsC = -0.5;

  // Review
  static const int diagnosisTriggerCount = 10;
  static const int maxQuizSize = 10;
  static const int maxReviewQueueSize = 10;

  // Knowledge graph
  static const int kgMaxBfsDepth = 2;
  static const double kgAlpha = 0.3;

  // Scheduler weights
  static const double schedulerAlpha = 0.5;
  static const double schedulerBeta = 0.3;
  static const double schedulerGamma = 0.2;

  // LLM
  static const int llmReceiveTimeoutMs = 180000;
  static const int llmConnectTimeoutMs = 30000;

  // Grades
  static const List<String> gradeOptions = [
    '高一',
    '高二',
    '高三',
    '大一',
    '大二',
    '大三',
    '大四',
    '其他',
  ];

  static const List<String> subjectOptions = [
    '化学',
    '物理',
    '数学',
    '生物',
    '英语',
    '历史',
    '地理',
    '其他',
  ];
}
