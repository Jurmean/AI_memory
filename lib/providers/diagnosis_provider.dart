import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/answer_log.dart';
import '../data/models/question.dart';
import '../data/models/diagnostic_report.dart';
import '../llm/services/diagnosis_service.dart';
import '../llm/prompts/prompt_builder.dart';
import 'database_provider.dart';
import 'llm_provider.dart';
import 'user_profile_provider.dart';

class DiagnosisState {
  final List<DiagnosticReport> reports;
  final bool isGenerating;
  final String? error;
  final DiagnosticReport? latestReport;

  const DiagnosisState({
    this.reports = const [],
    this.isGenerating = false,
    this.error,
    this.latestReport,
  });

  DiagnosisState copyWith({
    List<DiagnosticReport>? reports,
    bool? isGenerating,
    String? error,
    DiagnosticReport? latestReport,
  }) =>
      DiagnosisState(
        reports: reports ?? this.reports,
        isGenerating: isGenerating ?? this.isGenerating,
        error: error,
        latestReport: latestReport ?? this.latestReport,
      );

  List<DiagnosticReport> get sessionReports =>
      reports.where((r) => r.reportType == 'session').toList();
  List<DiagnosticReport> get overallReports =>
      reports.where((r) => r.reportType == 'overall').toList();
}

class DiagnosisNotifier extends Notifier<DiagnosisState> {
  @override
  DiagnosisState build() {
    _loadReports();
    return const DiagnosisState();
  }

  Future<void> _loadReports() async {
    final db = ref.read(databaseProvider);
    final reports = await db.getAllReports();
    state = state.copyWith(reports: reports);
  }

  Future<void> triggerSessionDiagnosis({
    required int sessionId,
    required List<AnswerLog> logs,
    required List<Question> questions,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final db = ref.read(databaseProvider);
      final client = ref.read(llmClientProvider);
      final settings = ref.read(llmSettingsProvider);
      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.value;
      if (profile == null) return;

      final weakPoints = await db.getWeakKnowledgePoints();
      final profileCtx =
          PromptBuilder.buildDiagnosisContext(profile, weakPoints: weakPoints);

      final questionDetails = logs.map((l) {
        final q = questions.firstWhere((q) => q.id == l.questionId);
        return <String, dynamic>{
          'stem': q.stem,
          'correct': l.isCorrect,
          'time': (l.responseTimeMs / 1000).toStringAsFixed(1),
          'confidence': l.confidenceRating,
        };
      }).toList();

      final service = DiagnosisService(client);
      final report = await service.generateSessionReport(
        sessionId: sessionId,
        profileContext: profileCtx,
        totalQuestions: logs.length,
        correctCount: logs.where((l) => l.isCorrect).length,
        theta: profile.theta,
        questionDetails: questionDetails,
        customPrompt: settings.customDiagnosisPrompt.isNotEmpty
            ? settings.customDiagnosisPrompt
            : null,
      );

      await db.insertReport(report);
      state = state.copyWith(
        isGenerating: false,
        reports: [...state.reports, report],
        latestReport: report,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '诊断报告生成失败：$e',
      );
    }
  }

  Future<void> generateOverallReport() async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final db = ref.read(databaseProvider);
      final client = ref.read(llmClientProvider);
      final settings = ref.read(llmSettingsProvider);
      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.value;
      if (profile == null) return;

      final weakPoints = await db.getWeakKnowledgePoints();
      final profileCtx =
          PromptBuilder.buildDiagnosisContext(profile, weakPoints: weakPoints);

      final sessions = await db.getAllSessions();
      final kpMastery = await db.getWeakKnowledgePoints();

      final service = DiagnosisService(client);
      final report = await service.generateOverallReport(
        profileContext: profileCtx,
        totalSessions: sessions.length,
        totalAnswers: profile.totalAnswers,
        totalCorrect: profile.totalCorrect,
        kpMastery: kpMastery,
        customPrompt: settings.customDiagnosisPrompt.isNotEmpty
            ? settings.customDiagnosisPrompt
            : null,
      );

      await db.insertReport(report);
      state = state.copyWith(
        isGenerating: false,
        reports: [...state.reports, report],
        latestReport: report,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '总报告生成失败：$e',
      );
    }
  }

  void clearLatestReport() {
    state = state.copyWith(isGenerating: false, error: null);
    state = DiagnosisState(reports: state.reports);
  }

  Future<void> refresh() async {
    await _loadReports();
  }
}

final diagnosisProvider =
    NotifierProvider<DiagnosisNotifier, DiagnosisState>(
        DiagnosisNotifier.new);
