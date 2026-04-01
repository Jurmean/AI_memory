import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/question.dart';
import '../data/models/answer_log.dart';
import '../data/models/review_session.dart';
import '../core/algorithms/quality_score.dart';
import '../core/algorithms/sm2_engine.dart';
import '../core/algorithms/irt_engine.dart';
import '../core/algorithms/scheduler.dart';
import '../shared/constants.dart';
import 'database_provider.dart';
import 'user_profile_provider.dart';
import 'review_queue_provider.dart';
import 'diagnosis_provider.dart';

class QuizState {
  final List<Question> questions;
  final int currentIndex;
  final List<AnswerLog> logs;
  final ReviewSession? session;
  final bool isFinished;

  const QuizState({
    this.questions = const [],
    this.currentIndex = 0,
    this.logs = const [],
    this.session,
    this.isFinished = false,
  });

  QuizState copyWith({
    List<Question>? questions,
    int? currentIndex,
    List<AnswerLog>? logs,
    ReviewSession? session,
    bool? isFinished,
  }) =>
      QuizState(
        questions: questions ?? this.questions,
        currentIndex: currentIndex ?? this.currentIndex,
        logs: logs ?? this.logs,
        session: session ?? this.session,
        isFinished: isFinished ?? this.isFinished,
      );

  int get totalQuestions => questions.length;
  int get answeredCount => logs.length;
  int get correctCount => logs.where((l) => l.isCorrect).length;
  Question? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;
}

class CurrentQuizNotifier extends Notifier<QuizState> {
  static const _sm2 = SM2Engine();
  static const _irt = IRTEngine();
  static const _qsCalc = QualityScoreCalculator();
  static const _scheduler = ReviewScheduler();

  @override
  QuizState build() => const QuizState();

  Future<void> startQuiz(List<Question> allQuestions) async {
    ref.read(diagnosisProvider.notifier).clearLatestReport();
    final db = ref.read(databaseProvider);
    final capped = allQuestions.take(AppConstants.maxQuizSize).toList();
    final session = ReviewSession(
      startTime: DateTime.now(),
      totalQuestions: capped.length,
    );
    final insertedId = await db.insertSession(session);
    final savedSession = session.copyWith(id: insertedId);

    state = QuizState(questions: capped, session: savedSession);
  }

  Future<void> submitAnswer({
    required int selectedOptionIndex,
    required int responseTimeMs,
    required int confidenceRating,
    required int hesitationCount,
  }) async {
    final question = state.currentQuestion;
    if (question == null || state.isFinished) return;

    final db = ref.read(databaseProvider);
    final isCorrect = selectedOptionIndex == question.correctIndex;
    final log = AnswerLog(
      questionId: question.id,
      sessionId: state.session!.id!,
      isCorrect: isCorrect,
      selectedOptionIndex: selectedOptionIndex,
      responseTimeMs: responseTimeMs,
      confidenceRating: confidenceRating,
      hesitationCount: hesitationCount,
      timestamp: DateTime.now(),
      reviewNumber: state.logs.length + 1,
    );
    await db.insertAnswerLog(log);

    final rs = await db.getReviewState(question.id);
    if (rs != null) {
      final qs = _qsCalc.calculate(log);
      final updated = _sm2.processAnswer(rs, qs);
      final profileAsync = ref.read(userProfileProvider);
      final theta = profileAsync.value?.theta ?? AppConstants.defaultTheta;
      final adjustedInterval =
          _scheduler.adjustedInterval(updated.intervalDays, theta, question.difficultyB);
      final fused = updated.copyWith(
        intervalDays: adjustedInterval,
        nextReviewDate: DateTime.now().add(Duration(days: adjustedInterval)),
      );
      await db.upsertReviewState(fused);
    }

    // Update theta via IRT
    final allLogs = [...state.logs, log];
    final records = allLogs.map((l) {
      final q = state.questions.firstWhere((q) => q.id == l.questionId);
      return AnswerRecord(isCorrect: l.isCorrect, difficultyB: q.difficultyB);
    }).toList();
    final newTheta = _irt.estimateTheta(records);

    await ref.read(userProfileProvider.notifier).recordAnswer(
          isCorrect: isCorrect,
          newTheta: newTheta,
        );

    final nextIndex = state.currentIndex + 1;
    final finished = nextIndex >= state.questions.length;

    state = state.copyWith(
      logs: [...state.logs, log],
      currentIndex: nextIndex,
      isFinished: finished,
    );

    if (finished) {
      await _endSession();
    }
  }

  Future<void> endSessionEarly() async {
    if (state.session == null) return;
    state = state.copyWith(isFinished: true);
    await _endSession();
  }

  Future<void> _endSession() async {
    final db = ref.read(databaseProvider);
    final session = state.session;
    if (session == null || session.id == null) return;

    final profileAsync = ref.read(userProfileProvider);
    final theta = profileAsync.value?.theta ?? AppConstants.defaultTheta;
    await db.updateSession(session.id!,
        endTime: DateTime.now(), thetaSnapshot: theta);
    await ref.read(reviewQueueProvider.notifier).refresh();

    if (state.answeredCount >= AppConstants.diagnosisTriggerCount) {
      ref.read(diagnosisProvider.notifier).triggerSessionDiagnosis(
            sessionId: session.id!,
            logs: state.logs,
            questions: state.questions,
          );
    }
  }

  void reset() {
    state = const QuizState();
  }
}

final currentQuizProvider =
    NotifierProvider<CurrentQuizNotifier, QuizState>(CurrentQuizNotifier.new);
